import Foundation

// Purely for visibility — tracking what you're subscribed to, its cost, and
// when it renews. Deliberately has no connection to Bills, buckets, or
// transactions: adding, editing, or deleting a subscription never moves
// money or touches a balance anywhere in the app.
struct Subscription: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var amount: Double
    var cadence: TransferFrequency
    var nextDueDate: String  // yyyy-MM-dd
}
