import Foundation

// Builds a believable, fully separate fake dataset for decoy mode — fake
// buckets, balances, transactions, bills, subscriptions, cards, and a fake
// pay schedule, so nothing in the app looks empty or gives away that it's
// not the real data. Called exactly once; the result is then cached by
// AppStore so it stays identical across sessions instead of reshuffling.
func generateDecoyState() -> AppState {
    let cal = Calendar.current
    func daysAgo(_ n: Int) -> String {
        isoDateFormatter.string(from: cal.date(byAdding: .day, value: -n, to: Date()) ?? Date())
    }
    func daysFromNow(_ n: Int) -> String {
        isoDateFormatter.string(from: cal.date(byAdding: .day, value: n, to: Date()) ?? Date())
    }

    let buckets: [Bucket] = [
        Bucket(id: "d_savings",  name: "Savings",       colorHex: "#AF52DE", isActive: true, archived: false, goal: nil,   isSpending: false, order: 0, isGeneral: true),
        Bucket(id: "d_checking", name: "Checking",      colorHex: "#007AFF", isActive: true, archived: false, goal: nil,   isSpending: true,  order: 1),
        Bucket(id: "d_emerg",    name: "Emergency Fund",colorHex: "#34C759", isActive: true, archived: false, goal: 5000,  goalDate: daysFromNow(240), isSpending: false, order: 2),
        Bucket(id: "d_groceries",name: "Groceries",     colorHex: "#FF9500", isActive: true, archived: false, goal: nil,   isSpending: true,  order: 3),
        Bucket(id: "d_car",      name: "Car Fund",      colorHex: "#5856D6", isActive: true, archived: false, goal: 3000,  goalDate: daysFromNow(400), isSpending: false, order: 4),
        Bucket(id: "d_gifts",    name: "Gifts",         colorHex: "#FFCC00", isActive: true, archived: false, goal: nil,   isSpending: false, order: 5),
    ]

    let incomeSources: [IncomeSource] = [
        IncomeSource(id: "d_job", name: "Job"),
        IncomeSource(id: "d_side", name: "Side Gig"),
    ]

    func al(_ id: String, _ amt: Double) -> Allocation { Allocation(bucketId: id, amount: amt) }

    let incomes: [Income] = [
        Income(id: "d_p1", date: daysAgo(56), amount: 1120.00, note: "", sourceId: "d_job",
               allocations: [al("d_savings", 150), al("d_checking", 720), al("d_emerg", 100), al("d_groceries", 150)]),
        Income(id: "d_p2", date: daysAgo(42), amount: 1145.50, note: "", sourceId: "d_job",
               allocations: [al("d_savings", 150), al("d_checking", 745.50), al("d_emerg", 100), al("d_groceries", 150)]),
        Income(id: "d_p3", date: daysAgo(28), amount: 1098.25, note: "", sourceId: "d_job",
               allocations: [al("d_savings", 150), al("d_checking", 668.25), al("d_car", 100), al("d_groceries", 180)]),
        Income(id: "d_p4", date: daysAgo(14), amount: 1210.75, note: "", sourceId: "d_job",
               allocations: [al("d_savings", 200), al("d_checking", 730.75), al("d_car", 100), al("d_groceries", 180)]),
        Income(id: "d_p5", date: daysAgo(0), amount: 1180.00, note: "", sourceId: "d_job",
               allocations: [al("d_savings", 200), al("d_checking", 700), al("d_car", 100), al("d_groceries", 180)]),
    ]

    let transactions: [AppTransaction] = [
        AppTransaction(id: "d_t_open", bucketId: "d_savings", amount: 3200.00, date: daysAgo(200), note: "Opening balance", type: "opening"),
        AppTransaction(id: "d_t_g1", bucketId: "d_groceries", amount: -84.20, date: daysAgo(24), note: "Weekly groceries", type: "spend"),
        AppTransaction(id: "d_t_g2", bucketId: "d_groceries", amount: -91.15, date: daysAgo(17), note: "Weekly groceries", type: "spend"),
        AppTransaction(id: "d_t_g3", bucketId: "d_groceries", amount: -76.40, date: daysAgo(10), note: "Weekly groceries", type: "spend"),
        AppTransaction(id: "d_t_gift", bucketId: "d_gifts", amount: -45.00, date: daysAgo(19), note: "Birthday gift", type: "spend"),
        AppTransaction(id: "d_t_dine", bucketId: "d_checking", amount: -38.60, date: daysAgo(6), note: "Dinner out", type: "spend"),
    ]

    let bills: [Bill] = [
        Bill(id: "d_rent", name: "Rent", amount: 900, isActive: true, order: 0),
        Bill(id: "d_phone", name: "Phone Bill", amount: 45, isActive: true, order: 1),
    ]

    let subscriptions: [Subscription] = [
        Subscription(id: "d_sub1", name: "Streaming Plus", amount: 14.99, cadence: .monthly, nextDueDate: daysFromNow(9)),
        Subscription(id: "d_sub2", name: "Cloud Storage", amount: 2.99, cadence: .monthly, nextDueDate: daysFromNow(21)),
    ]

    let creditCards: [CreditCard] = [
        CreditCard(id: "d_card1", name: "Visa", dueDay: 12, isActive: true),
        CreditCard(id: "d_card2", name: "Mastercard", dueDay: 25, isActive: true),
    ]

    let recurringTransfers: [RecurringTransfer] = [
        RecurringTransfer(id: "d_xfer1", name: "Emergency Fund", bucketId: "d_emerg", amount: 25, frequency: .weekly, startDate: daysAgo(60), lastRunDate: nil, isActive: true),
    ]

    let paySchedule = PaySchedule(nextPayDate: daysFromNow(14), frequency: .biweekly)

    return AppState(
        buckets: buckets,
        incomes: incomes,
        transactions: transactions,
        bills: bills,
        incomeSources: incomeSources,
        recurringTransfers: recurringTransfers,
        subscriptions: subscriptions,
        paySchedule: paySchedule,
        creditCards: creditCards,
        cardPayments: []
    )
}
