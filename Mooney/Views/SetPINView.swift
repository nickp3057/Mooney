import SwiftUI

// Shared "type a PIN, then confirm it" flow used for both the real PIN and
// the decoy PIN. Purely local state — the caller decides what to do with
// the final PIN (AppLockManager.setPIN vs setDecoyPIN).
struct SetPINView: View {
    @Environment(\.dismiss) var dismiss
    let title: String
    let onConfirm: (String) -> Void

    @State private var first: String?
    @State private var digits = ""
    @State private var errorText: String?

    private let maxDigits = 6
    private let minDigits = 4

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()
                Text(first == nil ? title : "Confirm PIN")
                    .font(.title2.weight(.semibold))

                HStack(spacing: 16) {
                    ForEach(0..<maxDigits, id: \.self) { i in
                        Circle()
                            .strokeBorder(Color.secondary.opacity(0.5), lineWidth: 1.5)
                            .background(Circle().fill(i < digits.count ? Color.primary : Color.clear))
                            .frame(width: 14, height: 14)
                    }
                }

                if let errorText {
                    Text(errorText).font(.footnote.weight(.semibold)).foregroundStyle(.red)
                }

                Spacer()
                keypad.padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { completeStage() }
                        .disabled(digits.count < minDigits)
                }
            }
        }
    }

    private var keypad: some View {
        let rows: [[String]] = [
            ["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "⌫"]
        ]
        return VStack(spacing: 18) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 28) {
                    ForEach(row, id: \.self) { key in keyButton(key) }
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
                Image(systemName: "delete.left").font(.system(size: 22)).frame(width: 72, height: 72)
            }
            .buttonStyle(.plain).foregroundStyle(.primary)
        } else {
            Button {
                append(key)
            } label: {
                Text(key)
                    .font(.system(size: 28, weight: .medium))
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(Color.secondary.opacity(0.12)))
            }
            .buttonStyle(.plain).foregroundStyle(.primary)
        }
    }

    private func append(_ d: String) {
        guard digits.count < maxDigits else { return }
        errorText = nil
        digits.append(d)
        if digits.count == maxDigits { completeStage() }
    }

    private func completeStage() {
        guard digits.count >= minDigits else { return }
        if let first {
            if digits == first {
                onConfirm(digits)
                dismiss()
            } else {
                errorText = "PINs didn't match — try again"
                digits = ""
                self.first = nil
            }
        } else {
            first = digits
            digits = ""
        }
    }
}
