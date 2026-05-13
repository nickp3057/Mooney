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

// MARK: - Models

struct Bucket: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var colorHex: String
    var isActive: Bool
    var archived: Bool
    var goal: Double?
    var isSpending: Bool
    var order: Int

    var color: Color { Color(hex: colorHex) }
}

struct Allocation: Codable, Hashable {
    var bucketId: String
    var amount: Double
}

struct Paycheck: Identifiable, Codable, Hashable {
    var id: String
    var date: String  // yyyy-MM-dd
    var amount: Double
    var note: String
    var allocations: [Allocation]
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
}

// MARK: - Seed Data

private func al(_ id: String, _ amt: Double) -> Allocation { Allocation(bucketId: id, amount: amt) }

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
    var state: AppState

    init() {
        if let data = UserDefaults.standard.data(forKey: "moonay_v2"),
           let saved = try? JSONDecoder().decode(AppState.self, from: data) {
            state = saved
        } else {
            state = AppState(buckets: seedBuckets, paychecks: seedPaychecks, transactions: seedTransactions)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: "moonay_v2")
        }
    }

    // ── Mutations ──

    func addPaycheck(_ p: Paycheck)      { state.paychecks.append(p); save() }
    func addTransaction(_ t: AppTransaction) { state.transactions.append(t); save() }
    func addBucket(_ b: Bucket)          { state.buckets.append(b); save() }

    func updateBucket(id: String, name: String, colorHex: String, goal: Double?, isSpending: Bool) {
        guard let i = state.buckets.firstIndex(where: { $0.id == id }) else { return }
        state.buckets[i].name = name
        state.buckets[i].colorHex = colorHex
        state.buckets[i].goal = goal
        state.buckets[i].isSpending = isSpending
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

    var lastPaycheck: Paycheck? { state.paychecks.sorted { $0.date > $1.date }.first }

    var activeBuckets: [Bucket] {
        state.buckets.filter { !$0.archived && $0.isActive }.sorted { $0.order < $1.order }
    }
    var savingsBuckets: [Bucket]  { activeBuckets.filter { !$0.isSpending } }
    var spendingBuckets: [Bucket] { activeBuckets.filter {  $0.isSpending } }
    var totalSavings: Double      { savingsBuckets.reduce(0) { $0 + balance(for: $1.id) } }

    var sortedNonArchived: [Bucket] {
        state.buckets.filter { !$0.archived }.sorted { $0.order < $1.order }
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

func fmt(_ n: Double) -> String { _currencyFmt.string(from: NSNumber(value: n)) ?? "$0.00" }

func fmtDate(_ iso: String) -> String {
    let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
    guard let d = df.date(from: iso) else { return iso }
    df.dateStyle = .medium; df.timeStyle = .none
    return df.string(from: d)
}

func todayISO() -> String {
    let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"; return df.string(from: Date())
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
                        Text("Across \(store.savingsBuckets.count) savings buckets")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(Color.clear)

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
                    Section {
                        FlowRow(spacing: 14) {
                            Text("THIS CHECK")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(.tertiaryLabel))
                            ForEach(store.spendingBuckets) { b in
                                Button { selectedBucket = b } label: {
                                    HStack(spacing: 4) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(b.color).frame(width: 7, height: 7)
                                        Text(b.name)
                                            .font(.system(size: 13)).foregroundStyle(.secondary)
                                        Text(fmt(store.lastAlloc(for: b.id)))
                                            .font(.system(size: 13)).foregroundStyle(Color(.tertiaryLabel))
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
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
    @ViewBuilder let content: Content

    var body: some View {
        // SwiftUI 16+ doesn't have a native flow layout, so use a simple HStack with wrap
        // For a small number of items this HStack is fine; add ViewThatFits if needed
        HStack(spacing: spacing) { content }
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
        return contribs.suffix(10).enumerated().map { (.init($0.offset), $0.element) }
    }

    var body: some View {
        NavigationStack {
            List {
                // ── Balance header ──
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(bucket.color).frame(width: 40, height: 40)
                            Text(bucket.isSpending ? "Spending allocation"
                                 : goalMet ? "Goal reached!" : "Savings bucket")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bucket.isSpending ? "Last paycheck" : "Balance")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(fmt(bucket.isSpending ? lastA : balance))
                                .font(.system(size: 38, weight: .bold))
                        }
                        if !bucket.isSpending, let goal = bucket.goal {
                            VStack(spacing: 4) {
                                HStack {
                                    Text("\(fmt(balance)) of \(fmt(goal))")
                                    Spacer()
                                    Text("\(min(Int((balance / goal) * 100), 100))%")
                                }
                                .font(.caption).foregroundStyle(.secondary)
                                ProgressView(value: min(balance / goal, 1.0))
                                    .tint(goalMet ? Color(hex: "#F59E0B") : bucket.color)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // ── Spend / info ──
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

                // ── Bar chart ──
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

                // ── Transaction history ──
                Section("Transactions") {
                    if history.isEmpty {
                        Text("No transactions yet").foregroundStyle(.secondary)
                    } else {
                        ForEach(history) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.label)
                                    Text(fmtDate(item.date))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text((item.amount >= 0 ? "+" : "") + fmt(item.amount))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(item.amount >= 0 ? .primary : .red)
                            }
                        }
                    }
                }
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

    @State private var date     = Date()
    @State private var totalStr = ""
    @State private var note     = ""
    @State private var allocs   = [String: String]()
    @State private var saved    = false

    var total: Double { Double(totalStr) ?? 0 }
    var allocated: Double {
        store.activeBuckets.reduce(0) { $0 + (Double(allocs[$1.id] ?? "") ?? 0) }
    }
    var remaining: Double { total - allocated }
    var isGood:  Bool { abs(remaining) < 0.005 }
    var isClose: Bool { abs(remaining) < 1 && !isGood }

    var body: some View {
        NavigationStack {
            if saved {
                VStack(spacing: 16) {
                    Text("🎉").font(.system(size: 64))
                    Text("Paycheck saved!").font(.title.bold())
                    Text("Nice work staying on top of it.").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section("Info") {
                        HStack {
                            Text("Total")
                            Spacer()
                            Text("$").foregroundStyle(.secondary)
                            TextField("0.00", text: $totalStr)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
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
                        Section {
                            HStack {
                                let color: Color = isGood ? .green : isClose ? Color(hex:"#FF9500") : .red
                                Text(isGood ? "Fully allocated" : "Remaining: \(fmt(remaining))")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(color)
                                Spacer()
                                Text("\(fmt(allocated)) / \(fmt(total))")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section("Allocate") {
                        ForEach(store.activeBuckets) { bucket in
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(bucket.color).frame(width: 26, height: 26)
                                Text(bucket.name)
                                Spacer()
                                Text("$").foregroundStyle(.secondary)
                                TextField("0", text: Binding(
                                    get: { allocs[bucket.id] ?? "" },
                                    set: { allocs[bucket.id] = $0 }
                                ))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            }
                        }
                    }

                    Section {
                        Button { handleSave() } label: {
                            Text("Save Paycheck")
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
                .navigationTitle("Add Paycheck")
            }
        }
    }

    private func handleSave() {
        guard total > 0 else { return }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        store.addPaycheck(Paycheck(
            id: UUID().uuidString,
            date: df.string(from: date),
            amount: total,
            note: note,
            allocations: store.activeBuckets.compactMap { b in
                guard let v = Double(allocs[b.id] ?? ""), v > 0 else { return nil }
                return Allocation(bucketId: b.id, amount: v)
            }
        ))
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            saved = false; totalStr = ""; allocs = [:]; note = ""; date = Date()
        }
    }
}

// MARK: - History

struct HistoryView: View {
    @Environment(AppStore.self) var store
    @State private var expandedId: String?

    var sorted: [Paycheck]  { store.state.paychecks.sorted { $0.date > $1.date } }
    var chart12: [Paycheck] { Array(store.state.paychecks.sorted { $0.date < $1.date }.suffix(12)) }

    var body: some View {
        NavigationStack {
            List {
                // ── Trend line ──
                if chart12.count >= 2 {
                    Section("Paycheck Trend") {
                        Chart(chart12) { p in
                            LineMark(
                                x: .value("Date", p.date),
                                y: .value("Amount", p.amount)
                            )
                            .foregroundStyle(Color(hex: "#7C3AED"))
                            .interpolationMethod(.catmullRom)
                            AreaMark(
                                x: .value("Date", p.date),
                                y: .value("Amount", p.amount)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex:"#7C3AED").opacity(0.18), .clear],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                            PointMark(
                                x: .value("Date", p.date),
                                y: .value("Amount", p.amount)
                            )
                            .foregroundStyle(Color(hex: "#7C3AED"))
                            .symbolSize(25)
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .frame(height: 80)
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
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("History")
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
    @State private var showAddBucket    = false
    @State private var showArchived     = false
    @State private var showResetConfirm = false

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
                    Button("Reset All Data", role: .destructive) { showResetConfirm = true }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .toolbar { EditButton() }
            .sheet(item: $editingBucket) { BucketEditView(bucket: $0) }
            .sheet(isPresented: $showAddBucket) { BucketAddView() }
            .confirmationDialog("Reset All Data?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { store.resetData() }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This cannot be undone.") }
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
    @State private var isSpending: Bool
    @State private var showArchive = false

    init(bucket: Bucket) {
        self.bucket   = bucket
        _name         = State(initialValue: bucket.name)
        _selectedColor = State(initialValue: Color(hex: bucket.colorHex))
        _goalStr      = State(initialValue: bucket.goal.map { String($0) } ?? "")
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
                                           goal: Double(goalStr), isSpending: isSpending)
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
                            goal: Double(goalStr), isSpending: isSpending,
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
