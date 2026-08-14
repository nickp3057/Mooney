import SwiftUI

struct MoneyEntryField: View {
    @Binding var text: String
    var placeholder: String
    var width: CGFloat
    // .focused() only reliably binds when applied to the leaf responder
    // itself — applying it to this whole struct from a call site doesn't
    // forward to the TextField inside, which is why the keyboard's "Done"
    // accessory bar could silently fail to track focus. Pass the binding in
    // and apply it here instead.
    var isFocused: FocusState<Bool>.Binding?

    var body: some View {
        HStack(spacing: 2) {
            Text("$")
                .foregroundStyle(.secondary)
            textField
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
        .frame(width: width)
    }

    @ViewBuilder
    private var textField: some View {
        if let isFocused {
            TextField(placeholder, text: $text).focused(isFocused)
        } else {
            TextField(placeholder, text: $text)
        }
    }
}
