import UserNotifications

// Local (not push) reminders on upcoming pay dates. Schedules a rolling
// window of individual, non-repeating notifications rather than one
// repeating trigger, since UNCalendarNotificationTrigger's `repeats` only
// handles fixed calendar components — biweekly/etc. cadences need each
// future date computed and scheduled separately, the same way
// CalendarEvents projects occurrences for display.
enum PaydayNotifications {
    private static let enabledKey = "com.mooney.notifications.payday.enabled"
    private static let scheduledCount = 12
    private static let idPrefix = "mooney.payday."
    private static let hour = 9
    private static let minute = 0

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    // Called when the user flips the Settings toggle. Requests OS
    // authorization only when turning on; turning off just cancels
    // everything already scheduled. `completion` reports the final on/off
    // state (which may be false even after "turning on" if the user denies
    // the system permission prompt) so the caller's own UI toggle state can
    // stay in sync instead of assuming the flip succeeded.
    static func setEnabled(_ enabled: Bool, schedule: PaySchedule?, completion: ((Bool) -> Void)? = nil) {
        if enabled {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async {
                    isEnabled = granted
                    if granted {
                        reschedule(from: schedule)
                    }
                    completion?(granted)
                }
            }
        } else {
            isEnabled = false
            cancelAll()
            completion?(false)
        }
    }

    // Re-derives the rolling window of future reminders from the current
    // pay schedule. Safe to call any time the schedule changes, and on
    // every launch, so the window never runs dry — always cancels and
    // rebuilds rather than appending, so it can't double-schedule.
    static func reschedule(from schedule: PaySchedule?) {
        cancelAll()
        guard isEnabled, let schedule, let anchor = schedule.upcomingPayDate() else { return }
        let cal = Calendar.current
        var date = anchor
        let center = UNUserNotificationCenter.current()
        for i in 0..<scheduledCount {
            var comps = cal.dateComponents([.year, .month, .day], from: date)
            comps.hour = hour
            comps.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

            let content = UNMutableNotificationContent()
            content.title = "Payday"
            content.body = "Don't forget to log your paycheck in Mooney."
            content.sound = .default

            center.add(UNNotificationRequest(identifier: "\(idPrefix)\(i)", content: content, trigger: trigger))
            date = schedule.frequency.nextDate(after: date)
        }
    }

    static func cancelAll() {
        let ids = (0..<scheduledCount).map { "\(idPrefix)\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}
