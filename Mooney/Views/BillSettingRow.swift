import SwiftUI

struct BillSettingRow: View {
    @Environment(AppStore.self) var store
    @Environment(\.tabAccentColor) private var accentColor
    let bill: Bill
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .foregroundStyle(accentColor)
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(bill.name)
                Text(fmt(bill.amount)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(bill.isActive ? "Active" : "Off") {
                store.toggleBillActive(id: bill.id)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(bill.isActive ? accentColor : .secondary)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(bill.isActive ? accentColor.opacity(0.15) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .buttonStyle(.plain)

            Button("Edit", action: onEdit)
                .font(.system(size: 13)).foregroundStyle(.secondary)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .buttonStyle(.plain)
        }
    }
}
