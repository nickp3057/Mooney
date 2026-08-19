import SwiftUI

// Shared "bubbly" visual language for list-row content across the app —
// rounded card with a soft shadow instead of a plain List row. Shape/depth
// only; colors still come from Theme.swift's palette/tabAccentColor system.
struct BubbleCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
            )
    }
}

extension View {
    /// Visual card only — for content that isn't itself a List row (e.g. a
    /// standalone VStack placed inside a Section).
    func bubbleCard() -> some View { modifier(BubbleCard()) }

    /// Visual card + strips the default List row chrome (background,
    /// separator, insets) so the card reads as a floating bubble rather than
    /// a card nested inside a plain row. Use on ForEach row content.
    func bubbleCardRow() -> some View {
        modifier(BubbleCard())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }
}
