import Foundation

struct Income: Identifiable, Codable, Hashable {
    var id: String
    var date: String  // yyyy-MM-dd
    var amount: Double
    var note: String
    var sourceId: String?
    var bills: [BillPayment]
    var allocations: [Allocation]

    init(id: String, date: String, amount: Double, note: String, sourceId: String? = nil, bills: [BillPayment] = [], allocations: [Allocation]) {
        self.id = id
        self.date = date
        self.amount = amount
        self.note = note
        self.sourceId = sourceId
        self.bills = bills
        self.allocations = allocations
    }

    enum CodingKeys: String, CodingKey {
        case id, date, amount, note, sourceId, bills, allocations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        date = try container.decode(String.self, forKey: .date)
        amount = try container.decode(Double.self, forKey: .amount)
        note = try container.decode(String.self, forKey: .note)
        sourceId = try container.decodeIfPresent(String.self, forKey: .sourceId)
        bills = try container.decodeIfPresent([BillPayment].self, forKey: .bills) ?? []
        allocations = try container.decode([Allocation].self, forKey: .allocations)
    }
}
