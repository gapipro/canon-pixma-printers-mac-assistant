import Foundation
import Security

enum KeychainStore {
    static let service = "local.g3010.assistant"

    static func savePassword(_ password: String, forHost host: String) {
        deletePassword(forHost: host)
        var query = baseQuery(host: host)
        query[kSecValueData as String] = Data(password.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }

    static func password(forHost host: String) -> String? {
        var query = baseQuery(host: host)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func deletePassword(forHost host: String) {
        SecItemDelete(baseQuery(host: host) as CFDictionary)
    }

    private static func baseQuery(host: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: host,
        ]
    }
}
