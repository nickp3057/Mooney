import SwiftUI

struct MoneyEntryField: View {
    @Binding var text: String
    var placeholder: String
    var width: CGFloat

    var body: some View {
        HStack(spacing: 2) {
            Text("$")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
        .frame(width: width)
    }
}
