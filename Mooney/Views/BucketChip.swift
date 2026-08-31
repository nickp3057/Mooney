import SwiftUI

// Reminders-list-style card for the Ledger's 2-across bucket grid — a
// colored/icon badge, name, and balance. The general "main savings" bucket
// gets its own full-width BucketHeroRow instead (see below).
struct BucketChip: View {
    @Environment(AppStore.self) var store
    let bucket: Bucket
    var onTap: () -> Void

    var body: some View {
        let bal = store.balance(for: bucket.id)
        let lastA = store.lastAlloc(for: bucket.id)
        let display = bucket.isSpending ? lastA : bal

        Button(action: onTap) {
            HStack(spacing: 8) {
                BucketBadge(bucket: bucket, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(bucket.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(fmt(display))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

// Full-width row for the general/"main savings" bucket — sits above the
// 2-across grid of everything else, like a Reminders list's top-level list.
struct BucketHeroRow: View {
    @Environment(AppStore.self) var store
    let bucket: Bucket
    var onTap: () -> Void

    var body: some View {
        let bal = store.balance(for: bucket.id)
        let lastA = store.lastAlloc(for: bucket.id)
        let display = bucket.isSpending ? lastA : bal

        Button(action: onTap) {
            HStack(spacing: 12) {
                BucketBadge(bucket: bucket, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(bucket.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("Main Savings")
                        .font(.caption)
                        .foregroundStyle(Color.helperText)
                }
                Spacer()
                Text(fmt(display))
                    .font(.system(size: 17, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .bubbleCard()
        }
        .buttonStyle(.plain)
    }
}
