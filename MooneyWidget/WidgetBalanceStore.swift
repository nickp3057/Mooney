import Foundation

// Shared contract between the main app and MooneyWidget, via the
// group.com.nickpearson.Mooney App Group. Deliberately a standalone file
// with zero dependency on AppStore or anything else app-only — it's
// duplicated verbatim into MooneyWidget/ rather than shared across targets,
// since this project uses per-folder file-system-synchronized target
// membership and a two-line contract isn't worth fighting that for.
//
// The widget never talks to the Tailscale-only backend itself (background
// widget refreshes have no guaranteed network/VPN access) — instead the
// main app writes the last successfully fetched balance here whenever it
// refreshes, and the widget just reads the cached snapshot. That's the
// "(relatively) current" tradeoff by design, not a bug.
struct WidgetBalanceSnapshot: Codable {
    var accountName: String
    var balance: Double
    var asOf: Date
}

enum WidgetBalanceStore {
    static let appGroupID = "group.com.nickpearson.Mooney"
    private static let key = "mooney.widget.balance.snapshot"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    static func write(_ snapshot: WidgetBalanceSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
    }

    static func read() -> WidgetBalanceSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetBalanceSnapshot.self, from: data)
    }

    static func clear() {
        defaults?.removeObject(forKey: key)
    }
}
