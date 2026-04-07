import Foundation
import IPificationSDK

/// Wraps the native carrier verification SDK for internal use only.
/// This class is never exposed to SDK consumers.
final class CarrierAuthManager {

    private let clientId: String
    private let redirectUri: String
    private let environment: QAEnvironment
    private var isConfigured = false

    init(clientId: String, redirectUri: String, environment: QAEnvironment) {
        self.clientId = clientId
        self.redirectUri = redirectUri
        self.environment = environment
    }

    // MARK: - Internal Configuration

    private func ensureConfigured() {
        guard !isConfigured else { return }

        let config = IPConfiguration.sharedInstance
        config.CLIENT_ID = clientId
        config.REDIRECT_URI = redirectUri
        config.ENV = environment == .production ? .PRODUCTION : .SANDBOX

        isConfigured = true
        QALogger.debug("Carrier auth configured")
    }

    // MARK: - Coverage Check

    /// Check whether the current network/operator supports carrier verification.
    func checkCoverage(phone: String, completion: @escaping (Result<Bool, QAError>) -> Void) {
        ensureConfigured()

        let service = CoverageService()

        service.callbackSuccess = { response in
            let available = response.isAvailable()
            QALogger.debug("Coverage check: available=\(available)")
            completion(.success(available))
        }

        service.callbackFailed = { exception in
            let message = Self.sanitizeErrorMessage(exception.localizedDescription)
            QALogger.warning("Coverage check failed: \(message)")
            completion(.failure(.coverageCheckFailed(message)))
        }

        service.checkCoverage(phoneNumber: phone)
    }

    // MARK: - Authentication

    /// Perform carrier-level authentication and return the authorization code.
    func authenticate(phone: String, completion: @escaping (Result<String, QAError>) -> Void) {
        ensureConfigured()

        let service = AuthorizationService()

        let builder = AuthorizationRequest.Builder()
        builder.setScope(value: "openid ip:phone_verify")
        builder.addQueryParam(key: "login_hint", value: phone)
        let request = builder.build()

        service.callbackSuccess = { response in
            guard let code = response.getCode(), !code.isEmpty else {
                let errMsg = Self.sanitizeErrorMessage(response.getError())
                QALogger.warning("Auth succeeded but no code returned: \(errMsg)")
                completion(.failure(.authenticationFailed("Authorization code missing")))
                return
            }
            QALogger.debug("Auth code received (length=\(code.count))")
            completion(.success(code))
        }

        service.callbackFailed = { exception in
            let message = Self.sanitizeErrorMessage(exception.localizedDescription)
            QALogger.warning("Authentication failed: \(message)")
            completion(.failure(.authenticationFailed(message)))
        }

        service.startAuthorization(request)
    }

    // MARK: - Error Sanitization

    /// Strip vendor-specific terms from error messages before surfacing to consumers.
    private static func sanitizeErrorMessage(_ raw: String) -> String {
        return raw
            .replacingOccurrences(of: "IPification", with: "Carrier verification", options: .caseInsensitive)
            .replacingOccurrences(of: "ipification", with: "carrier verification", options: .caseInsensitive)
    }
}
