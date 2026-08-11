import SwiftUI
import Observation

@Observable
class AppStore {
    static let storageKey = "moonay_v2"

    var state: AppState

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(AppState.self, from: data) {
            state = saved
        } else {
            state = AppState(buckets: seedBuckets, incomes: seedIncomes, transactions: seedTransactions, recurringTransfers: seedRecurringTransfers)
        }
        ensureGeneralBucket()
        runScheduledTransfers()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
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

    // ── Mutations ──

    func addIncome(_ p: Income)      { state.incomes.append(p); save() }
    func deleteIncome(id: String)      { state.incomes.removeAll { $0.id == id }; save() }
    func addTransaction(_ t: AppTransaction) { state.transactions.append(t); save() }
    func deleteTransaction(id: String)   { state.transactions.removeAll { $0.id == id }; save() }
    func addBucket(_ b: Bucket)          { state.buckets.append(b); save() }
    func deleteBucket(id: String) {
        guard state.buckets.first(where: { $0.id == id })?.isGeneral != true else { return }
        state.buckets.removeAll { $0.id == id }
        save()
    }
    func addBill(_ b: Bill)              { state.bills.append(b); save() }
    func deleteBill(id: String)          { state.bills.removeAll { $0.id == id }; save() }

    func updateBucket(id: String, name: String, colorHex: String, goal: Double?, goalDate: String?, isSpending: Bool) {
        guard let i = state.buckets.firstIndex(where: { $0.id == id }) else { return }
        state.buckets[i].name = name
        state.buckets[i].colorHex = colorHex
        state.buckets[i].goal = goal
        state.buckets[i].goalDate = goalDate
        // The general bucket must stay a savings bucket — it's what makes
        // bucket balances always sum to total savings.
        if !state.buckets[i].isGeneral {
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

    func addRecurringTransfer(_ t: RecurringTransfer) { state.recurringTransfers.append(t); save() }
    func deleteRecurringTransfer(id: String)           { state.recurringTransfers.removeAll { $0.id == id }; save() }

    func updateRecurringTransfer(_ t: RecurringTransfer) {
        guard let i = state.recurringTransfers.firstIndex(where: { $0.id == t.id }) else { return }
        state.recurringTransfers[i] = t
        save()
    }

    func toggleRecurringTransferActive(id: String) {
        guard let i = state.recurringTransfers.firstIndex(where: { $0.id == id }) else { return }
        state.recurringTransfers[i].isActive.toggle()
        save()
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
                state.transactions.append(AppTransaction(
                    id: UUID().uuidString,
                    bucketId: transfer.bucketId,
                    amount: transfer.amount,
                    date: isoDateFormatter.string(from: nextDue),
                    note: "\(transfer.name) · auto-transfer",
                    type: "transfer"
                ))
                state.recurringTransfers[i].lastRunDate = isoDateFormatter.string(from: nextDue)
                didChange = true
                nextDue = transfer.frequency.nextDate(after: nextDue)
            }
        }
        if didChange { save() }
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
        let days = max(Calendar.current.dateComponents([.day], from: Date(), to: target).day ?? 0, 0)
        let incomes = max(ceil(Double(days) / 14.0), 1)
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

    var totalSavings: Double      { savingsBuckets.reduce(0) { $0 + balance(for: $1.id) } + unpaidBillsTotal }

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

    var sortedSubscriptions: [Subscription] {
        state.subscriptions.sorted { $0.nextDueDate < $1.nextDueDate }
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
        for p in state.incomes {
            let sourceName = incomeSourceName(p.sourceId)
            items.append(LedgerEntry(
                id: "pay_\(p.id)",
                date: p.date,
                title: p.note.isEmpty ? (sourceName ?? "Income") : p.note,
                subtitle: sourceName.map { "Income · \($0)" } ?? "Income · Deposit",
                amount: p.amount,
                bucketId: nil,
                colorHex: "#8E8E93"
            ))
        }
        for t in state.transactions {
            let bucket = state.buckets.first { $0.id == t.bucketId }
            items.append(LedgerEntry(
                id: t.id,
                date: t.date,
                title: t.note.isEmpty ? (bucket?.name ?? "Transaction") : t.note,
                subtitle: bucket?.name ?? t.type.capitalized,
                amount: t.amount,
                bucketId: t.bucketId,
                colorHex: bucket?.colorHex ?? "#8E8E93"
            ))
        }
        return items.sorted { $0.date > $1.date }
    }
}
