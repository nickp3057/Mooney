import Foundation
import CryptoKit
import Security

// Minimal Keychain wrapper for the app's own default access group — no
// entitlements needed. Deliberately kept out of UserDefaults/AppState so PIN
// hashes never end up inside a JSON export/backup.
private enum Keychain {
    static func set(_ value: String, for key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// App-lock PIN + decoy PIN management. A PIN is off by default — the app
// only ever locks once one has been explicitly set. Removing the real PIN
// also removes the decoy PIN, since a decoy can't meaningfully exist without
// a real lock to hide behind.
enum AppLockManager {
    private static let realKey = "com.mooney.applock.pin"
    private static let decoyKey = "com.mooney.applock.decoypin"
    // Local, per-device salt only — this guards against casual UserDefaults/
    // Keychain-dump inspection, not a substitute for a real KDF. Fine for a
    // 4-6 digit device passcode gate.
    private static let salt = "mooney.applock.v1"

    static var isPINEnabled: Bool { Keychain.get(realKey) != nil }
    static var isDecoyEnabled: Bool { Keychain.get(decoyKey) != nil }

    static func setPIN(_ pin: String) {
        Keychain.set(hash(pin), for: realKey)
    }

    static func removePIN() {
        Keychain.delete(realKey)
        removeDecoyPIN()
    }

    static func setDecoyPIN(_ pin: String) {
        Keychain.set(hash(pin), for: decoyKey)
    }

    static func removeDecoyPIN() {
        Keychain.delete(decoyKey)
    }

    enum VerifyResult { case real, decoy, none }

    static func verify(_ pin: String) -> VerifyResult {
        let h = hash(pin)
        if let real = Keychain.get(realKey), real == h { return .real }
        if let decoy = Keychain.get(decoyKey), decoy == h { return .decoy }
        return .none
    }

    private static func hash(_ pin: String) -> String {
        let digest = SHA256.hash(data: Data((pin + salt).utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
