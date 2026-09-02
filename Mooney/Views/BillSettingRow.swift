import SwiftUI

struct BillSettingRow: View {
    @Environment(AppStore.self) var store
    @Environment(\.tabAccentColor) private var accentColor
    let bill: Bill
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            IconTile(systemName: "doc.text.fill", color: accentColor, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(bill.name).lineLimit(1)
                Text(fmt(bill.amount)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                store.toggleBillActive(id: bill.id)
            } label: {
                StatusChip(title: bill.isActive ? "Active" : "Off", isOn: bill.isActive, tint: accentColor)
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
