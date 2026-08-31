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
    // When set, each occurrence pulls `amount` OUT of bucketId to somewhere
    // Mooney doesn't track (a CD, an outside brokerage, etc.) instead of
    // depositing into it — the money just leaves totalSavings for good.
    // Nil keeps the original behavior: a scheduled deposit INTO bucketId.
    var externalDestination: String?
}

extension RecurringTransfer {
    // The next date this transfer is due to post, given its schedule and
    // last run — nil when inactive or the start date won't parse. Mirrors
    // the projection in AppStore.runScheduledTransfers so a row can show the
    // exact date the engine will act on. A date in the past means an
    // occurrence is outstanding and hasn't been caught up yet.
    func nextDueDate() -> Date? {
        guard isActive, let start = isoDateFormatter.date(from: startDate) else { return nil }
        if let lastRunStr = lastRunDate,
           let lastRun = isoDateFormatter.date(from: lastRunStr) {
            return frequency.nextDate(after: lastRun)
        }
        return start
    }
}
