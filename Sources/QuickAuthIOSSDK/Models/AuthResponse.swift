import Foundation

/// Internal model for decoding backend `/auth/verify`, `/auth/refresh`,
/// and `/auth/session` responses.
struct BackendAuthResponse: Decodable {
    let success: Bool
    let message: String?
    let accessToken: String?
    let refreshToken: String?
    let user: BackendUser?

    private enum CodingKeys: String, CodingKey {
        case success, message, user
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }

    var token: String? { accessToken }
}

/// Internal model for user data from backend.
struct BackendUser: Decodable {
    let id: String?
    let phone: String?
    let createdAt: String?

    private enum CodingKeys: String, CodingKey {
        case id, phone, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.phone = try container.decodeIfPresent(String.self, forKey: .phone)
        self.createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        // Backend may return id as either String or nested object
        if let idString = try? container.decode(String.self, forKey: .id) {
            self.id = idString
        } else {
            self.id = nil
        }
    }
}
