import SwiftUI
import Observation

@Observable
class AppStore {
    static let storageKey = "moonay_v2"
    static let decoyStorageKey = "moonay_decoy_v1"

    // One instance shared by the UI and the background-refresh handler
    // (MoonayApp) so a BGAppRefreshTask run and the next foreground
    // catch-up operate on the same state — two separate stores would each
    // hold their own stale lastRunDate and double-post occurrences.
    static let shared = AppStore()

    var state: AppState
    var isDecoyMode = false
    var isLocked: Bool

    init() {
        state = Self.loadReal()
        isLocked = AppLockManager.isPINEnabled
        catchUpState()
    }

    private static func loadReal() -> AppState {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(AppState.self, from: data) {
            return saved
        }
        return AppState(buckets: seedBuckets, incomes: seedIncomes, transactions: seedTransactions, recurringTransfers: seedRecurringTransfers)
    }

    private static func loadOrGenerateDecoy() -> AppState {
        if let data = UserDefaults.standard.data(forKey: decoyStorageKey),
           let saved = try? JSONDecoder().decode(AppState.self, from: data) {
            return saved
        }
        let generated = generateDecoyState()
        if let data = try? JSONEncoder().encode(generated) {
            UserDefaults.standard.set(data, forKey: decoyStorageKey)
        }
        return generated
    }

