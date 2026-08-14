import Foundation

// One cycle's worth of a credit card payment. `amountPaid` is a running
// total — a cycle can take several partial payments (each debits savings
// immediately, since that money actually left) before it's closed out via
// an explicit "mark paid off," independent of whether amountPaid hits any
// particular target.
struct CardPayment: Identifiable, Codable, Hashable {
    var id: String
    var cardId: String
    var dueDate: String  // yyyy-MM-dd, this cycle's due date
    var amountPaid: Double
    var isPaid: Bool
    var paidDate: String?

    init(id: String, cardId: String, dueDate: String, amountPaid: Double = 0, isPaid: Bool = false, paidDate: String? = nil) {
        self.id = id
        self.cardId = cardId
        self.dueDate = dueDate
        self.amountPaid = amountPaid
        self.isPaid = isPaid
        self.paidDate = paidDate
    }

    enum CodingKeys: String, CodingKey {
        // "amount" kept as a fallback decode key so any cycle already saved
        // under the old single-payment shape still reads as its running total.
        case id, cardId, dueDate, amountPaid, amount, isPaid, paidDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        cardId = try container.decode(String.self, forKey: .cardId)
        dueDate = try container.decode(String.self, forKey: .dueDate)
        if let amountPaid = try container.decodeIfPresent(Double.self, forKey: .amountPaid) {
            self.amountPaid = amountPaid
        } else {
            self.amountPaid = try container.decodeIfPresent(Double.self, forKey: .amount) ?? 0
        }
        isPaid = try container.decodeIfPresent(Bool.self, forKey: .isPaid) ?? false
        paidDate = try container.decodeIfPresent(String.self, forKey: .paidDate)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(cardId, forKey: .cardId)
        try container.encode(dueDate, forKey: .dueDate)
        try container.encode(amountPaid, forKey: .amountPaid)
        try container.encode(isPaid, forKey: .isPaid)
        try container.encodeIfPresent(paidDate, forKey: .paidDate)
    }
}
