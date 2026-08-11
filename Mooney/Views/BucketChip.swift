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
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(bucket.color)
                    .frame(width: 10, height: 10)
                Text(bucket.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                Text(fmt(display))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .overlay(
                Capsule().stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
