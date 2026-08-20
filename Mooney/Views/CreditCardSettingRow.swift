import SwiftUI

struct CreditCardSettingRow: View {
    @Environment(AppStore.self) var store
    @Environment(\.tabAccentColor) private var accentColor
    let card: CreditCard
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "creditcard.fill")
                .foregroundStyle(accentColor)
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.name)
                Text("Due on the \(card.dueDay)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(card.isActive ? "Active" : "Off") {
                store.toggleCreditCardActive(id: card.id)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(card.isActive ? accentColor : .secondary)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(card.isActive ? accentColor.opacity(0.15) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .buttonStyle(.plain)

            Button("Edit", action: onEdit)
                .font(.system(size: 13)).foregroundStyle(.secondary)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .buttonStyle(.plain)
        }
        .bubbleCardRow()
    }
}
