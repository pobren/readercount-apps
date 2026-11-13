// The sign in lives in the Keychain, only on this device. On iPhone and iPad it's kept in the App Group's access
// group, so the widget can use it too; where that isn't allowed (unsigned test builds) it stays with the app.

import Foundation
import Security

enum Keychain {
    private static let service = "com.readercount.app"

    private static func query(_ account: String, shared: Bool) -> [String: Any] {
        var q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        #if os(iOS)
        if shared { q[kSecAttrAccessGroup as String] = Shared.group }
        #endif
        return q
    }

    static func save(_ account: String, _ value: String) {
        delete(account)
        for shared in [true, false] {
            var q = query(account, shared: shared)
            q[kSecValueData as String] = Data(value.utf8)
            q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            if SecItemAdd(q as CFDictionary, nil) == errSecSuccess { return }
        }
    }

    static func read(_ account: String) -> String? {
        for shared in [true, false] {
            var q = query(account, shared: shared)
            q[kSecReturnData as String] = true
            q[kSecMatchLimit as String] = kSecMatchLimitOne
            var out: AnyObject?
            if SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data { return String(data: data, encoding: .utf8) }
        }
        return nil
    }

    static func delete(_ account: String) {
        SecItemDelete(query(account, shared: true) as CFDictionary)
        SecItemDelete(query(account, shared: false) as CFDictionary)
    }
}
