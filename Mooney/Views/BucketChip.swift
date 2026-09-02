import SwiftUI

// Shared chip background: the card surface with a wash of the bucket's (or
// card's) color bleeding in from the top-left, and a faint tinted border.
private struct TintedChipBackground: ViewModifier {
    let tint: Color
    var cornerRadius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.22), tint.opacity(0.05)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(tint.opacity(0.22), lineWidth: 1)
                }
            )
    }
}

extension View {
    func tintedChipBackground(_ tint: Color, cornerRadius: CGFloat = 18) -> some View {
        modifier(TintedChipBackground(tint: tint, cornerRadius: cornerRadius))
    }
}

// Card for the Ledger's 2-across bucket grid — colored badge, name, balance,
// and a goal bar when the bucket has a target. The general "main savings"
// bucket gets its own full-width BucketHeroRow instead (see below).
struct BucketChip: View {
    @Environment(AppStore.self) var store
    let bucket: Bucket
    var onTap: () -> Void

    var body: some View {
        let bal = store.balance(for: bucket.id)
        let lastA = store.lastAlloc(for: bucket.id)
        let display = bucket.isSpending ? lastA : bal
        let progress = bucket.goal.map { $0 > 0 ? bal / $0 : 0 }

        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    BucketBadge(bucket: bucket, size: 32)
                    Spacer(minLength: 0)
                    if let progress {
                        Text("\(Int((min(progress, 1) * 100).rounded()))%")
                            .font(.caption2.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(progress >= 1 ? Color.green : bucket.color)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(bucket.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(fmt(display))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(display < -0.005 ? Color.red : Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                if let progress {
                    GoalBar(progress: progress, color: progress >= 1 ? .green : bucket.color)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tintedChipBackground(bucket.color)
        }
        .buttonStyle(.plain)
    }
}

// Full-width row for the general/"main savings" bucket — sits above the
// 2-across grid of everything else.
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
                BucketBadge(bucket: bucket, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(bucket.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(display < -0.005
                         ? "Negative — transfer from another bucket to cover it"
                         : "Main savings · unassigned money lands here")
                        .font(.caption)
                        .foregroundStyle(display < -0.005 ? Color.red : Color.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(fmt(display))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(display < -0.005 ? Color.red : Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .tintedChipBackground(bucket.color)
        }
        .buttonStyle(.plain)
    }
}
