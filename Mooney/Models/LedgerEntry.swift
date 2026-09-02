import SwiftUI

struct LedgerEntry: Identifiable {
    // Drives the row's icon in the Ledger feed — derived from the source
    // record, never stored.
    enum Kind {
        case income, spend, transfer, autoTransfer, adjustment, cardPayment, other

        var systemImage: String {
            switch self {
            case .income:        return "arrow.down.left"
            case .spend:         return "bag.fill"
            case .transfer:      return "arrow.left.arrow.right"
            case .autoTransfer:  return "arrow.triangle.2.circlepath"
            case .adjustment:    return "slider.horizontal.3"
            case .cardPayment:   return "creditcard.fill"
            case .other:         return "circle.fill"
            }
        }
    }

    var id: String
    var date: String
    var title: String
    var subtitle: String
    var amount: Double
    var bucketId: String?
    var colorHex: String
    var isTransfer: Bool = false
    var kind: Kind = .other

    var color: Color { Color(hex: colorHex) }

    static func kind(forTransactionType type: String, isLinkedTransfer: Bool) -> Kind {
        switch type {
        case "spend":        return .spend
        case "adjustment":   return .adjustment
        case "card_payment": return .cardPayment
        case "transfer":     return isLinkedTransfer ? .transfer : .autoTransfer
        default:             return .other
        }
    }
}
