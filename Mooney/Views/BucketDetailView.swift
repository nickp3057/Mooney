import SwiftUI
import Charts

struct BucketDetailView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss
    @State private var bucketId: String

    init(bucket: Bucket) {
        _bucketId = State(initialValue: bucket.id)
    }

    private var liveBucket: Bucket? {
        store.state.buckets.first { $0.id == bucketId }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let bucket = liveBucket {
                    BucketDetailContent(bucket: bucket) { other in bucketId = other.id }
                } else {
                    ContentUnavailableView("Bucket Removed", systemImage: "tray")
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct BucketDetailContent: View {
    @Environment(AppStore.self) var store
    let bucket: Bucket
    var switchTo: (Bucket) -> Void

    @State private var showSpendForm = false
    @State private var spendIsDeposit = false
    @State private var spendAmt  = ""
    @State private var spendNote = ""

    var balance: Double { store.balance(for: bucket.id) }
    var lastA: Double   { store.lastAlloc(for: bucket.id) }
    var goalMet: Bool   { bucket.goal.map { balance >= $0 } ?? false }

    var daysLeft: Int? {
        guard let goalDate = bucket.goalDate,
              let target = isoDateFormatter.date(from: goalDate) else { return nil }
        return max(Calendar.current.dateComponents([.day], from: Date(), to: target).day ?? 0, 0)
    }

    var otherBuckets: [Bucket] {
        store.activeBuckets.filter { $0.id != bucket.id }
    }

    struct HistoryItem: Identifiable {
        var id: String; var date: String; var amount: Double; var label: String; var isTransaction: Bool
    }

    var history: [HistoryItem] {
        var items: [HistoryItem] = []
        for p in store.state.incomes {
            if let a = p.allocations.first(where: { $0.bucketId == bucket.id }) {
                items.append(.init(id: p.id, date: p.date, amount: a.amount,
                                   label: p.note.isEmpty ? "Income" : p.note, isTransaction: false))
            }
        }
        for t in store.state.transactions.filter({ $0.bucketId == bucket.id }) {
            items.append(.init(id: t.id, date: t.date, amount: t.amount, label: t.note, isTransaction: true))
        }
        return items.sorted { $0.date > $1.date }
    }

    var barData: [(index: Int, value: Double)] {
        let contribs = store.state.incomes
            .sorted { $0.date < $1.date }
            .compactMap { p -> Double? in
                p.allocations.first(where: { $0.bucketId == bucket.id })?.amount
            }
        return contribs.suffix(10).enumerated().map { (index: $0.offset, value: $0.element) }
    }

    var body: some View {
        List {
            headerSection
            spendSection
            chartSection
            historySection
            otherBucketsSection
        }
        .listStyle(.plain)
        .navigationTitle(bucket.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(bucket.color)
                        .frame(width: 10, height: 10)
                    Text(bucket.name)
                        .font(.system(size: 26, weight: .bold))
                }
                Text(fmt(bucket.isSpending ? lastA : balance))
                    .font(.system(size: 38, weight: .bold))
                    .monospacedDigit()

                if !bucket.isSpending, let goal = bucket.goal {
                    let pct = min(Int((balance / goal) * 100), 100)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Text("of \(fmt(goal))")
                            if let daysLeft { Text("· \(daysLeft) days left") }
                        }
                        .font(.caption).foregroundStyle(.secondary)

                        ProgressView(value: min(balance / goal, 1.0))
                            .tint(goalMet ? Color(hex: "#F59E0B") : bucket.color)

                        HStack {
                            Text(goalMet ? "Goal reached" : "\(pct)% saved")
                            Spacer()
                            if !goalMet {
                                Text("\(fmt(max(goal - balance, 0))) to go")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(goalMet ? Color(hex: "#F59E0B") : .secondary)
                    }
                } else if bucket.isSpending {
                    Text("This check").font(.caption).foregroundStyle(.secondary)
                } else if let daysLeft {
                    Text("\(daysLeft) days left").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            .bubbleCard()
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private var spendSection: some View {
        if bucket.isSpending {
            Section {
                Text("This is your spending account. Allocations are logged each income — no need to track individual purchases here.")
                    .font(.callout).foregroundStyle(.secondary)
                    .bubbleCard()
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } else {
            Section {
                Group {
                    if !showSpendForm {
                        HStack(spacing: 10) {
                            Button("Record Spending") { spendIsDeposit = false; showSpendForm = true }
                                .foregroundStyle(bucket.color)
                            Button("Record Deposit") { spendIsDeposit = true; showSpendForm = true }
                                .foregroundStyle(bucket.color)
                        }
                    } else {
                        VStack(spacing: 10) {
                            Picker("Type", selection: $spendIsDeposit) {
                                Text("Spending").tag(false)
                                Text("Deposit").tag(true)
                            }
                            .pickerStyle(.segmented)
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
                .bubbleCard()
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
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
                .bubbleCard()
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
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
                            .monospacedDigit()
                            .foregroundStyle(item.amount >= 0 ? .green : Color.primary)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: item.isTransaction) {
                        if item.isTransaction {
                            Button("Delete", role: .destructive) {
                                store.deleteTransaction(id: item.id)
                            }
                        }
                    }
                    .bubbleCardRow()
                }
            }
        }
    }

    @ViewBuilder
    private var otherBucketsSection: some View {
        if !otherBuckets.isEmpty {
            Section("Other Buckets") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(otherBuckets) { other in
                        Button { switchTo(other) } label: {
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(other.color)
                                    .frame(width: 10, height: 10)
                                Text(other.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .overlay(Capsule().stroke(Color.secondary.opacity(0.25), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func saveSpend() {
        guard let amt = Double(spendAmt), amt > 0 else { return }
        store.addTransaction(AppTransaction(
            id: UUID().uuidString, bucketId: bucket.id,
            amount: spendIsDeposit ? amt : -amt, date: todayISO(),
            note: spendNote.isEmpty ? (spendIsDeposit ? "Deposit" : "Spending") : spendNote,
            type: spendIsDeposit ? "adjustment" : "spend"
        ))
        showSpendForm = false; spendAmt = ""; spendNote = ""
    }
}
