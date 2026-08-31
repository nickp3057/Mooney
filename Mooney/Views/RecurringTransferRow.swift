import SwiftUI

struct RecurringTransferRow: View {
    @Environment(AppStore.self) var store
    @Environment(\.tabAccentColor) private var accentColor
    let transfer: RecurringTransfer
    let onEdit: () -> Void

    var bucketName: String {
        store.state.buckets.first { $0.id == transfer.bucketId }?.name ?? transfer.bucketId
    }

    // Shows whether the transfer is armed and when it will next fire, so
    // it's obvious at a glance if it's paused or has an occurrence that
    // hasn't posted yet (the engine only catches up on launch/foreground).
    var scheduleNote: String {
        guard transfer.isActive else { return "Paused — won't auto-run" }
        guard let next = transfer.nextDueDate() else { return "" }
        let nextISO = isoDateFormatter.string(from: next)
        let ran = transfer.lastRunDate.map { " · last ran \(fmtDueDate($0))" } ?? ""
        return next <= Date()
            ? "Due \(fmtDueDate(nextISO)) — open app to sync\(ran)"
            : "Next \(fmtDueDate(nextISO))\(ran)"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(accentColor)
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(transfer.name)
                if let destination = transfer.externalDestination {
                    Text("−\(fmt(transfer.amount)) · \(transfer.frequency.label) · \(bucketName) → \(destination)")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("\(fmt(transfer.amount)) · \(transfer.frequency.label) → \(bucketName)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !scheduleNote.isEmpty {
                    Text(scheduleNote)
                        .font(.caption2)
                        .foregroundStyle(transfer.isActive ? .secondary : Color.orange)
                }
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
