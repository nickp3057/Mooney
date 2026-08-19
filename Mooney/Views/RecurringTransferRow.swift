import SwiftUI

struct RecurringTransferRow: View {
    @Environment(AppStore.self) var store
    @Environment(\.tabAccentColor) private var accentColor
    let transfer: RecurringTransfer
    let onEdit: () -> Void

    var bucketName: String {
        store.state.buckets.first { $0.id == transfer.bucketId }?.name ?? transfer.bucketId
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(accentColor)
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(transfer.name)
                Text("\(fmt(transfer.amount)) · \(transfer.frequency.label) → \(bucketName)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(transfer.isActive ? "Active" : "Off") {
                store.toggleRecurringTransferActive(id: transfer.id)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(transfer.isActive ? accentColor : .secondary)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(transfer.isActive ? accentColor.opacity(0.15) : Color(.systemGray6))
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
