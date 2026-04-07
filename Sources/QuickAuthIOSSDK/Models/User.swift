import Foundation

/// Public user model returned to SDK consumers.
public struct QAUser: Codable, Equatable {
    /// Backend user ID.
    public let id: String?
    /// Verified phone number (digits only).
    public let phone: String?
    /// Account creation timestamp (ISO 8601).
    public let createdAt: String?

    public init(id: String?, phone: String?, createdAt: String?) {
        self.id = id
        self.phone = phone
        self.createdAt = createdAt
    }

    /// Create from internal backend model.
    init(from backendUser: BackendUser) {
        self.id = backendUser.id
        self.phone = backendUser.phone
        self.createdAt = backendUser.createdAt
    }
}
