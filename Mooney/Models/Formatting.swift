import SwiftUI
import Foundation

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        self.init(
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8)  & 0xFF) / 255,
            blue:  Double( int        & 0xFF) / 255
        )
    }

    // Round-trips a custom-picked color back to the "#RRGGBB" strings
    // everything else in the app (Bucket.colorHex, accentColorHex, etc.)
    // stores. Uses Color.Resolved (SwiftUI, iOS 17+) rather than UIColor so
    // this file stays UIKit-free and safe for the macOS typecheck.
    func toHex() -> String {
        let resolved = resolve(in: EnvironmentValues())
        let r = Int((resolved.red * 255).rounded())
        let g = Int((resolved.green * 255).rounded())
        let b = Int((resolved.blue * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

private let _currencyFmt: NumberFormatter = {
    let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "USD"; return f
}()

// Used across models, the store, and views for parsing/formatting yyyy-MM-dd
// date strings, so this needs to stay internal (not private) now that it's
// no longer confined to a single file.
let isoDateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    return df
}()

func fmt(_ n: Double) -> String { _currencyFmt.string(from: NSNumber(value: n)) ?? "$0.00" }

func fmtDate(_ iso: String) -> String {
    guard let d = isoDateFormatter.date(from: iso) else { return iso }
    let df = DateFormatter()
    df.dateStyle = .medium; df.timeStyle = .none
    return df.string(from: d)
}

// Drops the year unless it differs from this year — e.g. "Mar 4" vs. "Mar 4, 2027".
func fmtDueDate(_ iso: String) -> String {
    guard let d = isoDateFormatter.date(from: iso) else { return iso }
    let cal = Calendar.current
    let df = DateFormatter()
    df.dateFormat = cal.component(.year, from: d) == cal.component(.year, from: Date()) ? "MMM d" : "MMM d, yyyy"
    return df.string(from: d)
}

func todayISO() -> String {
    isoDateFormatter.string(from: Date())
}

// "1st", "22nd", "13th" — for day-of-month labels.
func ordinal(_ n: Int) -> String {
    let suffix: String
    switch (n % 10, n % 100) {
    case (1, let h) where h != 11: suffix = "st"
    case (2, let h) where h != 12: suffix = "nd"
    case (3, let h) where h != 13: suffix = "rd"
    default: suffix = "th"
    }
    return "\(n)\(suffix)"
}
