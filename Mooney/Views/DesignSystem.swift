import SwiftUI

// The app's shared visual language. Screens are native inset-grouped Lists
// (so swipe actions, reordering, and disclosure groups all keep working) on
// a custom near-black/soft-gray background, with a handful of bespoke card
// components (hero balance, bucket chips, stat tiles) layered in as
// full-bleed rows. Colors still come from Theme.swift's palette and the
// per-tab accent system.

// MARK: - Screen + surfaces

private struct ScreenBackground: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(scheme == .dark ? Color(hex: appBackgroundHex) : Color(.systemGroupedBackground))
    }
}

private struct SurfaceCard: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var padding: EdgeInsets
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.primary.opacity(scheme == .dark ? 0.07 : 0.04), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.05), radius: 10, x: 0, y: 4)
            )
    }
}

extension View {
    /// Custom background for every List/Form — hides the system grouped
    /// background and paints the app's own (Spotify-style near-black in
    /// dark mode, standard grouped gray in light).
    func screenBackground() -> some View { modifier(ScreenBackground()) }

    /// A standalone rounded card for non-row content (hero, chart, grid).
    func surfaceCard(padding: EdgeInsets = EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16),
                     cornerRadius: CGFloat = 20) -> some View {
        modifier(SurfaceCard(padding: padding, cornerRadius: cornerRadius))
    }

    /// Kept for older call sites — same as `surfaceCard()`.
    func bubbleCard() -> some View { surfaceCard() }

    /// Strips a List row's own chrome so a `surfaceCard()` (or any custom
    /// card) placed as a row sits flush with the inset-grouped cards around
    /// it, rather than nested inside a plain row.
    func cardRow(verticalPadding: CGFloat = 0) -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: verticalPadding, leading: 0, bottom: verticalPadding, trailing: 0))
    }

    /// Kept for older call sites — a card that is itself a List row.
    func bubbleCardRow() -> some View { surfaceCard().cardRow(verticalPadding: 4) }

    /// Kept for older call sites.
    func plainCardSection() -> some View { cardRow() }

    /// Small-caps section label matching the List's own headers, for use
    /// above custom card rows that aren't in a titled Section.
    func sectionLabelStyle() -> some View {
        font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .kerning(0.4)
    }
}

// MARK: - Components

/// Rounded, colored square carrying an SF Symbol — the row "identity" mark
/// used by settings rows, ledger entries, and calendar events.
struct IconTile: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 30
    var symbolWeight: Font.Weight = .semibold

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(color.gradient)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: size * 0.5, weight: symbolWeight))
                    .foregroundStyle(.white)
            }
    }
}

/// Softer variant — tinted background with the symbol in the tint color,
/// for secondary/inline actions.
struct SoftIconTile: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 30

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(color.opacity(0.16))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .foregroundStyle(color)
            }
    }
}

/// Capsule button in a tint — filled or soft-tinted.
struct PillButtonStyle: ButtonStyle {
    var tint: Color
    var prominent: Bool = false
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
            .foregroundStyle(prominent ? Color.white : tint)
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 5 : 9)
            .background(
                Capsule().fill(prominent ? tint : tint.opacity(0.14))
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static func pill(_ tint: Color, prominent: Bool = false, compact: Bool = false) -> PillButtonStyle {
        PillButtonStyle(tint: tint, prominent: prominent, compact: compact)
    }
}

/// Small on/off chip used in settings rows (Active / Off).
struct StatusChip: View {
    let title: String
    let isOn: Bool
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isOn ? tint : Color.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(isOn ? tint.opacity(0.14) : Color.primary.opacity(0.06)))
    }
}

/// A compact label/value tile for summary strips.
struct StatTile: View {
    let title: String
    let value: String
    var tint: Color = .primary
    var systemImage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption2.weight(.semibold))
                }
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14), cornerRadius: 16)
    }
}

/// Circular progress indicator for savings goals.
struct GoalRing: View {
    let progress: Double
    let color: Color
    var size: CGFloat = 44
    var lineWidth: CGFloat = 5

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(progress, 1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: progress)
        }
        .frame(width: size, height: size)
    }
}

/// Thin horizontal progress bar for goals inside chips and rows.
struct GoalBar: View {
    let progress: Double
    let color: Color
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.18))
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * max(0, min(progress, 1)))
                    .animation(.easeOut(duration: 0.5), value: progress)
            }
        }
        .frame(height: height)
    }
}

/// "+ New Thing" row for settings lists.
struct AddRow: View {
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            SoftIconTile(systemName: "plus", color: tint, size: 28)
            Text(title)
                .foregroundStyle(tint)
                .fontWeight(.medium)
            Spacer()
        }
        .contentShape(Rectangle())
    }
}

/// Signed, colored amount text: green for money in, primary for money out.
struct AmountText: View {
    let amount: Double
    var font: Font = .body.weight(.semibold)
    var signed: Bool = true
    var muted: Bool = false

    var body: some View {
        let prefix = signed && amount > 0 ? "+" : ""
        Text(prefix + fmt(amount))
            .font(font)
            .monospacedDigit()
            .foregroundStyle(muted ? Color.secondary : (amount > 0 ? Color.green : Color.primary))
    }
}

/// A tinted glow drawn behind hero cards so the accent color shows through
/// without sacrificing text contrast.
struct AccentGlow: View {
    let color: Color

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [color.opacity(0.42), color.opacity(0.0)],
                center: .topLeading, startRadius: 0, endRadius: 320
            )
            RadialGradient(
                colors: [color.opacity(0.22), color.opacity(0.0)],
                center: .bottomTrailing, startRadius: 0, endRadius: 260
            )
        }
    }
}

extension View {
    /// Hero-card treatment: surface card with an accent glow bleeding in
    /// from the corners.
    func heroCard(tint: Color, cornerRadius: CGFloat = 24) -> some View {
        self
            .padding(EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18))
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                    AccentGlow(color: tint)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(tint.opacity(0.25), lineWidth: 1)
                }
            )
    }
}
