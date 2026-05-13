// Moonay.swift — "All my moonay", SwiftUI Edition
//
// Setup:
//   1. In Xcode, create a new project → App (SwiftUI, Swift)
//   2. Delete the generated ContentView.swift and <AppName>App.swift
//   3. Drag Moonay.swift into the project (target checked)
//   4. Set minimum deployment to iOS 17.0
//   5. Build & run
//
// Persistence: UserDefaults key "moonay_v2" — same key as the web version,
// but the format is Swift-native JSON, not the JS version, so they don't share data.

import SwiftUI
import Charts
import Observation
import UIKit
import UniformTypeIdentifiers


// MARK: - Models

struct Bucket: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var colorHex: String
    var isActive: Bool
    var archived: Bool
    var goal: Double?
    var goalDate: String?
    var isSpending: Bool
    var order: Int

    var color: Color { Color(hex: colorHex) }

    init(id: String, name: String, colorHex: String, isActive: Bool, archived: Bool, goal: Double?, goalDate: String? = nil, isSpending: Bool, order: Int) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isActive = isActive
        self.archived = archived
        self.goal = goal
        self.goalDate = goalDate
        self.isSpending = isSpending
        self.order = order
    }

    enum CodingKeys: String, CodingKey {
        case id, name, colorHex, isActive, archived, goal, goalDate, isSpending, order
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        archived = try container.decode(Bool.self, forKey: .archived)
        goal = try container.decodeIfPresent(Double.self, forKey: .goal)
        goalDate = try container.decodeIfPresent(String.self, forKey: .goalDate)
        isSpending = try container.decode(Bool.self, forKey: .isSpending)
        order = try container.decode(Int.self, forKey: .order)
    }
}

struct Allocation: Codable, Hashable {
    var bucketId: String
    var amount: Double
}

struct Bill: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var amount: Double
    var isActive: Bool
    var order: Int
}

struct BillPayment: Identifiable, Codable, Hashable {
    var id: String
    var billId: String
    var name: String
    var amount: Double
    var isPaid: Bool
    var paidDate: String?

    init(id: String, billId: String, name: String, amount: Double, isPaid: Bool = false, paidDate: String? = nil) {
        self.id = id
        self.billId = billId
        self.name = name
        self.amount = amount
        self.isPaid = isPaid
        self.paidDate = paidDate
    }

    enum CodingKeys: String, CodingKey {
        case id, billId, name, amount, isPaid, paidDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        billId = try container.decode(String.self, forKey: .billId)
        name = try container.decode(String.self, forKey: .name)
        amount = try container.decode(Double.self, forKey: .amount)
        isPaid = try container.decodeIfPresent(Bool.self, forKey: .isPaid) ?? true
        paidDate = try container.decodeIfPresent(String.self, forKey: .paidDate)
    }
}

struct Paycheck: Identifiable, Codable, Hashable {
    var id: String
    var date: String  // yyyy-MM-dd
    var amount: Double
    var note: String
    var bills: [BillPayment]
    var allocations: [Allocation]

    init(id: String, date: String, amount: Double, note: String, bills: [BillPayment] = [], allocations: [Allocation]) {
        self.id = id
        self.date = date
        self.amount = amount
        self.note = note
        self.bills = bills
        self.allocations = allocations
    }

    enum CodingKeys: String, CodingKey {
        case id, date, amount, note, bills, allocations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        date = try container.decode(String.self, forKey: .date)
        amount = try container.decode(Double.self, forKey: .amount)
        note = try container.decode(String.self, forKey: .note)
        bills = try container.decodeIfPresent([BillPayment].self, forKey: .bills) ?? []
        allocations = try container.decode([Allocation].self, forKey: .allocations)
    }
}

struct AppTransaction: Identifiable, Codable {
    var id: String
    var bucketId: String
    var amount: Double
    var date: String
    var note: String
    var type: String
}

struct AppState: Codable {
    var buckets: [Bucket]
    var paychecks: [Paycheck]
    var transactions: [AppTransaction]
    var bills: [Bill]

    init(buckets: [Bucket], paychecks: [Paycheck], transactions: [AppTransaction], bills: [Bill] = seedBills) {
        self.buckets = buckets
        self.paychecks = paychecks
        self.transactions = transactions
        self.bills = bills
    }

    enum CodingKeys: String, CodingKey {
        case buckets, paychecks, transactions, bills
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        buckets = try container.decode([Bucket].self, forKey: .buckets)
        paychecks = try container.decode([Paycheck].self, forKey: .paychecks)
        transactions = try container.decode([AppTransaction].self, forKey: .transactions)
        bills = try container.decodeIfPresent([Bill].self, forKey: .bills) ?? seedBills
    }
}

struct MoonayBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum BackupError: LocalizedError {
    case emptyFile
    case invalidBackup

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "That backup file was empty."
        case .invalidBackup:
            return "That file does not look like a Moonay backup."
        }
    }
}

// MARK: - Seed Data

private func al(_ id: String, _ amt: Double) -> Allocation { Allocation(bucketId: id, amount: amt) }

private let seedBills: [Bill] = [
    Bill(id: "car_payment", name: "Car Payment", amount: 250, isActive: true, order: 0),
    Bill(id: "phone_bill", name: "Phone Bill", amount: 25, isActive: true, order: 1),
]

private let seedBuckets: [Bucket] = [
    Bucket(id:"savings",     name:"Savings",     colorHex:"#7C3AED", isActive:true,  archived:false, goal:nil,   isSpending:false, order:0),
    Bucket(id:"checking",    name:"Checking",    colorHex:"#3B82F6", isActive:true,  archived:false, goal:nil,   isSpending:true,  order:1),
    Bucket(id:"tithing",     name:"Tithing",     colorHex:"#10B981", isActive:true,  archived:false, goal:nil,   isSpending:true,  order:2),
    Bucket(id:"bts",         name:"BTS",         colorHex:"#DB2777", isActive:true,  archived:false, goal:nil,   isSpending:false, order:3),
    Bucket(id:"vacation",    name:"Vacation",    colorHex:"#F59E0B", isActive:true,  archived:false, goal:nil,   isSpending:false, order:4),
    Bucket(id:"christmas",   name:"Christmas",   colorHex:"#DC2626", isActive:true,  archived:false, goal:nil,   isSpending:false, order:5),
    Bucket(id:"car",         name:"Car",         colorHex:"#6366F1", isActive:true,  archived:false, goal:2000,  isSpending:false, order:6),
    Bucket(id:"lego",        name:"Lego",        colorHex:"#CA8A04", isActive:true,  archived:false, goal:nil,   isSpending:false, order:7),
    Bucket(id:"nickolas",    name:"Nickolas",    colorHex:"#F97316", isActive:false, archived:false, goal:nil,   isSpending:false, order:8),
    Bucket(id:"splurges",    name:"Splurges",    colorHex:"#8B5CF6", isActive:false, archived:false, goal:nil,   isSpending:false, order:9),
    Bucket(id:"debt_makeup", name:"Debt Makeup", colorHex:"#64748B", isActive:false, archived:false, goal:nil,   isSpending:false, order:10),
    Bucket(id:"disney",      name:"Disney",      colorHex:"#EA580C", isActive:false, archived:true,  goal:nil,   isSpending:false, order:20),
]

