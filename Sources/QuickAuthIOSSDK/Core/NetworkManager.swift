import Foundation

/// Lightweight URLSession-based HTTP client used by `BackendService`.
final class NetworkManager {

    private let session: URLSession
    private let connectTimeout: TimeInterval
    private let requestTimeout: TimeInterval

    init(
        connectTimeout: TimeInterval = 15,
        requestTimeout: TimeInterval = 20
    ) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = requestTimeout
        config.timeoutIntervalForRequest = connectTimeout
        self.session = URLSession(configuration: config)
        self.connectTimeout = connectTimeout
        self.requestTimeout = requestTimeout
    }

    // MARK: - POST

    func post(
        url: String,
        headers: [String: String],
        body: [String: Any],
        completion: @escaping (Result<Data, QAError>) -> Void
    ) {
        guard let requestURL = URL(string: url) else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.serializationError))
            return
        }

        execute(request: request, completion: completion)
    }

    // MARK: - GET

    func get(
        url: String,
        headers: [String: String],
        completion: @escaping (Result<Data, QAError>) -> Void
    ) {
        guard let requestURL = URL(string: url) else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.timeoutInterval = requestTimeout

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        execute(request: request, completion: completion)
    }

    // MARK: - Execute

    private func execute(
        request: URLRequest,
        completion: @escaping (Result<Data, QAError>) -> Void
    ) {
        QALogger.debug("\(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "")")

        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    let nsError = error as NSError
                    if nsError.code == NSURLErrorTimedOut {
                        completion(.failure(.timeout))
                    } else if nsError.code == NSURLErrorNotConnectedToInternet ||
                              nsError.code == NSURLErrorCannotFindHost {
                        completion(.failure(.networkUnavailable))
                    } else {
                        completion(.failure(.networkError(error.localizedDescription)))
                    }
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.networkError("Invalid response")))
                    return
                }

                guard let data = data else {
                    completion(.failure(.networkError("Empty response")))
                    return
                }

                QALogger.debug("Response: \(httpResponse.statusCode)")

                switch httpResponse.statusCode {
                case 200...299:
                    completion(.success(data))
                case 401:
                    completion(.failure(.unauthorized))
                case 403:
                    let msg = Self.extractMessage(from: data) ?? "Forbidden"
                    completion(.failure(.backendError(msg)))
                case 400...499:
                    let msg = Self.extractMessage(from: data) ?? "Request failed (\(httpResponse.statusCode))"
                    completion(.failure(.backendError(msg)))
                case 500...599:
                    completion(.failure(.serverError))
                default:
                    completion(.failure(.networkError("Unexpected status \(httpResponse.statusCode)")))
                }
            }
        }.resume()
    }

    private static func extractMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json["message"] as? String
    }
}
