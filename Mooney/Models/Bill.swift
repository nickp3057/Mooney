import Foundation

struct Bill: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var amount: Double
    var isActive: Bool
    var order: Int
}
