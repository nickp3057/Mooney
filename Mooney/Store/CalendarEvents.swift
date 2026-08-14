import Foundation

struct CalendarEvent: Identifiable {
    enum Kind { case subscription, cardPayment, paycheck }
    var id: String
    var date: Date
    var title: String
    var subtitle: String
    var colorHex: String
    var kind: Kind
    // Points back to the originating Subscription/CreditCard id (nil for
    // paychecks, which have nothing to open) so the Calendar view can route
    // a tap to the right edit/payment sheet.
    var sourceId: String?
    // Raw charge amount, populated for .subscription so the calendar grid
    // can render a dollar figure instead of just a dot. Unused otherwise.
    var amount: Double?
}

// Aggregates every money-related date (subscriptions, credit card due
// dates, upcoming paychecks) into one list for the Calendar view. Recurring
// transfers are intentionally not projected here — that's plumbing, not a
// charge — see Settings for managing them. Everything here is a read-only
// projection — none of this creates transactions or mutates state, unlike
// runScheduledTransfers.
extension AppStore {
    func calendarEvents(forMonthContaining date: Date) -> [CalendarEvent] {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: date) else { return [] }
        let start = interval.start, end = interval.end
        var events: [CalendarEvent] = []

        for sub in state.subscriptions {
            guard let anchor = isoDateFormatter.date(from: sub.nextDueDate) else { continue }
            for occurrence in projectOccurrences(anchor: anchor, frequency: sub.cadence, start: start, end: end) {
                events.append(CalendarEvent(
                    id: "sub_\(sub.id)_\(isoDateFormatter.string(from: occurrence))",
                    date: occurrence,
                    title: sub.name,
                    subtitle: "Subscription · \(fmt(sub.amount))",
                    colorHex: "#5E5CE6",
                    kind: .subscription,
                    sourceId: sub.id,
                    amount: sub.amount
                ))
            }
        }

        // Always projected straight from the card's dueDay so the calendar
        // shows every month's due date, not just the single pending
        // CardPayment record — overlay paid/unpaid from any matching record.
        for card in state.creditCards where card.isActive {
            for occurrence in monthlyDueDates(day: card.dueDay, start: start, end: end) {
                let occurrenceISO = isoDateFormatter.string(from: occurrence)
                let matching = state.cardPayments.first { $0.cardId == card.id && $0.dueDate == occurrenceISO }
                let paid = matching?.isPaid ?? false
                let subtitle: String
                if paid {
                    subtitle = "Paid"
                } else if let amountPaid = matching?.amountPaid, amountPaid > 0 {
                    subtitle = "\(fmt(amountPaid)) paid so far"
                } else {
                    subtitle = "Due"
                }
                events.append(CalendarEvent(
                    id: "card_\(card.id)_\(occurrenceISO)",
                    date: occurrence,
                    title: "\(card.name) payment",
                    subtitle: subtitle,
                    colorHex: paid ? "#8E8E93" : "#FF3B30",
                    kind: .cardPayment,
                    sourceId: card.id
                ))
            }
        }

        if let schedule = state.paySchedule, let anchor = isoDateFormatter.date(from: schedule.nextPayDate) {
            for occurrence in projectOccurrences(anchor: anchor, frequency: schedule.frequency, start: start, end: end) {
                events.append(CalendarEvent(
                    id: "pay_\(isoDateFormatter.string(from: occurrence))",
                    date: occurrence,
                    title: "Paycheck",
                    subtitle: "Expected pay date",
                    colorHex: "#34C759",
                    kind: .paycheck,
                    sourceId: nil
                ))
            }
        }

        return events.sorted { $0.date < $1.date }
    }

    // Steps `frequency.nextDate(after:)` forward from `anchor` into
    // [start, end). If the anchor itself is at/after `end`, the schedule
    // hasn't started yet as of this month, so there's nothing to show.
    private func projectOccurrences(anchor: Date, frequency: TransferFrequency, start: Date, end: Date) -> [Date] {
        guard anchor < end else { return [] }
        var date = anchor
        var guardCount = 0
        while date < start, guardCount < 10_000 {
            date = frequency.nextDate(after: date)
            guardCount += 1
        }
        var occurrences: [Date] = []
        guardCount = 0
        while date < end, guardCount < 1_000 {
            occurrences.append(date)
            date = frequency.nextDate(after: date)
            guardCount += 1
        }
        return occurrences
    }

    private func monthlyDueDates(day: Int, start: Date, end: Date) -> [Date] {
        var dates: [Date] = []
        var cursor = start
        var guardCount = 0
        while cursor < end, guardCount < 24 {
            dates.append(nextMonthlyDueDate(day: day, onOrAfter: cursor))
            guard let next = Calendar.current.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
            guardCount += 1
        }
        return dates
    }
}
