import SwiftUI

struct CreditCardSettingRow: View {
    @Environment(AppStore.self) var store
    @Environment(\.tabAccentColor) private var accentColor
    let card: CreditCard
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            IconTile(systemName: "creditcard.fill", color: accentColor, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.name).lineLimit(1)
                Text("Due on the \(ordinal(card.dueDay))\(card.bankApp.map { " · \($0.label)" } ?? "")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                store.toggleCreditCardActive(id: card.id)
            } label: {
                StatusChip(title: card.isActive ? "Active" : "Off", isOn: card.isActive, tint: accentColor)
            }
            .buttonStyle(.plain)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
    }
}
