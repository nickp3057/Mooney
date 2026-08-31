import SwiftUI

// Apple's own named system colors — a small, recognizable set instead of
// arbitrary custom hex, so bucket tags read as native iOS rather than a
// rainbow of one-off swatches.
let curatedPalette: [String] = [
    "#FF3B30", // red — reserved as the default accent, avoid for bucket tags
    "#FF9500", // orange
    "#FFCC00", // yellow
    "#34C759", // green
    "#00C7BE", // mint
    "#30B0C7", // teal
    "#32ADE6", // cyan
    "#007AFF", // blue
    "#5856D6", // indigo
    "#AF52DE", // purple
    "#FF2D55", // pink
    "#A2845E", // brown
    "#8E8E93", // gray
]

// The subset offered for bucket tags — red excluded so it stays reserved
// for the accent color / "money going out" contexts.
let bucketPalette: [String] = Array(curatedPalette.dropFirst())

// Curated accent choices, mirroring Apple's own Settings > Accent Color picker.
let accentPalette: [String] = ["#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#007AFF", "#5856D6", "#AF52DE", "#FF2D55"]

let defaultAccentHex = "#FF3B30"

extension Color {
    // A dedicated muted dark gray for explanatory/instructional copy (section
    // footers, inline hints) — dimmer than the system's `.secondary`, which
    // in dark mode reads brighter than plain data labels want it to.
    static let helperText = Color(hex: "#6E6E73")
}

// Spotify-style near-black instead of pure system black, applied as the
// List/NavigationStack background across the app so dark mode doesn't read
// as flat #000.
let appBackgroundHex = "#121212"

// The app's 4 tabs, each independently colorable from Settings >
// Appearance. Sub-pages reached from a tab (pushed screens, sheets) inherit
// that tab's color via the tabAccentColor environment value below — the tab
// bar itself stays a single neutral tint so it doesn't look chaotic.
enum AppTab: String, CaseIterable, Identifiable {
    case ledger, add, subscriptions, settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ledger:        return "Ledger"
        case .add:            return "Add"
        case .subscriptions: return "Subscriptions"
        case .settings:       return "Settings"
        }
    }
}

private struct TabAccentColorKey: EnvironmentKey {
    static let defaultValue = Color(hex: defaultAccentHex)
}

extension EnvironmentValues {
    var tabAccentColor: Color {
        get { self[TabAccentColorKey.self] }
        set { self[TabAccentColorKey.self] = newValue }
    }
}
