import Foundation

struct CreditCard: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var dueDay: Int  // 1-31, day of month the payment is due
    var isActive: Bool
}
