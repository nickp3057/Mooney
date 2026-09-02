import SwiftUI

struct BucketSettingRow: View {
    @Environment(AppStore.self) var store
    @Environment(\.tabAccentColor) private var accentColor
    let bucket: Bucket
    let onEdit: () -> Void

    var meta: String {
        var p: [String] = []
        if bucket.isGeneral   { p.append("main savings") }
        if bucket.isSpending  { p.append("spending") }
        if let g = bucket.goal { p.append("goal \(fmt(g))") }
        if let d = bucket.goalDate { p.append("by \(fmtDate(d))") }
        if bucket.archived    { p.append("archived") }
        return p.isEmpty ? "savings bucket" : p.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            BucketBadge(bucket: bucket, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(bucket.name).lineLimit(1)
                Text(meta).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if !bucket.archived {
                Button {
                    store.toggleActive(id: bucket.id)
                } label: {
                    StatusChip(title: bucket.isActive ? "Active" : "Paused", isOn: bucket.isActive, tint: accentColor)
                }
                .buttonStyle(.plain)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
    }
}
