import Foundation

struct AppState: Codable {
    var buckets: [Bucket]
    var incomes: [Income]
    var transactions: [AppTransaction]
    var bills: [Bill]
    var accentColorHex: String
    var incomeSources: [IncomeSource]
    var recurringTransfers: [RecurringTransfer]
    var subscriptions: [Subscription]

    init(buckets: [Bucket], incomes: [Income], transactions: [AppTransaction], bills: [Bill] = seedBills, accentColorHex: String = defaultAccentHex, incomeSources: [IncomeSource] = seedIncomeSources, recurringTransfers: [RecurringTransfer] = [], subscriptions: [Subscription] = []) {
        self.buckets = buckets
        self.incomes = incomes
        self.transactions = transactions
        self.bills = bills
        self.accentColorHex = accentColorHex
        self.incomeSources = incomeSources
        self.recurringTransfers = recurringTransfers
        self.subscriptions = subscriptions
    }

    enum CodingKeys: String, CodingKey {
        // "incomes" kept on the wire as "paychecks" so existing saved data
        // (and exported backups) still decode without a migration.
        case buckets, incomes = "paychecks", transactions, bills, accentColorHex, incomeSources, recurringTransfers, subscriptions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        buckets = try container.decode([Bucket].self, forKey: .buckets)
        incomes = try container.decode([Income].self, forKey: .incomes)
        transactions = try container.decode([AppTransaction].self, forKey: .transactions)
        bills = try container.decodeIfPresent([Bill].self, forKey: .bills) ?? seedBills
        accentColorHex = try container.decodeIfPresent(String.self, forKey: .accentColorHex) ?? defaultAccentHex
        incomeSources = try container.decodeIfPresent([IncomeSource].self, forKey: .incomeSources) ?? seedIncomeSources
        recurringTransfers = try container.decodeIfPresent([RecurringTransfer].self, forKey: .recurringTransfers) ?? []
        subscriptions = try container.decodeIfPresent([Subscription].self, forKey: .subscriptions) ?? []
    }
}
