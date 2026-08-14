import SwiftUI

struct BucketSettingRow: View {
    @Environment(AppStore.self) var store
    @Environment(\.tabAccentColor) private var accentColor
    let bucket: Bucket
    let onEdit: () -> Void

    var meta: String {
        var p: [String] = []
        if bucket.isGeneral   { p.append("general") }
        if bucket.isSpending  { p.append("spending") }
        if let g = bucket.goal { p.append("goal: \(fmt(g))") }
        if let d = bucket.goalDate { p.append("by \(fmtDate(d))") }
        if bucket.archived    { p.append("archived") }
        return p.isEmpty ? "savings bucket" : p.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 7)
                .fill(bucket.color).frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(bucket.name)
                Text(meta).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !bucket.archived {
                Button(bucket.isActive ? "Active" : "Activate") {
                    store.toggleActive(id: bucket.id)
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(bucket.isActive ? accentColor : .secondary)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(bucket.isActive ? accentColor.opacity(0.15) : Color(.systemGray6))
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
}
