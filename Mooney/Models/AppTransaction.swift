import Foundation

struct AppTransaction: Identifiable, Codable {
    var id: String
    var bucketId: String
    var amount: Double
    var date: String
    var note: String
    var type: String
}
