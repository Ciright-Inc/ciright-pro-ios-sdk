import Foundation

/// Primary entry point for the QuickAuth iOS SDK.
///
/// Usage:
/// ```swift
/// QuickAuth.shared.configure(
///     apiKey: "your_api_key",
///     clientId: "your_client_id",
///     redirectUri: "https://example.com/callback"
/// )
///
/// QuickAuth.shared.login(phone: "919876543210") { result in
///     switch result {
///     case .success(let session):
///         print("Token: \(session.accessToken)")
///     case .failure(let error):
///         print("Error: \(error.localizedDescription)")
///     }
/// }
/// ```
public final class QuickAuth {

    // MARK: - Singleton

    public static let shared = QuickAuth()
    private init() {}

    // MARK: - Internal dependencies

    private var authManager: AuthManager?
    private var tokenStorage = TokenStorage()
    private var isConfigured = false

    // MARK: - Configuration

    private(set) var apiKey: String = ""
    private(set) var clientId: String = ""
    private(set) var redirectUri: String = ""
    private(set) var baseURL: String = QAConstants.defaultBaseURL
    private(set) var environment: QAEnvironment = .sandbox

    /// Configure the SDK. Call once before using `login()`.
    ///
    /// - Parameters:
    ///   - apiKey: Your QuickAuth API key (from backend dashboard).
    ///   - clientId: The carrier verification client ID.
    ///   - redirectUri: The registered redirect URI.
    ///   - baseURL: Backend base URL. Defaults to `https://api.ciright.pro`.
    ///   - environment: `.sandbox` or `.production`. Defaults to `.sandbox`.
    public func configure(
        apiKey: String,
        clientId: String,
        redirectUri: String,
        baseURL: String = QAConstants.defaultBaseURL,
        environment: QAEnvironment = .sandbox
    ) {
        self.apiKey = apiKey
        self.clientId = clientId
        self.redirectUri = redirectUri
        self.baseURL = baseURL
        self.environment = environment

        let networkManager = NetworkManager()
        let backendService = BackendService(
            baseURL: baseURL,
            apiKey: apiKey,
            clientId: clientId,
            redirectUri: redirectUri,
            networkManager: networkManager
        )
        let carrierAuth = CarrierAuthManager(
            clientId: clientId,
            redirectUri: redirectUri,
            environment: environment
        )

        self.authManager = AuthManager(
            carrierAuth: carrierAuth,
            backendService: backendService,
            tokenStorage: tokenStorage
        )
        self.isConfigured = true
        QALogger.info("SDK configured (base: \(baseURL))")
    }

    // MARK: - Login

    /// Authenticate a user by phone number.
    ///
    /// This triggers carrier-level SIM verification, exchanges the
    /// authorization code with the backend, and stores the resulting
    /// session tokens in Keychain.
    ///
    /// - Parameters:
    ///   - phone: Phone number (digits only, e.g. `"919876543210"`).
    ///   - onProgress: Optional progress callback with human-readable status.
    ///   - completion: Called with `.success(QASession)` or `.failure(QAError)`.
    public func login(
        phone: String,
        onProgress: ((String) -> Void)? = nil,
        completion: @escaping (Result<QASession, QAError>) -> Void
    ) {
        guard isConfigured, let authManager = authManager else {
            completion(.failure(.notConfigured))
            return
        }

        authManager.login(
            phone: phone,
            onProgress: onProgress,
            completion: completion
        )
    }

    /// Async/await wrapper for `login(phone:onProgress:completion:)`.
    @available(iOS 13.0, *)
    public func login(
        phone: String,
        onProgress: ((String) -> Void)? = nil
    ) async throws -> QASession {
        try await withCheckedThrowingContinuation { continuation in
            login(phone: phone, onProgress: onProgress) { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: - Session

    /// Returns the current session if tokens are stored and not expired.
    public func getCurrentSession() -> QASession? {
        return tokenStorage.loadSession()
    }

    /// Returns the currently stored user, or `nil` if not logged in.
    public func getCurrentUser() -> QAUser? {
        return tokenStorage.loadSession()?.user
    }

    /// `true` if a valid session exists in storage.
    public var isLoggedIn: Bool {
        return tokenStorage.loadSession() != nil
    }

    /// Validate the stored session against the backend.
    ///
    /// - Parameter completion: Called with the validated session or an error.
    public func validateSession(
        completion: @escaping (Result<QASession, QAError>) -> Void
    ) {
        guard isConfigured, let authManager = authManager else {
            completion(.failure(.notConfigured))
            return
        }
        guard let session = tokenStorage.loadSession() else {
            completion(.failure(.noSession))
            return
        }
        authManager.validateSession(accessToken: session.accessToken, completion: completion)
    }

    /// Refresh the stored tokens using the refresh token.
    ///
    /// - Parameter completion: Called with the new session or an error.
    public func refreshToken(
        completion: @escaping (Result<QASession, QAError>) -> Void
    ) {
        guard isConfigured, let authManager = authManager else {
            completion(.failure(.notConfigured))
            return
        }
        guard let session = tokenStorage.loadSession(),
              let refreshToken = session.refreshToken else {
            completion(.failure(.noSession))
            return
        }
        authManager.refreshToken(refreshToken: refreshToken, completion: completion)
    }

    // MARK: - Logout

    /// Clear all stored tokens and session data.
    public func logout(completion: ((Result<Void, QAError>) -> Void)? = nil) {
        tokenStorage.clear()
        QALogger.info("User logged out — tokens cleared")
        completion?(.success(()))
    }
}