private let seedPaychecks: [Paycheck] = [
    Paycheck(id:"p_20250626", date:"2025-06-26", amount:477.10,  note:"",                  allocations:[al("savings",100),  al("checking",327.11), al("bts",50)]),
    Paycheck(id:"p_20250710", date:"2025-07-10", amount:265.17,  note:"",                  allocations:[al("savings",30),   al("checking",135.17), al("disney",50),    al("bts",50)]),
    Paycheck(id:"p_20250723", date:"2025-07-23", amount:472.25,  note:"",                  allocations:[al("savings",40),   al("checking",332.25), al("disney",50),    al("bts",50)]),
    Paycheck(id:"p_20250807", date:"2025-08-07", amount:504.17,  note:"",                  allocations:[al("savings",50),   al("checking",394.17), al("disney",30),    al("bts",30)]),
    Paycheck(id:"p_20250821", date:"2025-08-21", amount:384.62,  note:"",                  allocations:[al("savings",50),   al("checking",274.62), al("disney",30),    al("bts",30)]),
    Paycheck(id:"p_20250904", date:"2025-09-04", amount:480.26,  note:"",                  allocations:[al("savings",80),   al("checking",300.26), al("disney",50),    al("bts",50)]),
    Paycheck(id:"p_20250918", date:"2025-09-18", amount:626.40,  note:"",                  allocations:[al("savings",80),   al("checking",384.40), al("disney",50),    al("bts",50)]),
    Paycheck(id:"p_20251002", date:"2025-10-02", amount:644.65,  note:"",                  allocations:[al("savings",80),   al("tithing",64),  al("checking",400.65), al("disney",50), al("bts",50)]),
    Paycheck(id:"p_20251016", date:"2025-10-16", amount:677.56,  note:"",                  allocations:[al("savings",80),   al("checking",430.56), al("disney",50),    al("bts",50)]),
    Paycheck(id:"p_20251030", date:"2025-10-30", amount:577.14,  note:"",                  allocations:[al("savings",100),  al("tithing",57),  al("checking",270.14), al("disney",50), al("bts",50), al("christmas",50)]),
    Paycheck(id:"p_20251113", date:"2025-11-13", amount:797.91,  note:"",                  allocations:[al("savings",200),  al("tithing",79),  al("checking",348.91), al("disney",50), al("bts",50), al("christmas",70)]),
    Paycheck(id:"p_20251128", date:"2025-11-28", amount:803.16,  note:"Disney fund closed",allocations:[al("savings",100),  al("tithing",80),  al("checking",473.16), al("bts",50), al("vacation",50), al("christmas",50)]),
    Paycheck(id:"p_20251211", date:"2025-12-11", amount:502.30,  note:"Christmas used",    allocations:[al("savings",100),  al("tithing",50),  al("checking",222.30), al("bts",20), al("vacation",20), al("christmas",50)]),
    Paycheck(id:"p_20251225", date:"2025-12-25", amount:710.78,  note:"",                  allocations:[al("savings",100),  al("tithing",70),  al("checking",390.78), al("bts",50), al("vacation",50), al("christmas",50)]),
    Paycheck(id:"p_20260108", date:"2026-01-08", amount:712.33,  note:"",                  allocations:[al("savings",100),  al("tithing",70),  al("checking",192.33), al("bts",50), al("vacation",50), al("christmas",50), al("car",250)]),
    Paycheck(id:"p_20260123", date:"2026-01-23", amount:703.67,  note:"",                  allocations:[al("savings",100),  al("checking",203.67), al("bts",50), al("vacation",50), al("christmas",50), al("car",250)]),
    Paycheck(id:"p_20260205", date:"2026-02-05", amount:877.49,  note:"",                  allocations:[al("savings",100),  al("checking",327.49), al("bts",100),al("vacation",50), al("christmas",50), al("car",250)]),
    Paycheck(id:"p_20260221", date:"2026-02-21", amount:649.25,  note:"",                  allocations:[al("savings",100),  al("checking",149.25), al("bts",50), al("vacation",50), al("christmas",50), al("car",250)]),
    Paycheck(id:"p_20260305", date:"2026-03-05", amount:863.49,  note:"",                  allocations:[al("savings",100),  al("checking",363.49), al("bts",50), al("vacation",50), al("christmas",50), al("car",250)]),
    Paycheck(id:"p_20260319", date:"2026-03-19", amount:778.01,  note:"",                  allocations:[al("savings",100),  al("checking",278.01), al("bts",50), al("vacation",50), al("christmas",50), al("car",250)]),
    Paycheck(id:"p_20260402", date:"2026-04-02", amount:618.50,  note:"",                  allocations:[al("savings",100),  al("checking",118.50), al("bts",50), al("vacation",50), al("christmas",50), al("car",250)]),
    Paycheck(id:"p_20260416", date:"2026-04-16", amount:842.14,  note:"Car goal reached",  allocations:[al("savings",100),  al("checking",322.14), al("bts",50), al("vacation",50), al("christmas",50), al("car",250), al("lego",20)]),
    Paycheck(id:"p_20260430", date:"2026-04-30", amount:843.37,  note:"",                  allocations:[al("savings",150),  al("checking",493.37), al("bts",50), al("vacation",50), al("christmas",50), al("lego",50)]),
]

private let seedTransactions: [AppTransaction] = [
    AppTransaction(id:"t_open_sav",   bucketId:"savings",   amount: 2012.15, date:"2025-06-25", note:"Opening balance",           type:"opening"),
    AppTransaction(id:"t_dis1",       bucketId:"disney",    amount:  -27.00, date:"2025-08-07", note:"Ghirardelli's",             type:"spend"),
    AppTransaction(id:"t_dis2",       bucketId:"disney",    amount:  -27.00, date:"2025-09-04", note:"Sunglasses",                type:"spend"),
    AppTransaction(id:"t_dis3",       bucketId:"disney",    amount:  -23.00, date:"2025-09-18", note:"Beignets",                  type:"spend"),
    AppTransaction(id:"t_dis4",       bucketId:"disney",    amount:  -55.00, date:"2025-10-02", note:"Sweats",                    type:"spend"),
    AppTransaction(id:"t_dis5",       bucketId:"disney",    amount:  -32.00, date:"2025-10-16", note:"Necklaces",                 type:"spend"),
    AppTransaction(id:"t_dis6",       bucketId:"disney",    amount:  -40.00, date:"2025-10-30", note:"Hat",                      type:"spend"),
    AppTransaction(id:"t_dis7",       bucketId:"disney",    amount:  -65.00, date:"2025-11-13", note:"Sweatshirt",               type:"spend"),
    AppTransaction(id:"t_dis_xfer",   bucketId:"disney",    amount: -191.00, date:"2025-11-19", note:"Transferred to Christmas", type:"transfer"),
    AppTransaction(id:"t_xmas_dis",   bucketId:"christmas", amount:  191.00, date:"2025-11-19", note:"From Disney fund",         type:"transfer"),
    AppTransaction(id:"t_coins",      bucketId:"checking",  amount:   85.02, date:"2025-11-19", note:"Coins cashed in",          type:"adjustment"),
    AppTransaction(id:"t_xmas_used",  bucketId:"christmas", amount: -411.00, date:"2025-12-11", note:"Christmas 2025 — used",    type:"spend"),
    AppTransaction(id:"t_slcc",       bucketId:"savings",   amount:-1990.50, date:"2026-01-15", note:"SLCC Spring Semester tuition", type:"spend"),
    AppTransaction(id:"t_bts_tix",    bucketId:"bts",       amount: -410.00, date:"2026-04-05", note:"Concert tickets",          type:"spend"),
    AppTransaction(id:"t_bts_skort",  bucketId:"bts",       amount:  -50.00, date:"2026-04-10", note:"Skort",                    type:"spend"),
    AppTransaction(id:"t_bts_outfit", bucketId:"bts",       amount:  -45.00, date:"2026-04-12", note:"Concert outfit",           type:"spend"),
    AppTransaction(id:"t_vac1",       bucketId:"vacation",  amount:  -65.00, date:"2026-03-30", note:"Nick St. George trip",     type:"spend"),
    AppTransaction(id:"t_vac2",       bucketId:"vacation",  amount:   -8.00, date:"2026-03-30", note:"Swig",                     type:"spend"),
    AppTransaction(id:"t_vac3",       bucketId:"vacation",  amount:  -21.00, date:"2026-03-30", note:"Sally's Piercings",        type:"spend"),
    AppTransaction(id:"t_vac4",       bucketId:"vacation",  amount:  -20.00, date:"2026-03-30", note:"McDonald's",               type:"spend"),
    AppTransaction(id:"t_vac5",       bucketId:"vacation",  amount:  -20.00, date:"2026-03-30", note:"Las Vegas souvenirs",      type:"spend"),
    AppTransaction(id:"t_vac6",       bucketId:"vacation",  amount:  -70.00, date:"2026-04-05", note:"Lego Toothless",           type:"spend"),
]

