import Foundation

enum TransferFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly, biweekly, monthly, yearly

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    func nextDate(after date: Date) -> Date {
        let cal = Calendar.current
        switch self {
        case .weekly:   return cal.date(byAdding: .day, value: 7, to: date) ?? date
        case .biweekly: return cal.date(byAdding: .day, value: 14, to: date) ?? date
        case .monthly:  return cal.date(byAdding: .month, value: 1, to: date) ?? date
        case .yearly:   return cal.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }
}

struct RecurringTransfer: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var bucketId: String
    var amount: Double
    var frequency: TransferFrequency
    var startDate: String  // yyyy-MM-dd
    var lastRunDate: String?
    var isActive: Bool
}
