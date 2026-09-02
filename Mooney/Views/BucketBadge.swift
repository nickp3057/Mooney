import SwiftUI

// Identity mark for a bucket: a rounded, colored badge carrying its icon, or
// a plain color square when no icon is set.
struct BucketBadge: View {
    let bucket: Bucket
    var size: CGFloat = 28

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(bucket.color.gradient)
            .frame(width: size, height: size)
            .overlay {
                if let icon = bucket.iconName {
                    Image(systemName: icon)
                        .font(.system(size: size * 0.48, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
    }
}