// MARK: - Store

@Observable
class AppStore {
    static let storageKey = "moonay_v2"

    var state: AppState

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(AppState.self, from: data) {
            state = saved
        } else {
            state = AppState(buckets: seedBuckets, paychecks: seedPaychecks, transactions: seedTransactions)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    // ── Mutations ──

    func addPaycheck(_ p: Paycheck)      { state.paychecks.append(p); save() }
    func addTransaction(_ t: AppTransaction) { state.transactions.append(t); save() }
    func addBucket(_ b: Bucket)          { state.buckets.append(b); save() }
    func addBill(_ b: Bill)              { state.bills.append(b); save() }

    func updateBucket(id: String, name: String, colorHex: String, goal: Double?, goalDate: String?, isSpending: Bool) {
        guard let i = state.buckets.firstIndex(where: { $0.id == id }) else { return }
        state.buckets[i].name = name
        state.buckets[i].colorHex = colorHex
        state.buckets[i].goal = goal
        state.buckets[i].goalDate = goalDate
        state.buckets[i].isSpending = isSpending
        save()
    }

    func updatePaycheck(_ paycheck: Paycheck) {
        guard let i = state.paychecks.firstIndex(where: { $0.id == paycheck.id }) else { return }
        state.paychecks[i] = paycheck
        save()
    }

    func setBillPaymentPaid(paycheckId: String, paymentId: String, isPaid: Bool) {
        guard let paycheckIndex = state.paychecks.firstIndex(where: { $0.id == paycheckId }),
              let billIndex = state.paychecks[paycheckIndex].bills.firstIndex(where: { $0.id == paymentId }) else { return }
        state.paychecks[paycheckIndex].bills[billIndex].isPaid = isPaid
        state.paychecks[paycheckIndex].bills[billIndex].paidDate = isPaid ? todayISO() : nil
        save()
    }

    func toggleActive(id: String) {
        guard let i = state.buckets.firstIndex(where: { $0.id == id }) else { return }
        state.buckets[i].isActive.toggle()
        save()
    }

    func archiveBucket(id: String) {
        guard let i = state.buckets.firstIndex(where: { $0.id == id }) else { return }
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
        state = AppState(buckets: seedBuckets, paychecks: seedPaychecks, transactions: seedTransactions)
        save()
    }

    func clearFinancialData() {
        state.paychecks = []
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
        let pay = state.paychecks.flatMap { $0.allocations }
            .filter { $0.bucketId == bucketId }.reduce(0) { $0 + $1.amount }
        let tx = state.transactions
            .filter { $0.bucketId == bucketId }.reduce(0) { $0 + $1.amount }
        return pay + tx
    }

    func lastAlloc(for bucketId: String) -> Double {
        for p in state.paychecks.sorted(by: { $0.date > $1.date }) {
            if let a = p.allocations.first(where: { $0.bucketId == bucketId }) { return a.amount }
        }
        return 0
    }

    func averageAlloc(for bucketId: String) -> Double {
        let values = state.paychecks
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
        let paychecks = max(ceil(Double(days) / 14.0), 1)
        return needed / paychecks
    }

    var lastPaycheck: Paycheck? { state.paychecks.sorted { $0.date > $1.date }.first }

    var savingsBucketIds: Set<String> {
        Set(state.buckets.filter { !$0.isSpending }.map(\.id))
    }

    var activeBuckets: [Bucket] {
        state.buckets.filter { !$0.archived && $0.isActive }.sorted { $0.order < $1.order }
    }
    var savingsBuckets: [Bucket]  { activeBuckets.filter { !$0.isSpending } }
    var spendingBuckets: [Bucket] { activeBuckets.filter {  $0.isSpending } }
    var unpaidBillPayments: [(paycheck: Paycheck, bill: BillPayment)] {
        state.paychecks.flatMap { paycheck in
            paycheck.bills
                .filter { !$0.isPaid }
                .map { (paycheck: paycheck, bill: $0) }
        }
        .sorted { $0.paycheck.date > $1.paycheck.date }
    }

    var unpaidBillsTotal: Double {
        unpaidBillPayments.reduce(0) { $0 + $1.bill.amount }
    }

    var totalSavings: Double      { savingsBuckets.reduce(0) { $0 + balance(for: $1.id) } + unpaidBillsTotal }

    var sortedNonArchived: [Bucket] {
        state.buckets.filter { !$0.archived }.sorted { $0.order < $1.order }
    }

    var activeBills: [Bill] {
        state.bills.filter { $0.isActive }.sorted { $0.order < $1.order }
    }

    var sortedBills: [Bill] {
        state.bills.sorted { $0.order < $1.order }
    }
}

// MARK: - Extensions

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        self.init(
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8)  & 0xFF) / 255,
            blue:  Double( int        & 0xFF) / 255
        )
    }

    func toHex() -> String? {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

private let _currencyFmt: NumberFormatter = {
    let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "USD"; return f
}()

private let isoDateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    return df
}()

func fmt(_ n: Double) -> String { _currencyFmt.string(from: NSNumber(value: n)) ?? "$0.00" }

func fmtDate(_ iso: String) -> String {
    guard let d = isoDateFormatter.date(from: iso) else { return iso }
    let df = DateFormatter()
    df.dateStyle = .medium; df.timeStyle = .none
    return df.string(from: d)
}

func todayISO() -> String {
    isoDateFormatter.string(from: Date())
}

// MARK: - App Entry Point

