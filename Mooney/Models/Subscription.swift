import Foundation

// Purely for visibility — tracking what you're subscribed to, its cost, and
// when it renews. Deliberately has no connection to Bills, buckets, or
// transactions: adding, editing, or deleting a subscription never moves
// money or touches a balance anywhere in the app.

enum SubscriptionStatus: String, Codable, CaseIterable, Identifiable {
    case active, paused, canceled

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct Subscription: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var amount: Double
    var cadence: TransferFrequency
    var nextDueDate: String  // yyyy-MM-dd
    var creditCardId: String?
    var status: SubscriptionStatus = .active

    enum CodingKeys: String, CodingKey {
        case id, name, amount, cadence, nextDueDate, creditCardId, status
    }

    init(id: String, name: String, amount: Double, cadence: TransferFrequency,
         nextDueDate: String, creditCardId: String? = nil, status: SubscriptionStatus = .active) {
        self.id = id
        self.name = name
        self.amount = amount
        self.cadence = cadence
        self.nextDueDate = nextDueDate
        self.creditCardId = creditCardId
        self.status = status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        amount = try c.decode(Double.self, forKey: .amount)
        cadence = try c.decode(TransferFrequency.self, forKey: .cadence)
        nextDueDate = try c.decode(String.self, forKey: .nextDueDate)
        creditCardId = try c.decodeIfPresent(String.self, forKey: .creditCardId)
        status = try c.decodeIfPresent(SubscriptionStatus.self, forKey: .status) ?? .active
    }

    // The stored nextDueDate is a static anchor set at add/edit time and is
    // never advanced automatically — this rolls it forward to the true next
    // occurrence on or after `today` without mutating anything, so sorting
    // and display never depend on a persisted field going stale.
    func upcomingDueDate(asOf today: Date = Date()) -> Date? {
        guard var date = isoDateFormatter.date(from: nextDueDate) else { return nil }
        let startOfToday = Calendar.current.startOfDay(for: today)
        var guardCount = 0
        while date < startOfToday, guardCount < 10_000 {
            date = cadence.nextDate(after: date)
            guardCount += 1
        }
        return date
    }
}
