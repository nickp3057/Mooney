import SwiftUI

// Bucket identity is always a small colour chip, never a large fill.
struct BucketChip: View {
    @Environment(AppStore.self) var store
    let bucket: Bucket
    var onTap: () -> Void

    var body: some View {
        let bal = store.balance(for: bucket.id)
        let lastA = store.lastAlloc(for: bucket.id)
        let display = bucket.isSpending ? lastA : bal

        Button(action: onTap) {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(bucket.color)
                    .frame(width: 9, height: 9)
                Text(bucket.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(fmt(display))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .overlay(
                Capsule().stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