    private func save() {
        let key = isDecoyMode ? Self.decoyStorageKey : Self.storageKey
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // ── App Lock ──

    func lock() {
        guard AppLockManager.isPINEnabled else { return }
        isLocked = true
    }

    @discardableResult
    func attemptUnlock(pin: String) -> Bool {
        switch AppLockManager.verify(pin) {
        case .real:
            if isDecoyMode {
                isDecoyMode = false
                state = Self.loadReal()
                catchUpState()
            }
            isLocked = false
            return true
        case .decoy:
            if !isDecoyMode {
                isDecoyMode = true
                state = Self.loadOrGenerateDecoy()
                catchUpState()
                // A lock screen widget is visible without unlocking the
                // phone at all, so it's outside the PIN/decoy boundary —
                // stop it from showing the real balance for the rest of
                // this duress session rather than letting a stale cached
                // snapshot sit there.
                WidgetBalanceStore.clear()
            }
            isLocked = false
            return true
        case .none:
            return false
        }
    }

    // Face ID/Touch ID can't distinguish which enrolled face unlocked the
    // device, so a biometric match always resolves to the real dataset —
    // mirrors the .real branch of attemptUnlock(pin:) above. Decoy mode
    // stays reachable only by typing the decoy PIN.
    func unlockWithBiometrics() {
        if isDecoyMode {
            isDecoyMode = false
            state = Self.loadReal()
            catchUpState()
        }
        isLocked = false
    }

    private func catchUpState() {
        ensureGeneralBucket()
        runScheduledTransfers()
        ensureCardPayments()
        PaydayNotifications.reschedule(from: state.paySchedule)
        RecurringTransferNotifications.reschedule(from: state.recurringTransfers)
    }

    // Data saved before the general-bucket concept existed has no bucket
    // flagged isGeneral — designate one so the invariant (bucket balances +
    // general bucket == total savings) always holds, even for old data.
    private func ensureGeneralBucket() {
        guard !state.buckets.contains(where: { $0.isGeneral }) else { return }
        if let i = state.buckets.firstIndex(where: { $0.id == "savings" }) {
            state.buckets[i].isGeneral = true
        } else if let i = state.buckets.firstIndex(where: { !$0.isSpending && !$0.archived }) {
            state.buckets[i].isGeneral = true
        } else if !state.buckets.isEmpty {
            state.buckets[0].isGeneral = true
        } else {
            state.buckets.append(Bucket(
                id: "savings", name: "Savings", colorHex: "#AF52DE",
                isActive: true, archived: false, goal: nil,
                isSpending: false, order: 0, isGeneral: true
            ))
        }
        save()
    }

    // ── Theme ──

    var accentColor: Color { Color(hex: state.accentColorHex) }

    func setAccentColor(hex: String) {
        state.accentColorHex = hex
        save()
    }

    func accentColor(for tab: AppTab) -> Color {
        if let hex = state.tabAccentColors[tab.rawValue] { return Color(hex: hex) }
        return accentColor
    }

    func setAccentColor(hex: String, for tab: AppTab) {
        state.tabAccentColors[tab.rawValue] = hex
        save()
    }

    func resetAccentColor(for tab: AppTab) {
        state.tabAccentColors.removeValue(forKey: tab.rawValue)
        save()
    }

    func addCustomColor(hex: String) {
        guard !state.customColorHexes.contains(where: { $0.uppercased() == hex.uppercased() }) else { return }
        state.customColorHexes.append(hex)
        save()
    }

    func removeCustomColor(hex: String) {
        state.customColorHexes.removeAll { $0.uppercased() == hex.uppercased() }
        save()
    }

    // ── Mutations ──

    func addIncome(_ p: Income)      { state.incomes.append(p); save() }
    func deleteIncome(id: String)      { state.incomes.removeAll { $0.id == id }; save() }
    func addTransaction(_ t: AppTransaction) { state.transactions.append(t); save() }

    // Deleting one leg of a transfer (see transferBetweenBuckets) also
    // deletes its paired leg, so a transfer can't be left half-reverted.
    func deleteTransaction(id: String) {
        if let linkedId = state.transactions.first(where: { $0.id == id })?.linkedId {
            state.transactions.removeAll { $0.id == id || $0.id == linkedId }
        } else {
            state.transactions.removeAll { $0.id == id }
        }
        save()
    }
    func addBucket(_ b: Bucket)          { state.buckets.append(b); save() }
    func deleteBucket(id: String) {
        guard let bucket = state.buckets.first(where: { $0.id == id }), !bucket.isGeneral else { return }
        // Whatever was in it moves to the general bucket as an auditable
        // adjustment, so deleting a bucket never changes total savings.
        moveBalanceToGeneral(from: bucket, note: "Moved from \(bucket.name) (deleted)")
        state.buckets.removeAll { $0.id == id }
        save()
    }

    // Shifts a bucket's remaining balance into the general bucket. Used when
    // a bucket stops being a tracked savings bucket (deleted, archived, or
    // switched to spending) so its money stays counted instead of vanishing.
    private func moveBalanceToGeneral(from bucket: Bucket, note: String) {
        guard !bucket.isGeneral, !bucket.isSpending,
              let generalId = generalBucket?.id, generalId != bucket.id else { return }
        let remaining = balance(for: bucket.id)
        guard abs(remaining) >= 0.005 else { return }
        let date = todayISO()
        let outId = UUID().uuidString
        let inId = UUID().uuidString
        state.transactions.append(AppTransaction(
            id: outId, bucketId: bucket.id, amount: -remaining, date: date,
            note: note, type: "transfer", linkedId: inId
        ))
        state.transactions.append(AppTransaction(
            id: inId, bucketId: generalId, amount: remaining, date: date,
            note: note, type: "transfer", linkedId: outId
        ))
    }
    func addBill(_ b: Bill)              { state.bills.append(b); save() }
    func deleteBill(id: String)          { state.bills.removeAll { $0.id == id }; save() }

    func updateBucket(id: String, name: String, colorHex: String, goal: Double?, goalDate: String?, isSpending: Bool, allocationPercent: Double?, allocationAmount: Double?, iconName: String?) {
        guard let i = state.buckets.firstIndex(where: { $0.id == id }) else { return }
        state.buckets[i].name = name
        state.buckets[i].colorHex = colorHex
        state.buckets[i].goal = goal
        state.buckets[i].goalDate = goalDate
        state.buckets[i].allocationPercent = allocationPercent
        state.buckets[i].allocationAmount = allocationAmount
        state.buckets[i].iconName = iconName
        // The general bucket must stay a savings bucket — it's what makes
        // bucket balances always sum to total savings.
        if !state.buckets[i].isGeneral {
            if isSpending && !state.buckets[i].isSpending {
                // A spending bucket isn't part of total savings, so hand
                // its balance back to the general bucket before the switch.
                moveBalanceToGeneral(from: state.buckets[i], note: "Moved from \(name) (now spending)")
            }
            state.buckets[i].isSpending = isSpending
        }
        save()
    }

    func updateIncome(_ income: Income) {
        guard let i = state.incomes.firstIndex(where: { $0.id == income.id }) else { return }
        state.incomes[i] = income
        save()
    }

    func setBillPaymentPaid(incomeId: String, paymentId: String, isPaid: Bool) {
        guard let incomeIndex = state.incomes.firstIndex(where: { $0.id == incomeId }),
              let billIndex = state.incomes[incomeIndex].bills.firstIndex(where: { $0.id == paymentId }) else { return }
        state.incomes[incomeIndex].bills[billIndex].isPaid = isPaid
        state.incomes[incomeIndex].bills[billIndex].paidDate = isPaid ? todayISO() : nil
        save()
    }

    func setUnpaidBillGroupPaid(billId: String) {
        guard unpaidBillGroup(for: billId)?.canPay == true else { return }
        for incomeIndex in state.incomes.indices {
            for billIndex in state.incomes[incomeIndex].bills.indices {
                guard state.incomes[incomeIndex].bills[billIndex].billId == billId,
                      !state.incomes[incomeIndex].bills[billIndex].isPaid else { continue }
                state.incomes[incomeIndex].bills[billIndex].isPaid = true
                state.incomes[incomeIndex].bills[billIndex].paidDate = todayISO()
            }
        }
        save()
    }

    func toggleActive(id: String) {
        guard let i = state.buckets.firstIndex(where: { $0.id == id }) else { return }
        state.buckets[i].isActive.toggle()
        save()
    }

    func archiveBucket(id: String) {
        guard let i = state.buckets.firstIndex(where: { $0.id == id }),
              !state.buckets[i].isGeneral else { return }
        moveBalanceToGeneral(from: state.buckets[i], note: "Moved from \(state.buckets[i].name) (archived)")
        state.buckets[i].archived = true
        state.buckets[i].isActive = false
        save()
    }

    func updateBill(id: String, name: String, amount: Double) {
        guard let i = state.bills.firstIndex(where: { $0.id == id }) else { return }
        state.bills[i].name = name
        state.bills[i].amount = amount
        save()
    }

    func toggleBillActive(id: String) {
        guard let i = state.bills.firstIndex(where: { $0.id == id }) else { return }
        state.bills[i].isActive.toggle()
        save()
    }

    func addIncomeSource(_ s: IncomeSource) { state.incomeSources.append(s); save() }
    func deleteIncomeSource(id: String)     { state.incomeSources.removeAll { $0.id == id }; save() }

    // ── Recurring Transfers ──

    var sortedRecurringTransfers: [RecurringTransfer] {
        state.recurringTransfers.sorted { $0.name < $1.name }
    }

    func addRecurringTransfer(_ t: RecurringTransfer) {
        state.recurringTransfers.append(t)
        save()
        RecurringTransferNotifications.reschedule(from: state.recurringTransfers)
    }

    func deleteRecurringTransfer(id: String) {
        state.recurringTransfers.removeAll { $0.id == id }
        save()
        RecurringTransferNotifications.reschedule(from: state.recurringTransfers)
    }

    func updateRecurringTransfer(_ t: RecurringTransfer) {
        guard let i = state.recurringTransfers.firstIndex(where: { $0.id == t.id }) else { return }
        state.recurringTransfers[i] = t
        save()
        runScheduledTransfers()
        RecurringTransferNotifications.reschedule(from: state.recurringTransfers)
    }

    // Flipping a transfer back on should immediately post anything that came
    // due while it was paused, rather than waiting for the next launch/
    // foreground catch-up.
    func toggleRecurringTransferActive(id: String) {
        guard let i = state.recurringTransfers.firstIndex(where: { $0.id == id }) else { return }
        state.recurringTransfers[i].isActive.toggle()
        save()
        runScheduledTransfers()
        RecurringTransferNotifications.reschedule(from: state.recurringTransfers)
    }

    // Catches up every elapsed occurrence since each transfer's last run —
    // there's no background execution in a client-only app, so this runs at
    // launch and whenever the app returns to the foreground instead.
    func runScheduledTransfers() {
        let today = Date()
        var didChange = false
        for i in state.recurringTransfers.indices {
            guard state.recurringTransfers[i].isActive,
                  let start = isoDateFormatter.date(from: state.recurringTransfers[i].startDate) else { continue }

            var nextDue: Date
            if let lastRunStr = state.recurringTransfers[i].lastRunDate,
               let lastRun = isoDateFormatter.date(from: lastRunStr) {
                nextDue = state.recurringTransfers[i].frequency.nextDate(after: lastRun)
            } else {
                nextDue = start
            }

            while nextDue <= today {
                let transfer = state.recurringTransfers[i]
                let note: String
                let amount: Double
                if let destination = transfer.externalDestination {
                    note = "\(transfer.name) → \(destination) · auto-transfer"
                    amount = -transfer.amount
                } else {
                    note = "\(transfer.name) · auto-transfer"
                    amount = transfer.amount
                }
                state.transactions.append(AppTransaction(
                    id: UUID().uuidString,
                    bucketId: transfer.bucketId,
                    amount: amount,
                    date: isoDateFormatter.string(from: nextDue),
                    note: note,
                    type: "transfer"
                ))
                state.recurringTransfers[i].lastRunDate = isoDateFormatter.string(from: nextDue)
                didChange = true
                nextDue = transfer.frequency.nextDate(after: nextDue)
            }
        }
        if didChange { save() }
    }

    // ── Pay Schedule ──

    func setPaySchedule(nextPayDate: String, frequency: TransferFrequency) {
        state.paySchedule = PaySchedule(nextPayDate: nextPayDate, frequency: frequency)
        save()
        PaydayNotifications.reschedule(from: state.paySchedule)
    }

    func clearPaySchedule() {
        state.paySchedule = nil
        save()
        PaydayNotifications.cancelAll()
    }

    // Every occurrence of the pay schedule from its anchor date through
    // `end`, inclusive. Used both for the goal-contribution math and the
    // Calendar view, so both stay in sync with a single source of truth.
    func payDates(through end: Date) -> [Date] {
        // The stored anchor is never advanced, so roll it forward to the
        // next real pay date first — otherwise months of already-passed
        // paydays would be counted toward a goal.
        guard let schedule = state.paySchedule,
              let start = schedule.upcomingPayDate() else { return [] }
        var dates: [Date] = []
        var date = start
        while date <= end {
            dates.append(date)
            date = schedule.frequency.nextDate(after: date)
        }
        return dates
    }

    // ── Credit Cards ──

    var sortedCreditCards: [CreditCard] {
        state.creditCards.sorted { $0.name < $1.name }
    }

    func addCreditCard(_ c: CreditCard) {
        state.creditCards.append(c)
        save()
        ensureCardPayments()
    }

    func deleteCreditCard(id: String) {
        state.creditCards.removeAll { $0.id == id }
        state.cardPayments.removeAll { $0.cardId == id && !$0.isPaid }
        save()
    }

    func updateCreditCard(_ c: CreditCard) {
        guard let i = state.creditCards.firstIndex(where: { $0.id == c.id }) else { return }
        state.creditCards[i] = c
        save()
        ensureCardPayments()
    }

    func toggleCreditCardActive(id: String) {
        guard let i = state.creditCards.firstIndex(where: { $0.id == id }) else { return }
        state.creditCards[i].isActive.toggle()
        save()
        ensureCardPayments()
    }

    // Clamps a target day-of-month to however many days that month actually
    // has (e.g. dueDay 30 in February lands on the 28th/29th).
    func nextMonthlyDueDate(day: Int, onOrAfter date: Date) -> Date {
        let cal = Calendar.current
        func clampedDate(forMonthOf ref: Date) -> Date {
            var comps = cal.dateComponents([.year, .month], from: ref)
            let range = cal.range(of: .day, in: .month, for: ref) ?? (1..<29)
            comps.day = min(day, range.count)
            return cal.date(from: comps) ?? ref
        }
        let startOfDate = cal.startOfDay(for: date)
        var candidate = clampedDate(forMonthOf: startOfDate)
        if candidate < startOfDate {
            let nextMonth = cal.date(byAdding: .month, value: 1, to: candidate) ?? candidate
            candidate = clampedDate(forMonthOf: nextMonth)
        }
        return candidate
    }

    // Keeps exactly one unpaid CardPayment "slot" queued per active card —
    // there's no background execution in a client-only app, so this runs at
    // launch and whenever the app returns to the foreground (same pattern
    // as runScheduledTransfers, but this never moves money on its own).
    func ensureCardPayments() {
        var didChange = false
        for card in state.creditCards where card.isActive {
            let hasUnpaid = state.cardPayments.contains { $0.cardId == card.id && !$0.isPaid }
            guard !hasUnpaid else { continue }
            let lastPaidDue = state.cardPayments
                .filter { $0.cardId == card.id && $0.isPaid }
                .compactMap { isoDateFormatter.date(from: $0.dueDate) }
                .max()
            let anchor: Date
            if let lastPaidDue, let dayAfter = Calendar.current.date(byAdding: .day, value: 1, to: lastPaidDue) {
                anchor = dayAfter
            } else {
                anchor = Date()
            }
            let dueDate = nextMonthlyDueDate(day: card.dueDay, onOrAfter: anchor)
            state.cardPayments.append(CardPayment(
                id: UUID().uuidString,
                cardId: card.id,
                dueDate: isoDateFormatter.string(from: dueDate)
            ))
            didChange = true
        }
        if didChange { save() }
    }

    // Logs a partial (or full) payment against the current cycle — debits it
    // from primary savings (the general bucket) immediately, since that
    // money actually left, but doesn't close out the cycle. Call this as
    // many times as needed for one due date.
    func logCardPayment(paymentId: String, amount: Double) {
        guard let i = state.cardPayments.firstIndex(where: { $0.id == paymentId }),
              !state.cardPayments[i].isPaid,
              let generalId = generalBucket?.id else { return }
        let cardId = state.cardPayments[i].cardId
        let cardName = state.creditCards.first { $0.id == cardId }?.name ?? "Card"
        state.cardPayments[i].amountPaid += amount
        state.transactions.append(AppTransaction(
            id: UUID().uuidString,
            bucketId: generalId,
            amount: -amount,
            date: todayISO(),
            note: "\(cardName) payment",
            type: "card_payment"
        ))
        save()
    }

    // Explicitly closes out the current cycle and rolls the card forward to
    // its next due date — independent of amountPaid, since you often don't
    // know the exact statement balance up front and just want to say "done."
    func markCardPaidOff(paymentId: String) {
        guard let i = state.cardPayments.firstIndex(where: { $0.id == paymentId }),
              !state.cardPayments[i].isPaid else { return }
        state.cardPayments[i].isPaid = true
        state.cardPayments[i].paidDate = todayISO()
        save()
        ensureCardPayments()
    }

    // Surfaces every active card's current cycle — paid or not — so the
    // Dashboard can show a "paid off" state instead of the card just
    // disappearing. A card stays "paid" here until ensureCardPayments()
    // rolls it forward on the next launch/foreground, since that's the only
    // thing that creates the next cycle's unpaid record.
    var currentCardPayments: [(card: CreditCard, payment: CardPayment)] {
        state.creditCards.filter { $0.isActive }.compactMap { card in
            guard let payment = state.cardPayments
                .filter({ $0.cardId == card.id })
                .max(by: { $0.dueDate < $1.dueDate }) else { return nil }
            return (card: card, payment: payment)
        }
        .sorted { $0.payment.dueDate < $1.payment.dueDate }
    }

    func moveBuckets(from source: IndexSet, to destination: Int, among list: [Bucket]) {
        var ids = list.map { $0.id }
        ids.move(fromOffsets: source, toOffset: destination)
        for (order, id) in ids.enumerated() {
            if let i = state.buckets.firstIndex(where: { $0.id == id }) {
                state.buckets[i].order = order
            }
        }
        save()
    }

    func resetData() {
        state = AppState(buckets: seedBuckets, incomes: seedIncomes, transactions: seedTransactions, recurringTransfers: seedRecurringTransfers)
        save()
    }

    func clearFinancialData() {
        state.incomes = []
        state.transactions = []
        save()
    }

    func backupData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(state)
    }

