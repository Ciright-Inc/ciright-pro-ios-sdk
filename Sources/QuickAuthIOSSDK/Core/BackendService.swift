import Foundation

/// Handles all HTTP communication with the QuickAuth backend.
final class BackendService {

    private let baseURL: String
    private let apiKey: String
    private let clientId: String
    private let redirectUri: String
    private let network: NetworkManager

    init(
        baseURL: String,
        apiKey: String,
        clientId: String,
        redirectUri: String,
        networkManager: NetworkManager
    ) {
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.apiKey = apiKey
        self.clientId = clientId
        self.redirectUri = redirectUri
        self.network = networkManager
    }

    private var commonHeaders: [String: String] {
        [
            "Content-Type": "application/json",
            "x-api-key": apiKey,
            "x-qa-client-id": clientId,
            "x-qa-redirect-uri": redirectUri
        ]
    }

    // MARK: - Login (Code Exchange)

    func login(
        code: String,
        phone: String,
        platform: String,
        deviceId: String,
        appId: String,
        sdkVersion: String,
        completion: @escaping (Result<BackendAuthResponse, QAError>) -> Void
    ) {
        let url = "\(baseURL)/auth/verify"

        let body: [String: Any] = [
            "code": code,
            "phone": phone,
            "platform": platform,
            "device_id": deviceId,
            "app_id": appId,
            "sdk_version": sdkVersion
        ]

        network.post(url: url, headers: commonHeaders, body: body) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let data):
                do {
                    let response = try JSONDecoder().decode(BackendAuthResponse.self, from: data)
                    guard response.success else {
                        completion(.failure(.backendError(response.message ?? "Login failed")))
                        return
                    }
                    completion(.success(response))
                } catch {
                    QALogger.warning("Failed to decode login response: \(error)")
                    completion(.failure(.decodingError))
                }
            }
        }
    }

    // MARK: - Session Validation

    func getSession(
        accessToken: String,
        completion: @escaping (Result<BackendAuthResponse, QAError>) -> Void
    ) {
        let url = "\(baseURL)/auth/session"

        var headers = commonHeaders
        headers["Authorization"] = "Bearer \(accessToken)"

        network.get(url: url, headers: headers) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let data):
                do {
                    let response = try JSONDecoder().decode(BackendAuthResponse.self, from: data)
                    guard response.success else {
                        completion(.failure(.sessionExpired))
                        return
                    }
                    completion(.success(response))
                } catch {
                    completion(.failure(.decodingError))
                }
            }
        }
    }

    // MARK: - Token Refresh

    func refreshToken(
        refreshToken: String,
        completion: @escaping (Result<BackendAuthResponse, QAError>) -> Void
    ) {
        let url = "\(baseURL)/auth/refresh"

        let body: [String: Any] = [
            "refresh_token": refreshToken
        ]

        network.post(url: url, headers: commonHeaders, body: body) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let data):
                do {
                    let response = try JSONDecoder().decode(BackendAuthResponse.self, from: data)
                    guard response.success else {
                        completion(.failure(.backendError(response.message ?? "Token refresh failed")))
                        return
                    }
                    completion(.success(response))
                } catch {
                    completion(.failure(.decodingError))
                }
            }
        }
    }
}
