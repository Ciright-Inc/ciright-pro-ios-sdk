import Foundation

/// Orchestrates the full authentication flow:
/// 1. Carrier coverage check
/// 2. Carrier authentication → authorization code
/// 3. Backend code exchange → JWT + refresh token
/// 4. Secure token storage
final class AuthManager {

    private let carrierAuth: CarrierAuthManager
    private let backendService: BackendService
    private let tokenStorage: TokenStorage

    init(
        carrierAuth: CarrierAuthManager,
        backendService: BackendService,
        tokenStorage: TokenStorage
    ) {
        self.carrierAuth = carrierAuth
        self.backendService = backendService
        self.tokenStorage = tokenStorage
    }

    // MARK: - Login

    func login(
        phone: String,
        onProgress: ((String) -> Void)?,
        completion: @escaping (Result<QASession, QAError>) -> Void
    ) {
        let phoneDigits = phone.replacingOccurrences(
            of: "[^0-9]", with: "", options: .regularExpression
        )

        guard phoneDigits.count >= 7, phoneDigits.count <= 15 else {
            completion(.failure(.invalidPhone))
            return
        }

        // Step 1: Coverage check
        onProgress?("(1/3) Checking operator coverage…")
        QALogger.info("(1/3) Checking operator coverage")

        carrierAuth.checkCoverage(phone: phoneDigits) { [weak self] coverageResult in
            guard let self = self else { return }

            switch coverageResult {
            case .failure(let error):
                completion(.failure(error))
                return
            case .success(let isAvailable):
                guard isAvailable else {
                    completion(.failure(.coverageNotAvailable))
                    return
                }
            }

            // Step 2: Carrier authentication
            onProgress?("(2/3) Verifying with carrier — complete any prompt, then return here…")
            QALogger.info("(2/3) Starting carrier authentication")

            self.carrierAuth.authenticate(phone: phoneDigits) { authResult in
                switch authResult {
                case .failure(let error):
                    completion(.failure(error))
                    return
                case .success(let code):
                    // Step 3: Backend exchange
                    onProgress?("(3/3) Exchanging code with backend…")
                    QALogger.info("(3/3) Exchanging code with backend")

                    self.exchangeWithBackend(
                        phone: phoneDigits,
                        code: code,
                        completion: completion
                    )
                }
            }
        }
    }

    // MARK: - Backend Exchange

    private func exchangeWithBackend(
        phone: String,
        code: String,
        completion: @escaping (Result<QASession, QAError>) -> Void
    ) {
        let deviceInfo = DeviceHelper.collect()

        backendService.login(
            code: code,
            phone: phone,
            platform: deviceInfo.platform,
            deviceId: deviceInfo.deviceId,
            appId: deviceInfo.appId,
            sdkVersion: deviceInfo.sdkVersion
        ) { [weak self] result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                guard let accessToken = response.accessToken else {
                    completion(.failure(.backendError("No access token returned")))
                    return
                }
                let user = response.user.map { QAUser(from: $0) }
                let session = QASession(
                    accessToken: accessToken,
                    refreshToken: response.refreshToken,
                    user: user
                )
                self?.tokenStorage.save(session: session)
                QALogger.info("Login successful — session stored")
                completion(.success(session))
            }
        }
    }

    // MARK: - Session Validation

    func validateSession(
        accessToken: String,
        completion: @escaping (Result<QASession, QAError>) -> Void
    ) {
        backendService.getSession(accessToken: accessToken) { [weak self] result in
            switch result {
            case .failure(let error):
                self?.tokenStorage.clear()
                completion(.failure(error))
            case .success(let response):
                let user = response.user.map { QAUser(from: $0) }
                let session = QASession(
                    accessToken: accessToken,
                    refreshToken: self?.tokenStorage.loadSession()?.refreshToken,
                    user: user
                )
                self?.tokenStorage.save(session: session)
                completion(.success(session))
            }
        }
    }

    // MARK: - Token Refresh

    func refreshToken(
        refreshToken: String,
        completion: @escaping (Result<QASession, QAError>) -> Void
    ) {
        backendService.refreshToken(refreshToken: refreshToken) { [weak self] result in
            switch result {
            case .failure(let error):
                self?.tokenStorage.clear()
                completion(.failure(error))
            case .success(let response):
                guard let accessToken = response.accessToken else {
                    completion(.failure(.backendError("No access token returned")))
                    return
                }
                let user = response.user.map { QAUser(from: $0) }
                let session = QASession(
                    accessToken: accessToken,
                    refreshToken: response.refreshToken,
                    user: user
                )
                self?.tokenStorage.save(session: session)
                QALogger.info("Token refreshed — session updated")
                completion(.success(session))
            }
        }
    }
}
