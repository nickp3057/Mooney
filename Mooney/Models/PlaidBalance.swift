import Foundation

// Always fetched fresh from the backend — never persisted in AppState/backups,
// since it's a live number, not something Mooney owns the source of truth for.
struct PlaidBalance {
    var accountName: String
    var current: Double?
    var available: Double?
    var isoCurrencyCode: String?
    var asOf: Date
}