@main
struct MoonayApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house") }
            AddPaycheckView()
                .tabItem { Label("Add", systemImage: "plus.circle") }
            HistoryView()
                .tabItem { Label("History", systemImage: "list.bullet") }
            NotesView()
                .tabItem { Label("Notes", systemImage: "doc.text") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .tint(Color(hex: "#7C3AED"))
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    @Environment(AppStore.self) var store
    @State private var selectedBucket: Bucket?

    var body: some View {
        NavigationStack {
            List {
                // ── Hero total ──
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Balance")
                            .font(.caption).foregroundStyle(.secondary)
                        Text(fmt(store.totalSavings))
                            .font(.system(size: 42, weight: .bold))
                        Text(store.unpaidBillsTotal > 0
                             ? "Includes \(fmt(store.unpaidBillsTotal)) waiting for bills"
                             : "Across \(store.savingsBuckets.count) savings buckets")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(Color.clear)

                if !store.unpaidBillPayments.isEmpty {
                    Section("Bills To Pay") {
                        ForEach(store.unpaidBillPayments, id: \.bill.id) { item in
                            HStack(spacing: 10) {
                                Button {
                                    store.setBillPaymentPaid(paycheckId: item.paycheck.id, paymentId: item.bill.id, isPaid: true)
                                } label: {
                                    Image(systemName: "circle")
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color(hex: "#7C3AED"))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.bill.name)
                                    Text(fmtDate(item.paycheck.date))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(fmt(item.bill.amount))
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }

                // ── Last paycheck ──
                if let last = store.lastPaycheck {
                    Section {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("LAST PAYCHECK")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(fmt(last.amount))
                                .font(.system(size: 20, weight: .bold))
                            Text(fmtDate(last.date))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }

                // ── Savings buckets ──
                if !store.savingsBuckets.isEmpty {
                    Section("Buckets") {
                        ForEach(store.savingsBuckets) { bucket in
                            BucketRowView(bucket: bucket)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedBucket = bucket }
                        }
                    }
                }

                // ── Spending buckets — quiet footer ──
                if !store.spendingBuckets.isEmpty, store.lastPaycheck != nil {
                    Section("This Check") {
                        VStack(spacing: 8) {
                            ForEach(store.spendingBuckets) { b in
                                Button { selectedBucket = b } label: {
                                    HStack(spacing: 8) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(b.color).frame(width: 8, height: 8)
                                        Text(b.name)
                                            .font(.system(size: 13)).foregroundStyle(.secondary)
                                        Spacer()
                                        Text(fmt(store.lastAlloc(for: b.id)))
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Color(.tertiaryLabel))
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("All my moonay")
            .sheet(item: $selectedBucket) { BucketDetailView(bucket: $0) }
        }
    }
}

// Horizontal wrapping layout for the spending footer
struct FlowRow<Content: View>: View {
    let spacing: CGFloat
    private let content: () -> Content

    init(spacing: CGFloat, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        HStack(spacing: spacing) {
            content()
        }
    }
}


// MARK: - Bucket Row

struct BucketRowView: View {
    @Environment(AppStore.self) var store
    let bucket: Bucket

    var body: some View {
        let bal    = store.balance(for: bucket.id)
        let lastA  = store.lastAlloc(for: bucket.id)
        let goalMet = bucket.goal.map { bal >= $0 } ?? false
        let display = bucket.isSpending ? lastA : bal

        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 7)
                .fill(bucket.color).frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(bucket.name)
                if let g = bucket.goal {
                    Text(goalMet ? "Goal reached" : "Goal: \(fmt(g))")
                        .font(.caption).foregroundStyle(.secondary)
                } else if let goalDate = bucket.goalDate {
                    Text("Save by \(fmtDate(goalDate))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                if goalMet {
                    Text("Met")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: "#F59E0B"))
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color(hex: "#FFFBEB")).clipShape(Capsule())
                }
                VStack(alignment: .trailing, spacing: 1) {
                    Text(fmt(display)).foregroundStyle(.secondary)
                    if bucket.isSpending {
                        Text("this check").font(.system(size: 11)).foregroundStyle(Color(.tertiaryLabel))
                    }
                }
            }
        }
    }
}

// MARK: - Bucket Detail (sheet)

struct BucketDetailView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss
    let bucket: Bucket

    @State private var showSpendForm = false
    @State private var spendAmt  = ""
    @State private var spendNote = ""

    var balance: Double { store.balance(for: bucket.id) }
    var lastA: Double   { store.lastAlloc(for: bucket.id) }
    var goalMet: Bool   { bucket.goal.map { balance >= $0 } ?? false }

    struct HistoryItem: Identifiable {
        var id: String; var date: String; var amount: Double; var label: String
    }

    var history: [HistoryItem] {
        var items: [HistoryItem] = []
        for p in store.state.paychecks {
            if let a = p.allocations.first(where: { $0.bucketId == bucket.id }) {
                items.append(.init(id: p.id, date: p.date, amount: a.amount,
                                   label: p.note.isEmpty ? "Paycheck" : p.note))
            }
        }
        for t in store.state.transactions.filter({ $0.bucketId == bucket.id }) {
            items.append(.init(id: t.id, date: t.date, amount: t.amount, label: t.note))
        }
        return items.sorted { $0.date > $1.date }
    }

    var barData: [(index: Int, value: Double)] {
        let contribs = store.state.paychecks
            .compactMap { p -> Double? in
                p.allocations.first(where: { $0.bucketId == bucket.id })?.amount
            }
        return contribs.suffix(10).enumerated().map { (index: $0.offset, value: $0.element) }
    }

    var body: some View {
        NavigationStack {
            List {
                headerSection
                spendSection
                chartSection
                historySection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(bucket.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(bucket.color).frame(width: 40, height: 40)
                    let subtitle = bucket.isSpending ? "Spending allocation"
                        : goalMet ? "Goal reached!" : "Savings bucket"
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(bucket.isSpending ? "Last paycheck" : "Balance")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(fmt(bucket.isSpending ? lastA : balance))
                        .font(.system(size: 38, weight: .bold))
                }
                if !bucket.isSpending, let goal = bucket.goal {
                    let pct = min(Int((balance / goal) * 100), 100)
                    VStack(spacing: 4) {
                        HStack {
                            Text("\(fmt(balance)) of \(fmt(goal))")
                            Spacer()
                            Text("\(pct)%")
                        }
                        .font(.caption).foregroundStyle(.secondary)
                        ProgressView(value: min(balance / goal, 1.0))
                            .tint(goalMet ? Color(hex: "#F59E0B") : bucket.color)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var spendSection: some View {
        if bucket.isSpending {
            Section {
                Text("This is your spending account. Allocations are logged each paycheck — no need to track individual purchases here.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        } else {
            Section {
                if !showSpendForm {
                    Button("Record Spending") { showSpendForm = true }
                        .foregroundStyle(bucket.color)
                } else {
                    VStack(spacing: 10) {
                        HStack {
                            Text("$").foregroundStyle(.secondary)
                            TextField("0.00", text: $spendAmt).keyboardType(.decimalPad)
                            Divider()
                            TextField("Note", text: $spendNote)
                        }
                        HStack(spacing: 10) {
                            Button("Save") { saveSpend() }
                                .buttonStyle(.borderedProminent).tint(bucket.color)
                            Button("Cancel") {
                                showSpendForm = false; spendAmt = ""; spendNote = ""
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var chartSection: some View {
        if barData.count > 1 {
            Section("Contribution History") {
                Chart(barData, id: \.index) { item in
                    BarMark(x: .value("Pay", item.index),
                            y: .value("Amount", item.value))
                    .foregroundStyle(bucket.color.opacity(0.75))
                    .cornerRadius(3)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 64)
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        Section("Transactions") {
            if history.isEmpty {
                Text("No transactions yet").foregroundStyle(.secondary)
            } else {
                ForEach(history) { (item: HistoryItem) in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.label)
                            Text(fmtDate(item.date))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text((item.amount >= 0 ? "+" : "") + fmt(item.amount))
                            .fontWeight(.semibold)
                            .foregroundStyle(item.amount >= 0 ? Color.primary : Color.red)
                    }
                }
            }
        }
    }

    private func saveSpend() {
        guard let amt = Double(spendAmt), amt > 0 else { return }
        store.addTransaction(AppTransaction(
            id: UUID().uuidString, bucketId: bucket.id,
            amount: -amt, date: todayISO(),
            note: spendNote.isEmpty ? "Spending" : spendNote,
            type: "spend"
        ))
        showSpendForm = false; spendAmt = ""; spendNote = ""
    }
}

// MARK: - Add Paycheck

struct AddPaycheckView: View {
    @Environment(AppStore.self) var store

    var paycheckToEdit: Paycheck?
    var onSaved: (() -> Void)?

    @State private var date     = Date()
    @State private var totalStr = ""
    @State private var note     = ""
    @State private var billAmounts = [String: String]()
    @State private var includedBills = Set<String>()
    @State private var allocs   = [String: String]()
    @State private var saved    = false

    var total: Double { Double(totalStr) ?? 0 }
    var billTotal: Double {
        store.activeBills.reduce(0) { sum, bill in
            guard includedBills.contains(bill.id) else { return sum }
            return sum + (Double(billAmounts[bill.id] ?? "") ?? 0)
        }
    }
    var allocated: Double {
        store.activeBuckets.reduce(0) { $0 + (Double(allocs[$1.id] ?? "") ?? 0) }
    }
    var envelopeMoney: Double { total - billTotal }
    var remaining: Double { envelopeMoney - allocated }
    var isGood:  Bool { abs(remaining) < 0.005 }
    var isClose: Bool { abs(remaining) < 1 && !isGood }
    var isEditing: Bool { paycheckToEdit != nil }
    var titheAmount: Double { total * 0.10 }

    var body: some View {
        NavigationStack {
            if saved {
                VStack(spacing: 16) {
                    Text(isEditing ? "Saved" : "🎉").font(.system(size: isEditing ? 34 : 64, weight: .bold))
                    Text(isEditing ? "Paycheck updated!" : "Paycheck saved!").font(.title.bold())
                    Text("Nice work staying on top of it.").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section("Info") {
                        HStack {
                            Text("Total")
                            Spacer()
                            MoneyEntryField(text: $totalStr, placeholder: "0.00", width: 110)
                        }
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                        HStack {
                            Text("Note")
                            Spacer()
                            TextField("Optional", text: $note)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if total > 0 {
                        if !store.activeBills.isEmpty {
                            Section("Bills") {
                                HStack(spacing: 10) {
                                    Button("Half Bills") { fillBills(multiplier: 0.5) }
                                        .buttonStyle(.bordered)
                                    Button("Full Bills") { fillBills(multiplier: 1.0) }
                                        .buttonStyle(.bordered)
                                }
                                .padding(.vertical, 2)
                                ForEach(store.activeBills) { bill in
                                    HStack(spacing: 12) {
                                        Toggle("", isOn: Binding(
                                            get: { includedBills.contains(bill.id) },
                                            set: { isIncluded in
                                                if isIncluded {
                                                    includedBills.insert(bill.id)
                                                    if billAmounts[bill.id] == nil {
                                                        billAmounts[bill.id] = String(format: "%.2f", bill.amount)
                                                    }
                                                } else {
                                                    includedBills.remove(bill.id)
                                                }
                                            }
                                        ))
                                        .labelsHidden()
                                        Text(bill.name)
                                        Spacer()
                                        MoneyEntryField(text: Binding(
                                            get: { billAmounts[bill.id] ?? String(format: "%.2f", bill.amount) },
                                            set: { billAmounts[bill.id] = $0 }
                                        ), placeholder: "0.00", width: 92)
                                        .disabled(!includedBills.contains(bill.id))
                                        .foregroundStyle(includedBills.contains(bill.id) ? Color.primary : Color.secondary)
                                    }
                                }
                            }
                        }

                        Section {
                            VStack(spacing: 8) {
                                HStack {
                                    Text("After bills")
                                    Spacer()
                                    Text(fmt(envelopeMoney))
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                                let color: Color = isGood ? .green : isClose ? Color(hex:"#FF9500") : .red
                                HStack {
                                    Text(isGood ? "Fully allocated" : "Remaining: \(fmt(remaining))")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(color)
                                    Spacer()
                                    Text("\(fmt(allocated)) / \(fmt(envelopeMoney))")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Section("Allocate") {
                        ForEach(store.activeBuckets) { bucket in
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(bucket.color).frame(width: 26, height: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bucket.name)
                                    if let hint = allocationHint(for: bucket) {
                                        Text(hint)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                MoneyEntryField(text: Binding(
                                    get: { allocs[bucket.id] ?? "" },
                                    set: { allocs[bucket.id] = $0 }
                                ), placeholder: "0", width: 86)
                                if isTithing(bucket) {
                                    Button("10%") {
                                        allocs[bucket.id] = String(format: "%.2f", titheAmount)
                                    }
                                    .font(.system(size: 12, weight: .semibold))
                                    .buttonStyle(.bordered)
                                    .disabled(total <= 0)
                                }
                            }
                        }
                    }

                    Section {
                        Button { handleSave() } label: {
                            Text(isEditing ? "Update Paycheck" : "Save Paycheck")
                                .frame(maxWidth: .infinity).font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "#7C3AED"))
                        .disabled(total <= 0)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
                .listStyle(.insetGrouped)
                .navigationTitle(isEditing ? "Edit Paycheck" : "Add Paycheck")
                .onAppear { prepareForm() }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button {
                            hideKeyboard()
                        } label: {
                            Text("Done")
                                .fontWeight(.semibold)
                        }
                        .accessibilityLabel("Close keyboard")
                    }
                }
            }
        }
    }

    private func handleSave() {
        guard total > 0 else { return }
        let bills = store.activeBills.compactMap { bill -> BillPayment? in
            guard includedBills.contains(bill.id),
                  let amount = Double(billAmounts[bill.id] ?? ""),
                  amount > 0 else { return nil }
            let existing = paycheckToEdit?.bills.first { $0.billId == bill.id }
            return BillPayment(
                id: existing?.id ?? UUID().uuidString,
                billId: bill.id,
                name: bill.name,
                amount: amount,
                isPaid: existing?.isPaid ?? false,
                paidDate: existing?.paidDate
            )
        }
        let paycheck = Paycheck(
            id: paycheckToEdit?.id ?? UUID().uuidString,
            date: isoDateFormatter.string(from: date),
            amount: total,
            note: note,
            bills: bills,
            allocations: store.activeBuckets.compactMap { b in
                guard let v = Double(allocs[b.id] ?? ""), v > 0 else { return nil }
                return Allocation(bucketId: b.id, amount: v)
            }
        )
        if isEditing {
            store.updatePaycheck(paycheck)
        } else {
            store.addPaycheck(paycheck)
        }
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if isEditing {
                onSaved?()
            } else {
                saved = false; totalStr = ""; allocs = [:]; note = ""; date = Date()
                billAmounts = [:]; includedBills = []; prepareBills()
            }
        }
    }

    private func prepareForm() {
        if let paycheckToEdit, totalStr.isEmpty, allocs.isEmpty, billAmounts.isEmpty {
            totalStr = String(format: "%.2f", paycheckToEdit.amount)
            date = isoDateFormatter.date(from: paycheckToEdit.date) ?? Date()
            note = paycheckToEdit.note
            allocs = Dictionary(uniqueKeysWithValues: paycheckToEdit.allocations.map { ($0.bucketId, String(format: "%.2f", $0.amount)) })
            billAmounts = Dictionary(uniqueKeysWithValues: paycheckToEdit.bills.map { ($0.billId, String(format: "%.2f", $0.amount)) })
            includedBills = Set(paycheckToEdit.bills.map(\.billId))
        } else {
            prepareBills()
        }
    }

    private func prepareBills() {
        guard billAmounts.isEmpty && includedBills.isEmpty else { return }
        for bill in store.activeBills {
            includedBills.insert(bill.id)
            billAmounts[bill.id] = String(format: "%.2f", bill.amount)
        }
    }

    private func fillBills(multiplier: Double) {
        for bill in store.activeBills {
            includedBills.insert(bill.id)
            billAmounts[bill.id] = String(format: "%.2f", bill.amount * multiplier)
        }
    }

    private func allocationHint(for bucket: Bucket) -> String? {
        if let suggested = store.suggestedGoalContribution(for: bucket), suggested > 0 {
            return "Need \(fmt(suggested))/check by \(fmtDate(bucket.goalDate ?? ""))"
        }
        if isTithing(bucket), total > 0 {
            return "10%: \(fmt(titheAmount))"
        }
        let last = store.lastAlloc(for: bucket.id)
        if last > 0 { return "Last: \(fmt(last))" }
        let average = store.averageAlloc(for: bucket.id)
        if average > 0 { return "Avg: \(fmt(average))" }
        return nil
    }

    private func isTithing(_ bucket: Bucket) -> Bool {
        bucket.id.lowercased() == "tithing" || bucket.name.lowercased().contains("tith")
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct MoneyEntryField: View {
    @Binding var text: String
    var placeholder: String
    var width: CGFloat

    var body: some View {
        HStack(spacing: 2) {
            Text("$")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
        .frame(width: width)
    }
}

// MARK: - History

struct HistoryView: View {
    @Environment(AppStore.self) var store
    @State private var expandedId: String?
    @State private var editingPaycheck: Paycheck?
    @State private var savingsRange: SavingsRange = .year

    var sorted: [Paycheck]  { store.state.paychecks.sorted { $0.date > $1.date } }
    var savingsChart: [SavingsPoint] {
        let all = savingsBalancePoints()
        guard let cutoff = savingsRange.cutoffDate else { return all }
        let previous = all.last { $0.date < cutoff }
        let filtered = all.filter { $0.date >= cutoff }
        if let previous, !filtered.contains(where: { $0.id == previous.id }) {
            return [previous] + filtered
        }
        return filtered
    }

    var body: some View {
        NavigationStack {
            List {
                // ── Savings tracker ──
                if savingsChart.count >= 2 {
                    Section {
                        Picker("Range", selection: $savingsRange) {
                            ForEach(SavingsRange.allCases) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)

                        Chart(savingsChart) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Balance", point.balance)
                            )
                            .foregroundStyle(Color(hex: "#7C3AED"))
                            .interpolationMethod(.catmullRom)
                            AreaMark(
                                x: .value("Date", point.date),
                                y: .value("Balance", point.balance)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex:"#7C3AED").opacity(0.18), .clear],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Balance", point.balance)
                            )
                            .foregroundStyle(Color(hex: "#7C3AED"))
                            .symbolSize(18)
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 4))
                        }
                        .chartYAxis(.hidden)
                        .frame(height: 110)
                        .contentTransition(.opacity)

                        HStack {
                            Text("Savings Balance")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(fmt(savingsChart.last?.balance ?? 0))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color(hex: "#7C3AED"))
                        }
                    }
                }

                // ── Paycheck list ──
                Section("\(sorted.count) Paychecks") {
                    ForEach(sorted) { p in
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedId == p.id },
                                set: { expandedId = $0 ? p.id : nil }
                            )
                        ) {
                            if !p.bills.isEmpty {
                                SectionBillRows(paycheckId: p.id, bills: p.bills)
                            }
                            ForEach(p.allocations, id: \.bucketId) { a in
                                let b = store.state.buckets.first { $0.id == a.bucketId }
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(b?.color ?? .gray).frame(width: 18, height: 18)
                                    Text(b?.name ?? a.bucketId)
                                        .font(.subheadline).foregroundStyle(.secondary)
                                    Spacer()
                                    Text(fmt(a.amount)).font(.subheadline)
                                }
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fmtDate(p.date))
                                    if !p.note.isEmpty {
                                        Text(p.note).font(.caption)
                                            .foregroundStyle(Color(hex: "#7C3AED"))
                                    }
                                }
                                Spacer()
                                Text(fmt(p.amount)).foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Edit") { editingPaycheck = p }
                                .tint(Color(hex: "#7C3AED"))
                        }
                        .contextMenu {
                            Button("Edit Paycheck") { editingPaycheck = p }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("History")
            .sheet(item: $editingPaycheck) { paycheck in
                AddPaycheckView(paycheckToEdit: paycheck) {
                    editingPaycheck = nil
                }
            }
        }
    }

    private func savingsBalancePoints() -> [SavingsPoint] {
        var events: [(date: Date, amount: Double)] = []
        let savingsIds = store.savingsBucketIds

        for paycheck in store.state.paychecks {
            guard let date = isoDateFormatter.date(from: paycheck.date) else { continue }
            let amount = paycheck.allocations
                .filter { savingsIds.contains($0.bucketId) }
                .reduce(0) { $0 + $1.amount }
            if amount != 0 { events.append((date, amount)) }
            for bill in paycheck.bills {
                events.append((date, bill.amount))
                if bill.isPaid, let paidDate = bill.paidDate.flatMap({ isoDateFormatter.date(from: $0) }) {
                    events.append((paidDate, -bill.amount))
                }
            }
        }

        for transaction in store.state.transactions {
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
}

enum SavingsRange: String, CaseIterable, Identifiable {
    case month = "Month"
    case year = "Year"
    case fiveYears = "5Y"
    case all = "All"

    var id: String { rawValue }

    var cutoffDate: Date? {
        let calendar = Calendar.current
        switch self {
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: Date())
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: Date())
        case .fiveYears:
            return calendar.date(byAdding: .year, value: -5, to: Date())
        case .all:
            return nil
        }
    }
}

struct SavingsPoint: Identifiable {
    var id: String
    var date: Date
    var balance: Double
}

struct SectionBillRows: View {
    @Environment(AppStore.self) var store
    let paycheckId: String
    let bills: [BillPayment]

    var body: some View {
        ForEach(bills) { bill in
            HStack(spacing: 8) {
                Button {
                    store.setBillPaymentPaid(paycheckId: paycheckId, paymentId: bill.id, isPaid: !bill.isPaid)
                } label: {
                    Image(systemName: bill.isPaid ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(bill.isPaid ? .green : Color(hex: "#7C3AED"))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 1) {
                    Text(bill.name)
                        .font(.subheadline)
                    Text(bill.isPaid ? "Paid" : "Needs transfer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(fmt(bill.amount)).font(.subheadline)
            }
        }
    }
}

// MARK: - Notes (Lauren View)

struct NotesView: View {
    @Environment(AppStore.self) var store
    @State private var copied = false

    var sorted: [Paycheck] { store.state.paychecks.sorted { $0.date > $1.date } }

    func bucketName(_ id: String) -> String {
        store.state.buckets.first { $0.id == id }?.name ?? id
    }

    func shortDate(_ iso: String) -> String {
        let p = iso.split(separator: "-")
        guard p.count == 3,
              let m = Int(p[1]), let d = Int(p[2]) else { return iso }
        return "\(m)/\(d)/\(String(p[0]).suffix(2))"
    }

    func buildText() -> String {
        store.state.paychecks.sorted { $0.date < $1.date }.map { p in
            var lines = [shortDate(p.date), "$\(String(format: "%.2f", p.amount))"]
            for bill in p.bills {
                lines.append("\(bill.name)- \(String(format: "%.2f", bill.amount))")
            }
            for a in p.allocations {
                lines.append("\(bucketName(a.bucketId))- \(String(format: "%.2f", a.amount))")
            }
            if !p.note.isEmpty { lines.append(p.note) }
            return lines.joined(separator: "\n")
        }.joined(separator: "\n\n")
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sorted) { p in
                    Section {
                        HStack {
                            Text(shortDate(p.date)).font(.headline)
                            Spacer()
                            Text("$\(String(format: "%.2f", p.amount))").font(.headline)
                        }
                        if !p.note.isEmpty {
                            Text(p.note.uppercased())
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(hex: "#7C3AED"))
                        }
                        ForEach(p.bills) { bill in
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(hex: "#7C3AED"))
                                    .frame(width: 8, height: 8)
                                Text("\(bill.name)-")
                                    .font(.callout).foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "%.2f", bill.amount)).font(.callout)
                            }
                        }
                        ForEach(p.allocations, id: \.bucketId) { a in
                            let b = store.state.buckets.first { $0.id == a.bucketId }
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(b?.color ?? .gray).frame(width: 8, height: 8)
                                Text("\(bucketName(a.bucketId))-")
                                    .font(.callout).foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "%.2f", a.amount)).font(.callout)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(copied ? "Copied!" : "Copy All") {
                        UIPasteboard.general.string = buildText()
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                    }
                    .foregroundStyle(copied ? .green : Color(hex: "#7C3AED"))
                }
            }
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Environment(AppStore.self) var store
    @State private var editingBucket: Bucket?
    @State private var editingBill: Bill?
    @State private var showAddBucket    = false
    @State private var showAddBill      = false
    @State private var showArchived     = false
    @State private var showResetConfirm = false
    @State private var resetText        = ""
    @State private var showExporter     = false
    @State private var showImporter     = false
    @State private var showImportConfirm = false
    @State private var backupDocument: MoonayBackupDocument?
    @State private var pendingImport: AppState?
    @State private var dataMessage: String?

    var active:   [Bucket] { store.sortedNonArchived.filter  { $0.isActive  } }
    var inactive: [Bucket] { store.sortedNonArchived.filter  { !$0.isActive } }
    var archived: [Bucket] { store.state.buckets.filter { $0.archived }.sorted { $0.order < $1.order } }

    var body: some View {
        NavigationStack {
            List {
                if !active.isEmpty {
                    Section("Active Buckets") {
                        ForEach(active) { b in
                            BucketSettingRow(bucket: b) { editingBucket = b }
                        }
                        .onMove { store.moveBuckets(from: $0, to: $1, among: active) }
                    }
                }

                if !inactive.isEmpty {
                    Section("Planned Buckets") {
                        ForEach(inactive) { b in
                            BucketSettingRow(bucket: b) { editingBucket = b }
                        }
                        .onMove { store.moveBuckets(from: $0, to: $1, among: inactive) }
                    }
                }

                Section {
                    Button("+ New Bucket") { showAddBucket = true }
                        .foregroundStyle(Color(hex: "#7C3AED"))
                }

                Section("Bills") {
                    ForEach(store.sortedBills) { bill in
                        BillSettingRow(bill: bill) { editingBill = bill }
                    }
                    Button("+ New Bill") { showAddBill = true }
                        .foregroundStyle(Color(hex: "#7C3AED"))
                }

                if !archived.isEmpty {
                    Section {
                        DisclosureGroup("Archived (\(archived.count))", isExpanded: $showArchived) {
                            ForEach(archived) { b in
                                BucketSettingRow(bucket: b) { editingBucket = b }
                            }
                        }
                    }
                }

                Section("Data") {
                    Button("Export Backup") { startExport() }
                    Button("Import Backup") { showImporter = true }
                    Button("Reset All Data", role: .destructive) { showResetConfirm = true }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .toolbar { EditButton() }
            .sheet(item: $editingBucket) { BucketEditView(bucket: $0) }
            .sheet(item: $editingBill) { BillEditView(bill: $0) }
            .sheet(isPresented: $showAddBucket) { BucketAddView() }
            .sheet(isPresented: $showAddBill) { BillAddView() }
            .sheet(isPresented: $showResetConfirm) {
                ResetDataView(resetText: $resetText) {
                    store.clearFinancialData()
                    resetText = ""
                    showResetConfirm = false
                    dataMessage = "Financial history cleared."
                }
            }
            .confirmationDialog("Restore Backup?", isPresented: $showImportConfirm, titleVisibility: .visible) {
                Button("Restore Backup", role: .destructive) {
                    if let pendingImport {
                        store.restoreBackup(pendingImport)
                        dataMessage = "Backup restored."
                    }
                    pendingImport = nil
                }
                Button("Cancel", role: .cancel) { pendingImport = nil }
            } message: {
                Text("This replaces the data currently on this device. Export a backup first if you want to keep it.")
            }
            .fileExporter(
                isPresented: $showExporter,
                document: backupDocument,
                contentType: .json,
                defaultFilename: "Moonay Backup \(todayISO())"
            ) { result in
                switch result {
                case .success:
                    dataMessage = "Backup exported."
                case .failure(let error):
                    dataMessage = error.localizedDescription
                }
                backupDocument = nil
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
            .alert("Moonay Data", isPresented: Binding(
                get: { dataMessage != nil },
                set: { if !$0 { dataMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(dataMessage ?? "")
            }
        }
    }

    private func startExport() {
        do {
            backupDocument = MoonayBackupDocument(data: try store.backupData())
            showExporter = true
        } catch {
            dataMessage = error.localizedDescription
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let data = try Data(contentsOf: url)
            pendingImport = try store.decodedBackup(from: data)
            showImportConfirm = true
        } catch {
            dataMessage = error.localizedDescription
        }
    }
}

struct ResetDataView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var resetText: String
    let onReset: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This clears paychecks, transactions, and unpaid bill history. Your bucket and bill setup stays, but balances go to $0.")
                        .foregroundStyle(.secondary)
                    TextField("Type Lauren", text: $resetText)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Type Lauren to reset all data")
                }

                Section {
                    Button("Reset All Data", role: .destructive) {
                        onReset()
                    }
                    .disabled(resetText != "Lauren")
                }
            }
            .navigationTitle("Reset Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        resetText = ""
                        dismiss()
                    }
                }
            }
        }
    }
}

struct BillSettingRow: View {
    @Environment(AppStore.self) var store
    let bill: Bill
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .foregroundStyle(Color(hex: "#7C3AED"))
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(bill.name)
                Text(fmt(bill.amount)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(bill.isActive ? "Active" : "Off") {
                store.toggleBillActive(id: bill.id)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(bill.isActive ? Color(hex:"#7C3AED") : .secondary)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(bill.isActive ? Color(hex:"#EDE9FE") : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .buttonStyle(.plain)

            Button("Edit", action: onEdit)
                .font(.system(size: 13)).foregroundStyle(.secondary)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .buttonStyle(.plain)
        }
    }
}

struct BillEditView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss
    let bill: Bill

    @State private var name: String
    @State private var amountStr: String

    init(bill: Bill) {
        self.bill = bill
        _name = State(initialValue: bill.name)
        _amountStr = State(initialValue: String(format: "%.2f", bill.amount))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Name"); Spacer()
                        TextField("Bill name", text: $name).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Amount"); Spacer()
                        Text("$").foregroundStyle(.secondary)
                        TextField("0.00", text: $amountStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                }
            }
            .navigationTitle("Edit Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty, let amount = Double(amountStr), amount >= 0 else { return }
                        store.updateBill(id: bill.id, name: trimmed, amount: amount)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || Double(amountStr) == nil)
                }
            }
        }
    }
}

struct BillAddView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var amountStr = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Name"); Spacer()
                        TextField("Bill name", text: $name).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Amount"); Spacer()
                        Text("$").foregroundStyle(.secondary)
                        TextField("0.00", text: $amountStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                }
            }
            .navigationTitle("New Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty, let amount = Double(amountStr), amount >= 0 else { return }
                        let maxOrder = store.state.bills.map { $0.order }.max() ?? -1
                        store.addBill(Bill(
                            id: UUID().uuidString,
                            name: trimmed,
                            amount: amount,
                            isActive: true,
                            order: maxOrder + 1
                        ))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || Double(amountStr) == nil)
                }
            }
        }
    }
}

struct BucketSettingRow: View {
    @Environment(AppStore.self) var store
    let bucket: Bucket
    let onEdit: () -> Void

    var meta: String {
        var p: [String] = []
        if bucket.isSpending  { p.append("spending") }
        if let g = bucket.goal { p.append("goal: \(fmt(g))") }
        if let d = bucket.goalDate { p.append("by \(fmtDate(d))") }
        if bucket.archived    { p.append("archived") }
        return p.isEmpty ? "savings bucket" : p.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 7)
                .fill(bucket.color).frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(bucket.name)
                Text(meta).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !bucket.archived {
                Button(bucket.isActive ? "Active" : "Activate") {
                    store.toggleActive(id: bucket.id)
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(bucket.isActive ? Color(hex:"#7C3AED") : .secondary)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(bucket.isActive ? Color(hex:"#EDE9FE") : Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .buttonStyle(.plain)

                Button("Edit", action: onEdit)
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .buttonStyle(.plain)
            }
        }
    }
}

struct BucketEditView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss
    let bucket: Bucket

    @State private var name:       String
    @State private var selectedColor: Color
    @State private var goalStr:    String
    @State private var hasGoalDate: Bool
    @State private var goalDate: Date
    @State private var isSpending: Bool
    @State private var showArchive = false

    init(bucket: Bucket) {
        self.bucket   = bucket
        _name         = State(initialValue: bucket.name)
        _selectedColor = State(initialValue: Color(hex: bucket.colorHex))
        _goalStr      = State(initialValue: bucket.goal.map { String($0) } ?? "")
        _hasGoalDate  = State(initialValue: bucket.goalDate != nil)
        _goalDate     = State(initialValue: bucket.goalDate.flatMap { isoDateFormatter.date(from: $0) } ?? Date())
        _isSpending   = State(initialValue: bucket.isSpending)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Name"); Spacer()
                        TextField("Bucket name", text: $name).multilineTextAlignment(.trailing)
                    }
                    ColorPicker("Color", selection: $selectedColor)
                    HStack {
                        Text("Savings Goal"); Spacer()
                        Text("$").foregroundStyle(.secondary)
                        TextField("None", text: $goalStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing).frame(width: 80)
                    }
                    Toggle("Save By Date", isOn: $hasGoalDate)
                    if hasGoalDate {
                        DatePicker("Save By", selection: $goalDate, displayedComponents: .date)
                    }
                    Toggle("Spending Bucket", isOn: $isSpending)
                }
                Section {
                    Button("Archive Bucket", role: .destructive) { showArchive = true }
                }
            }
            .navigationTitle("Edit \(bucket.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateBucket(id: bucket.id, name: name,
                                           colorHex: selectedColor.toHex() ?? bucket.colorHex,
                                           goal: Double(goalStr),
                                           goalDate: hasGoalDate ? isoDateFormatter.string(from: goalDate) : nil,
                                           isSpending: isSpending)
                        dismiss()
                    }.fontWeight(.semibold)
                }
            }
            .confirmationDialog("Archive \(bucket.name)?", isPresented: $showArchive, titleVisibility: .visible) {
                Button("Archive", role: .destructive) { store.archiveBucket(id: bucket.id); dismiss() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

struct BucketAddView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss

    @State private var name          = ""
    @State private var selectedColor = Color(hex: "#7C3AED")
    @State private var goalStr       = ""
    @State private var hasGoalDate   = false
    @State private var goalDate      = Date()
    @State private var isSpending    = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Name"); Spacer()
                        TextField("Bucket name", text: $name).multilineTextAlignment(.trailing)
                    }
                    ColorPicker("Color", selection: $selectedColor)
                    HStack {
                        Text("Savings Goal"); Spacer()
                        Text("$").foregroundStyle(.secondary)
                        TextField("Optional", text: $goalStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing).frame(width: 80)
                    }
                    Toggle("Save By Date", isOn: $hasGoalDate)
                    if hasGoalDate {
                        DatePicker("Save By", selection: $goalDate, displayedComponents: .date)
                    }
                    Toggle("Spending Bucket", isOn: $isSpending)
                }
            }
            .navigationTitle("New Bucket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        let maxOrder = store.state.buckets.map { $0.order }.max() ?? -1
                        store.addBucket(Bucket(
                            id: UUID().uuidString, name: trimmed,
                            colorHex: selectedColor.toHex() ?? "#7C3AED",
                            isActive: true, archived: false,
                            goal: Double(goalStr),
                            goalDate: hasGoalDate ? isoDateFormatter.string(from: goalDate) : nil,
                            isSpending: isSpending,
                            order: maxOrder + 1
                        ))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            
        }
        
    }
   

    

}

#Preview {
    ContentView()
        .environment(AppStore())
}
