import SwiftUI

struct LedgerEntry: Identifiable {
    var id: String
    var date: String
    var title: String
    var subtitle: String
    var amount: Double
    var bucketId: String?
    var colorHex: String

    var color: Color { Color(hex: colorHex) }
}
