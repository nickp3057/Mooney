import UserNotifications

// Local (not push) reminders that a recurring transfer is due, so a weekly
// "$125 leaves savings" doesn't slip by unrecorded when the app hasn't been
// opened. Mirrors PaydayNotifications: a rolling window of individual,
// non-repeating notifications rather than one repeating trigger, since the
// weekly/biweekly cadences need each future occurrence computed and
// scheduled separately.
//
// Unlike PaydayNotifications the set of identifiers is dynamic (one series
// per active transfer), so the identifiers that were actually scheduled are
// persisted and used to cancel synchronously — no async getPending round
// trip that could race the re-add.
enum RecurringTransferNotifications {
    private static let enabledKey = "com.mooney.notifications.recurringtransfer.enabled"
    private static let scheduledIDsKey = "com.mooney.notifications.recurringtransfer.ids"
    private static let idPrefix = "mooney.recurringtransfer."
    private static let occurrencesPerTransfer = 8
    private static let hour = 9
    private static let minute = 0

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    private static var scheduledIDs: [String] {
        get { UserDefaults.standard.stringArray(forKey: scheduledIDsKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: scheduledIDsKey) }
    }

    // Called when the user flips the Settings toggle. Requests OS
    // authorization only when turning on; `completion` reports the final
    // on/off state (false even after "turning on" if the user denies the
    // system prompt) so the caller's toggle can stay in sync.
    static func setEnabled(_ enabled: Bool, transfers: [RecurringTransfer], completion: ((Bool) -> Void)? = nil) {
        if enabled {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async {
                    isEnabled = granted
                    if granted {
                        reschedule(from: transfers)
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

    // Re-derives the rolling window from the current transfers. Safe to call
    // any time transfers change and on every launch, so the window never
    // runs dry — always cancels what it previously scheduled and rebuilds.
    static func reschedule(from transfers: [RecurringTransfer]) {
        cancelAll()
        guard isEnabled else { return }
        let cal = Calendar.current
        let center = UNUserNotificationCenter.current()
        let now = Date()
        var newIDs: [String] = []

        for transfer in transfers where transfer.isActive {
            guard var due = transfer.nextDueDate() else { continue }
            for i in 0..<occurrencesPerTransfer {
                if due > now {
                    var comps = cal.dateComponents([.year, .month, .day], from: due)
                    comps.hour = hour
                    comps.minute = minute
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

                    let content = UNMutableNotificationContent()
                    content.title = "Recurring transfer"
                    let verb = transfer.externalDestination != nil ? "leaves your savings" : "moves into savings"
                    content.body = "\(fmt(transfer.amount)) \(verb) via \(transfer.name) today. Open Mooney to record it."
                    content.sound = .default

                    let id = "\(idPrefix)\(transfer.id).\(i)"
                    center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
                    newIDs.append(id)
                }
                due = transfer.frequency.nextDate(after: due)
            }
        }
        scheduledIDs = newIDs
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: scheduledIDs)
        scheduledIDs = []
    }
}
