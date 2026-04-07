import Foundation
import Security

/// Securely stores and retrieves session data using the iOS Keychain.
final class TokenStorage {

    private let serviceName = "pro.ciright.quickauth"
    private let sessionKey = "qa_session"

    // MARK: - Save

    func save(session: QASession) {
        guard let data = try? JSONEncoder().encode(session) else {
            QALogger.warning("TokenStorage: failed to encode session")
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: sessionKey
        ]

        // Delete any existing item first
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            QALogger.warning("TokenStorage: Keychain save failed (status \(status))")
        }
    }

    // MARK: - Load

    func loadSession() -> QASession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: sessionKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return try? JSONDecoder().decode(QASession.self, from: data)
    }

    // MARK: - Clear

    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: sessionKey
        ]
        SecItemDelete(query as CFDictionary)
        QALogger.debug("TokenStorage: Keychain cleared")
    }
}
