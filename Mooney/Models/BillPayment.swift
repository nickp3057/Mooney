import Foundation

struct BillPayment: Identifiable, Codable, Hashable {
    var id: String
    var billId: String
    var name: String
    var amount: Double
    var isPaid: Bool
    var paidDate: String?

    init(id: String, billId: String, name: String, amount: Double, isPaid: Bool = false, paidDate: String? = nil) {
        self.id = id
        self.billId = billId
        self.name = name
        self.amount = amount
        self.isPaid = isPaid
        self.paidDate = paidDate
    }

    enum CodingKeys: String, CodingKey {
        case id, billId, name, amount, isPaid, paidDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        billId = try container.decode(String.self, forKey: .billId)
        name = try container.decode(String.self, forKey: .name)
        amount = try container.decode(Double.self, forKey: .amount)
        isPaid = try container.decodeIfPresent(Bool.self, forKey: .isPaid) ?? true
        paidDate = try container.decodeIfPresent(String.self, forKey: .paidDate)
    }
}
