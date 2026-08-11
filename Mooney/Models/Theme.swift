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
