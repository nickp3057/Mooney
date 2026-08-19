import LocalAuthentication

// Face ID/Touch ID on/off preference — a plain toggle, not a secret, so a
// UserDefaults bool is fine here unlike AppLockManager's PIN hashes, which
// deliberately live in the Keychain and stay out of AppState/UserDefaults so
// they can never end up in a JSON export/backup.
enum BiometricAuth {
    private static let enabledKey = "com.mooney.applock.faceid.enabled"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    // Biometrics can't tell the app which enrolled face/fingerprint
    // triggered a match — there's no way to distinguish a primary vs.
    // alternate appearance from here, so success always means "this device
    // owner authenticated," and callers should treat that as unlocking the
    // real dataset. Decoy access stays reachable only by typing the decoy
    // PIN manually on the keypad shown when this fails, is cancelled, or is
    // unavailable.
    static func attempt(reason: String = "Unlock Mooney", completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            completion(false)
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
            DispatchQueue.main.async { completion(success) }
        }
    }
}
