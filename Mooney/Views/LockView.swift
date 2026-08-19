import SwiftUI

// Full-screen passcode-style gate. Accepts either the real or decoy PIN —
// AppStore.attemptUnlock decides which dataset to load; this view has no
// idea which one it is (and shouldn't).
struct LockView: View {
    @Environment(AppStore.self) var store
    @State private var digits = ""
    @State private var shake = false
    @State private var showError = false
    @State private var didAttemptBiometrics = false

    private let maxDigits = 6
    private let minDigits = 4

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            VStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("Enter PIN")
                    .font(.title2.weight(.semibold))
            }

            HStack(spacing: 16) {
                ForEach(0..<maxDigits, id: \.self) { i in
                    Circle()
                        .strokeBorder(Color.secondary.opacity(0.5), lineWidth: 1.5)
                        .background(Circle().fill(i < digits.count ? Color.primary : Color.clear))
                        .frame(width: 14, height: 14)
                }
            }
            .modifier(ShakeEffect(shakes: shake ? 2 : 0))
            .animation(.default, value: shake)

            if showError {
                Text("Incorrect PIN")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
            }

            if BiometricAuth.isEnabled && BiometricAuth.isAvailable {
                Button {
                    attemptBiometrics()
                } label: {
                    Label("Use Face ID", systemImage: "faceid")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Spacer()

            keypad
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .task {
            guard !didAttemptBiometrics, BiometricAuth.isEnabled else { return }
            attemptBiometrics()
        }
    }

    private func attemptBiometrics() {
        didAttemptBiometrics = true
        BiometricAuth.attempt { success in
            if success { store.unlockWithBiometrics() }
        }
    }

    private var keypad: some View {
        let rows: [[String]] = [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            ["", "0", "⌫"]
        ]
        return VStack(spacing: 18) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 28) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyButton(_ key: String) -> some View {
        if key.isEmpty {
            Color.clear.frame(width: 72, height: 72)
        } else if key == "⌫" {
            Button {
                if !digits.isEmpty { digits.removeLast() }
            } label: {
                Image(systemName: "delete.left")
                    .font(.system(size: 22))
                    .frame(width: 72, height: 72)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
        } else {
            Button {
                appendDigit(key)
            } label: {
                Text(key)
                    .font(.system(size: 28, weight: .medium))
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(Color.secondary.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
        }
    }

    private func appendDigit(_ d: String) {
        guard digits.count < maxDigits else { return }
        showError = false
        digits.append(d)
        guard digits.count >= minDigits else { return }
        // Auto-submit once a plausible PIN length is reached; if it's wrong
        // and more digits fit, let the user keep typing without wiping input.
        if store.attemptUnlock(pin: digits) {
            digits = ""
        } else if digits.count == maxDigits {
            fail()
        }
    }

    private func fail() {
        showError = true
        withAnimation { shake.toggle() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            digits = ""
        }
    }
}

private struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = 8 * sin(shakes * .pi * 4)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}
