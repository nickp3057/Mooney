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
            IconTile(systemName: transfer.externalDestination == nil ? "arrow.triangle.2.circlepath" : "arrow.up.right",
                     color: accentColor, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(transfer.name).lineLimit(1)
                if let destination = transfer.externalDestination {
                    Text("−\(fmt(transfer.amount)) · \(transfer.frequency.label) · \(bucketName) → \(destination)")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                } else {
                    Text("\(fmt(transfer.amount)) · \(transfer.frequency.label) → \(bucketName)")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                if !scheduleNote.isEmpty {
                    Text(scheduleNote)
                        .font(.caption2)
                        .foregroundStyle(transfer.isActive ? Color.secondary : Color.orange)
                        .lineLimit(1)
                }
            }
            Spacer()
            Button {
                store.toggleRecurringTransferActive(id: transfer.id)
            } label: {
                StatusChip(title: transfer.isActive ? "Active" : "Off", isOn: transfer.isActive, tint: accentColor)
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
