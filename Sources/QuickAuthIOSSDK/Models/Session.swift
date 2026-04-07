import Foundation

/// Represents an authenticated session with tokens and user info.
/// Stored securely in Keychain by the SDK.
public struct QASession: Codable, Equatable {
    /// JWT access token for API authorization.
    public let accessToken: String
    /// Refresh token for obtaining new access tokens.
    public let refreshToken: String?
    /// The authenticated user.
    public let user: QAUser?

    public init(accessToken: String, refreshToken: String?, user: QAUser?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.user = user
    }
}

/// SDK environment setting.
public enum QAEnvironment: String, Codable {
    case sandbox
    case production
}

/// Typed errors surfaced by the SDK.
public enum QAError: LocalizedError {
    case notConfigured
    case invalidPhone
    case coverageNotAvailable
    case coverageCheckFailed(String)
    case authenticationFailed(String)
    case backendError(String)
    case networkError(String)
    case networkUnavailable
    case timeout
    case unauthorized
    case sessionExpired
    case noSession
    case invalidURL
    case serializationError
    case decodingError
    case serverError
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "QuickAuth SDK is not configured. Call QuickAuth.shared.configure() first."
        case .invalidPhone:
            return "Invalid phone number. Use 7–15 digits only."
        case .coverageNotAvailable:
            return "Carrier verification is not available on this network."
        case .coverageCheckFailed(let msg):
            return "Coverage check failed: \(msg)"
        case .authenticationFailed(let msg):
            return "Authentication failed: \(msg)"
        case .backendError(let msg):
            return msg
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .networkUnavailable:
            return "No internet connection."
        case .timeout:
            return "Request timed out. Please try again."
        case .unauthorized:
            return "Session expired. Please login again."
        case .sessionExpired:
            return "Session is no longer valid."
        case .noSession:
            return "No active session. Please login first."
        case .invalidURL:
            return "Invalid backend URL configuration."
        case .serializationError:
            return "Failed to prepare request data."
        case .decodingError:
            return "Failed to parse server response."
        case .serverError:
            return "Server error. Please try again later."
        case .unknown(let msg):
            return msg
        }
    }
}