    func decodedBackup(from data: Data) throws -> AppState {
        guard !data.isEmpty else { throw BackupError.emptyFile }
        do {
            return try JSONDecoder().decode(AppState.self, from: data)
        } catch {
            throw BackupError.invalidBackup
        }
    }

    func restoreBackup(_ backup: AppState) {
        state = backup
        save()
    }

    // ── Computed ──

    func balance(for bucketId: String) -> Double {
        let pay = state.incomes.flatMap { $0.allocations }
            .filter { $0.bucketId == bucketId }.reduce(0) { $0 + $1.amount }
        let tx = state.transactions
            .filter { $0.bucketId == bucketId }.reduce(0) { $0 + $1.amount }
        return pay + tx
    }

    func lastAlloc(for bucketId: String) -> Double {
        for p in state.incomes.sorted(by: { $0.date > $1.date }) {
            if let a = p.allocations.first(where: { $0.bucketId == bucketId }) { return a.amount }
        }
        return 0
    }

    func averageAlloc(for bucketId: String) -> Double {
        let values = state.incomes
            .flatMap { $0.allocations }
            .filter { $0.bucketId == bucketId }
            .map(\.amount)
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    func suggestedGoalContribution(for bucket: Bucket) -> Double? {
        guard !bucket.isSpending,
              let goal = bucket.goal,
              let goalDate = bucket.goalDate,
              let target = isoDateFormatter.date(from: goalDate) else { return nil }
        let needed = goal - balance(for: bucket.id)
        guard needed > 0 else { return 0 }
        // With a pay schedule set, count actual upcoming pay dates instead
        // of guessing a biweekly cadence.
        let incomes: Double
        if state.paySchedule != nil {
            incomes = Double(max(payDates(through: target).count, 1))
        } else {
            let days = max(Calendar.current.dateComponents([.day], from: Date(), to: target).day ?? 0, 0)
            incomes = max(ceil(Double(days) / 14.0), 1)
        }
        return needed / incomes
    }

    var lastIncome: Income? { state.incomes.sorted { $0.date > $1.date }.first }

    var generalBucket: Bucket? { state.buckets.first { $0.isGeneral } }

    var savingsBucketIds: Set<String> {
        Set(state.buckets.filter { !$0.isSpending }.map(\.id))
    }

    var activeBuckets: [Bucket] {
        state.buckets.filter { !$0.archived && $0.isActive }.sorted { $0.order < $1.order }
    }
    var savingsBuckets: [Bucket]  { activeBuckets.filter { !$0.isSpending } }
    var spendingBuckets: [Bucket] { activeBuckets.filter {  $0.isSpending } }
    var unpaidBillPayments: [(income: Income, bill: BillPayment)] {
        state.incomes.flatMap { income in
            income.bills
                .filter { !$0.isPaid }
                .map { (income: income, bill: $0) }
        }
        .sorted { $0.income.date > $1.income.date }
    }

    var unpaidBillsTotal: Double {
        unpaidBillPayments.reduce(0) { $0 + $1.bill.amount }
    }

    var unpaidBillGroups: [UnpaidBillGroup] {
        Dictionary(grouping: unpaidBillPayments, by: { $0.bill.billId })
            .compactMap { billId, payments in
                let saved = payments.reduce(0) { $0 + $1.bill.amount }
                let bill = state.bills.first { $0.id == billId }
                let name = bill?.name ?? payments.first?.bill.name ?? "Bill"
                // If the Bill definition was deleted, there's no live target to compare
                // against — treat whatever's already saved as the full requirement instead
                // of picking one arbitrary payment's amount out of the group.
                let required = bill?.amount ?? saved
                return UnpaidBillGroup(
                    billId: billId,
                    name: name,
                    savedAmount: saved,
                    requiredAmount: required,
                    paymentCount: payments.count
                )
            }
            .sorted { $0.name < $1.name }
    }

    func unpaidBillGroup(for billId: String) -> UnpaidBillGroup? {
        unpaidBillGroups.first { $0.billId == billId }
    }

    // Every non-spending bucket counts — including paused/"planned" and
    // archived ones — so deactivating a bucket never makes its money
    // disappear from the total. (savingsBalancePoints uses the same set.)
    var totalSavings: Double {
        state.buckets.filter { !$0.isSpending }.reduce(0) { $0 + balance(for: $1.id) } + unpaidBillsTotal
    }

    // Quick correction for the whole total (initial setup, interest, etc.) —
    // logs the delta as an adjustment on the general bucket instead of
    // silently overwriting anything, so it stays auditable in the ledger.
    @discardableResult
    func overrideTotalSavings(to target: Double, note: String) -> Bool {
        guard let generalId = generalBucket?.id else { return false }
        let delta = target - totalSavings
        guard delta != 0 else { return false }
        addTransaction(AppTransaction(
            id: UUID().uuidString,
            bucketId: generalId,
            amount: delta,
            date: todayISO(),
            note: note.isEmpty ? "Balance correction" : note,
            type: "adjustment"
        ))
        return true
    }

    // Moves money between two savings buckets as a paired debit/credit — unlike
    // overrideTotalSavings or a deposit/spend adjustment, the two transactions
    // always net to zero, so totalSavings itself never moves.
    @discardableResult
    func transferBetweenBuckets(fromId: String, toId: String, amount: Double, note: String) -> Bool {
        guard fromId != toId, amount > 0 else { return false }
        guard state.buckets.contains(where: { $0.id == fromId }),
              state.buckets.contains(where: { $0.id == toId }) else { return false }
        let transferNote = note.isEmpty ? "Transfer" : note
        let date = todayISO()
        let outId = UUID().uuidString
        let inId = UUID().uuidString
        state.transactions.append(AppTransaction(
            id: outId, bucketId: fromId, amount: -amount, date: date,
            note: transferNote, type: "transfer", linkedId: inId
        ))
        state.transactions.append(AppTransaction(
            id: inId, bucketId: toId, amount: amount, date: date,
            note: transferNote, type: "transfer", linkedId: outId
        ))
        save()
        return true
    }

    var sortedNonArchived: [Bucket] {
        state.buckets.filter { !$0.archived }.sorted { $0.order < $1.order }
    }

    var activeBills: [Bill] {
        state.bills.filter { $0.isActive }.sorted { $0.order < $1.order }
    }

    var sortedBills: [Bill] {
        state.bills.sorted { $0.order < $1.order }
    }

    // ── Subscriptions ──
    // Visibility only — these never create transactions or touch a bucket.

    // Yearly subscriptions are excluded entirely (not prorated) — this is a
    // "what recurs every month" total, not an amortized annual cost. Paused/
    // canceled subscriptions don't count toward it either.
    var monthlySubscriptionTotal: Double {
        state.subscriptions.filter { $0.status == .active }.reduce(0) { total, sub in
            switch sub.cadence {
            case .weekly:   return total + sub.amount * 52 / 12
            case .biweekly: return total + sub.amount * 26 / 12
            case .monthly:  return total + sub.amount
            case .yearly:   return total
            }
        }
    }

    func addSubscription(_ s: Subscription) { state.subscriptions.append(s); save() }
    func deleteSubscription(id: String)     { state.subscriptions.removeAll { $0.id == id }; save() }

    func updateSubscription(_ s: Subscription) {
        guard let i = state.subscriptions.firstIndex(where: { $0.id == s.id }) else { return }
        state.subscriptions[i] = s
        save()
    }

    func savingsBalancePoints() -> [SavingsPoint] {
        var events: [(date: Date, amount: Double)] = []
        let savingsIds = savingsBucketIds

        for income in state.incomes {
            guard let date = isoDateFormatter.date(from: income.date) else { continue }
            let amount = income.allocations
                .filter { savingsIds.contains($0.bucketId) }
                .reduce(0) { $0 + $1.amount }
            if amount != 0 { events.append((date, amount)) }
            for bill in income.bills {
                events.append((date, bill.amount))
                if bill.isPaid, let paidDate = bill.paidDate.flatMap({ isoDateFormatter.date(from: $0) }) {
                    events.append((paidDate, -bill.amount))
                }
            }
        }

        for transaction in state.transactions {
            guard let date = isoDateFormatter.date(from: transaction.date),
                  savingsIds.contains(transaction.bucketId) else { continue }
            events.append((date, transaction.amount))
        }

        var running = 0.0
        return events
            .sorted { $0.date < $1.date }
            .enumerated()
            .map { offset, event in
                running += event.amount
                return SavingsPoint(id: "\(offset)-\(event.date.timeIntervalSince1970)", date: event.date, balance: running)
            }
    }

    func incomeSourceName(_ sourceId: String?) -> String? {
        guard let sourceId else { return nil }
        return state.incomeSources.first { $0.id == sourceId }?.name
    }

    // Reverse-chronological feed of every income (as income) and standalone
    // transaction, for the Ledger view.
    var ledgerEntries: [LedgerEntry] {
        var items: [LedgerEntry] = []
        // Reversed so that, after the stable sort below, same-day ties (the
        // date string has no time component) land most-recently-added first
        // instead of oldest-added first.
        for p in state.incomes.reversed() {
            let sourceName = incomeSourceName(p.sourceId)
            items.append(LedgerEntry(
                id: "pay_\(p.id)",
                date: p.date,
                title: p.note.isEmpty ? (sourceName ?? "Income") : p.note,
                subtitle: sourceName.map { "Income · \($0)" } ?? "Income · Deposit",
                amount: p.amount,
                bucketId: nil,
                colorHex: "#34C759",
                kind: .income
            ))
        }
        for t in state.transactions.reversed() {
            // Ad-hoc bucket-to-bucket transfers are stored as two paired legs
            // (see transferBetweenBuckets) and carry a linkedId — emit one
            // combined "A → B" entry from the outgoing leg and skip the
            // linked incoming leg. Recurring-transfer-originated transactions
            // also use type "transfer" but are single, unlinked legs (see
            // runScheduledTransfers), so they fall through to the normal
            // single-entry path below instead of being merged/dropped here.
            if t.type == "transfer", let linkedId = t.linkedId {
                guard t.amount < 0 else { continue }
                let fromBucket = state.buckets.first { $0.id == t.bucketId }
                let toBucket = state.transactions.first { $0.id == linkedId }
                    .flatMap { inLeg in state.buckets.first { $0.id == inLeg.bucketId } }
                items.append(LedgerEntry(
                    id: t.id,
                    date: t.date,
                    title: t.note.isEmpty ? "Transfer" : t.note,
                    subtitle: "\(fromBucket?.name ?? "Bucket") → \(toBucket?.name ?? "Bucket")",
                    amount: -t.amount,
                    bucketId: nil,
                    colorHex: "#8E8E93",
                    isTransfer: true,
                    kind: .transfer
                ))
                continue
            }
            let bucket = state.buckets.first { $0.id == t.bucketId }
            items.append(LedgerEntry(
                id: t.id,
                date: t.date,
                title: t.note.isEmpty ? (bucket?.name ?? "Transaction") : t.note,
                subtitle: bucket?.name ?? t.type.capitalized,
                amount: t.amount,
                bucketId: t.bucketId,
                colorHex: bucket?.colorHex ?? "#8E8E93",
                kind: LedgerEntry.kind(forTransactionType: t.type, isLinkedTransfer: false)
            ))
        }
        return items.sorted { $0.date > $1.date }
    }
}
