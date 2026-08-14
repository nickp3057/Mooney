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
