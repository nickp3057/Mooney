import SwiftUI

// Curated so every option reads clearly at 16pt in a small badge — general
// enough to cover common savings goals without turning into an unbounded
// SF Symbol browser.
let bucketIconOptions: [String] = [
    "house.fill", "car.fill", "airplane", "gift.fill",
    "heart.fill", "cart.fill", "graduationcap.fill", "bolt.fill",
    "fork.knife", "pawprint.fill", "gamecontroller.fill", "book.fill",
    "wrench.fill", "cross.case.fill", "bag.fill", "star.fill",
    "umbrella.fill", "banknote.fill", "creditcard.fill", "shield.fill",
    "leaf.fill", "sparkles", "briefcase.fill", "figure.walk",
]

// Reminders-list-style: a color swatch that optionally carries an SF Symbol,
// paired with a "None" option for buckets that would rather rely on an
// emoji already in their name (see Bucket.iconName).
struct BucketIconPicker: View {
    @Binding var selectedIcon: String?
    var colorHex: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            iconSwatch(nil)
            ForEach(bucketIconOptions, id: \.self) { icon in
                iconSwatch(icon)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func iconSwatch(_ icon: String?) -> some View {
        let isSelected = selectedIcon == icon
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(Color(hex: colorHex).opacity(icon == nil ? 0.15 : 1))
            .frame(width: 32, height: 32)
            .overlay {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "slash.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: colorHex))
                }
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.primary, lineWidth: 2)
                }
            }
            .onTapGesture { selectedIcon = icon }
    }
}
