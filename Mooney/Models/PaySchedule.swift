import Foundation

struct PaySchedule: Codable, Equatable {
    var nextPayDate: String  // yyyy-MM-dd
    var frequency: TransferFrequency

    // nextPayDate is a static anchor set when the schedule was saved and is
    // never advanced in storage — this rolls it forward to the first pay
    // date on or after `today` (same idea as Subscription.upcomingDueDate).
    func upcomingPayDate(asOf today: Date = Date()) -> Date? {
        guard var date = isoDateFormatter.date(from: nextPayDate) else { return nil }
        let startOfToday = Calendar.current.startOfDay(for: today)
        var guardCount = 0
        while date < startOfToday, guardCount < 10_000 {
            date = frequency.nextDate(after: date)
            guardCount += 1
        }
        return date
    }
}
