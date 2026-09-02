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
                        .screenBackground()
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
    @State private var spendAmt  = ""
    @State private var spendNote = ""

    enum TransferDirection { case from, to }

    @State private var showTransferForm = false
    @State private var transferDirection: TransferDirection = .to
    @State private var transferOtherId: String?
    @State private var transferAmt = ""
    @State private var transferNote = ""

    var balance: Double { store.balance(for: bucket.id) }
    var lastA: Double   { store.lastAlloc(for: bucket.id) }
    var goalMet: Bool   { bucket.goal.map { balance >= $0 } ?? false }
    var goalProgress: Double? {
        guard !bucket.isSpending, let goal = bucket.goal, goal > 0 else { return nil }
        return balance / goal
    }

    var daysLeft: Int? {
        guard let goalDate = bucket.goalDate,
              let target = isoDateFormatter.date(from: goalDate) else { return nil }
        return max(Calendar.current.dateComponents([.day], from: Date(), to: target).day ?? 0, 0)
    }

    var otherBuckets: [Bucket] {
        store.activeBuckets.filter { $0.id != bucket.id }
    }

    // Transfers only make sense between two savings buckets — a spending
    // bucket is excluded from totalSavings, so moving money into one would
    // shrink the total instead of just reshuffling it.
    var transferTargets: [Bucket] {
        store.savingsBuckets.filter { $0.id != bucket.id }
    }

    struct HistoryItem: Identifiable {
        var id: String
        var date: String
        var amount: Double
        var label: String
        var isTransaction: Bool
        var kind: LedgerEntry.Kind
    }

    var history: [HistoryItem] {
        var items: [HistoryItem] = []
        for p in store.state.incomes {
            if let a = p.allocations.first(where: { $0.bucketId == bucket.id }) {
                items.append(.init(id: p.id, date: p.date, amount: a.amount,
                                   label: p.note.isEmpty ? "Income" : p.note, isTransaction: false, kind: .income))
            }
        }
        for t in store.state.transactions.filter({ $0.bucketId == bucket.id }) {
            items.append(.init(id: t.id, date: t.date, amount: t.amount,
                               label: t.note.isEmpty ? t.type.capitalized : t.note, isTransaction: true,
                               kind: LedgerEntry.kind(forTransactionType: t.type, isLinkedTransfer: t.linkedId != nil)))
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
            Section { headerCard }.cardRow()
            Section { actionsCard }.cardRow()
            chartSection
            historySection
            otherBucketsSection
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(14)
        .screenBackground()
        .navigationTitle(bucket.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        BucketBadge(bucket: bucket, size: 28)
                        Text(bucket.isSpending ? "Spending" : (bucket.isGeneral ? "Main Savings" : "Savings Bucket"))
                            .sectionLabelStyle()
                    }
                    Text(fmt(bucket.isSpending ? lastA : balance))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: balance)
                    if bucket.isSpending {
                        Text("Allocated this check")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let goal = bucket.goal {
                        HStack(spacing: 4) {
                            Text("of \(fmt(goal))")
                            if let daysLeft { Text("· \(daysLeft) days left") }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    } else if let daysLeft {
                        Text("\(daysLeft) days left")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let goalProgress {
                    ZStack {
                        GoalRing(progress: goalProgress, color: goalMet ? .green : bucket.color, size: 68, lineWidth: 7)
                        if goalMet {
                            Image(systemName: "checkmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.green)
                        } else {
                            Text("\(Int((min(goalProgress, 1) * 100).rounded()))%")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        }
                    }
                }
            }
            if let goal = bucket.goal, !bucket.isSpending {
                HStack {
                    Text(goalMet ? "Goal reached 🎉" : "\(fmt(max(goal - balance, 0))) to go")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(goalMet ? Color.green : bucket.color)
                    Spacer()
                    if !goalMet, let suggested = store.suggestedGoalContribution(for: bucket), suggested > 0 {
                        Text("\(fmt(suggested)) per check")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .heroCard(tint: bucket.color)
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionsCard: some View {
        if bucket.isSpending {
            HStack(spacing: 12) {
                SoftIconTile(systemName: "info", color: bucket.color, size: 30)
                Text("This is your spending account. Allocations are logged each income — no need to track individual purchases here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .surfaceCard()
        } else {
            Group {
                if showSpendForm {
                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            Text("Spend").sectionLabelStyle()
                            Spacer()
                        }
                        entryFields(amount: $spendAmt, note: $spendNote, notePlaceholder: "What was it for?")
                        HStack(spacing: 10) {
                            Button("Cancel") {
                                showSpendForm = false; spendAmt = ""; spendNote = ""
                            }
                            .buttonStyle(.pill(.secondary))
                            Button {
                                saveSpend()
                            } label: {
                                Text("Log Spending").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.pill(bucket.color, prominent: true))
                            .disabled((Double(spendAmt) ?? 0) <= 0)
                        }
                    }
                } else if showTransferForm {
                    VStack(spacing: 12) {
                        Picker("Direction", selection: $transferDirection) {
                            Text("Move out").tag(TransferDirection.to)
                            Text("Move in").tag(TransferDirection.from)
                        }
                        .pickerStyle(.segmented)
                        HStack {
                            Text(transferDirection == .to ? "To" : "From")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Picker("", selection: $transferOtherId) {
                                ForEach(transferTargets) { other in
                                    Text(other.name).tag(Optional(other.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(bucket.color)
                        }
                        entryFields(amount: $transferAmt, note: $transferNote, notePlaceholder: "Note (optional)")
                        HStack(spacing: 10) {
                            Button("Cancel") { resetTransferForm() }
                                .buttonStyle(.pill(.secondary))
                            Button {
                                saveTransfer()
                            } label: {
                                Text("Transfer").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.pill(bucket.color, prominent: true))
                            .disabled(transferOtherId == nil || (Double(transferAmt) ?? 0) <= 0)
                        }
                    }
                } else {
                    HStack(spacing: 10) {
                        Button {
                            withAnimation(.snappy) { showSpendForm = true }
                        } label: {
                            Label("Spend", systemImage: "minus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.pill(bucket.color))

                        if !transferTargets.isEmpty {
                            Button {
                                transferDirection = .to
                                transferOtherId = transferTargets.first?.id
                                withAnimation(.snappy) { showTransferForm = true }
                            } label: {
                                Label("Transfer", systemImage: "arrow.left.arrow.right")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.pill(bucket.color))
                        }
                    }
                }
            }
            .surfaceCard()
        }
    }

    @ViewBuilder
    private func entryFields(amount: Binding<String>, note: Binding<String>, notePlaceholder: String) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Text("$")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                TextField("0.00", text: amount)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.05)))
            TextField(notePlaceholder, text: note)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.05)))
        }
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartSection: some View {
        if barData.count > 1 {
            Section("Contribution History") {
                VStack(alignment: .leading, spacing: 8) {
                    Chart(barData, id: \.index) { item in
                        BarMark(x: .value("Pay", item.index),
                                y: .value("Amount", item.value))
                        .foregroundStyle(bucket.color.gradient)
                        .cornerRadius(4)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 72)
                    Text("Last \(barData.count) paychecks · avg \(fmt(store.averageAlloc(for: bucket.id)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .surfaceCard()
            }
            .cardRow()
        }
    }

    // MARK: - History

    @ViewBuilder
    private var historySection: some View {
        Section("Transactions") {
            if history.isEmpty {
                HStack(spacing: 12) {
                    SoftIconTile(systemName: "tray", color: .secondary, size: 30)
                    Text("No transactions yet").foregroundStyle(.secondary)
                }
            } else {
                ForEach(history) { (item: HistoryItem) in
                    HStack(spacing: 12) {
                        IconTile(systemName: item.kind.systemImage,
                                 color: item.kind == .income ? Color(hex: "#34C759") : bucket.color,
                                 size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.label).lineLimit(1)
                            Text(fmtDate(item.date))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        AmountText(amount: item.amount)
                    }
                    .padding(.vertical, 1)
                    .swipeActions(edge: .trailing, allowsFullSwipe: item.isTransaction) {
                        if item.isTransaction {
                            Button("Delete", role: .destructive) {
                                store.deleteTransaction(id: item.id)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Other buckets

    @ViewBuilder
    private var otherBucketsSection: some View {
        if !otherBuckets.isEmpty {
            Section("Other Buckets") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(otherBuckets) { other in
                        Button { switchTo(other) } label: {
                            HStack(spacing: 6) {
                                BucketBadge(bucket: other, size: 18)
                                Text(other.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(other.color.opacity(0.14)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            .cardRow()
        }
    }

    // MARK: - Actions

    private func saveSpend() {
        guard let amt = Double(spendAmt), amt > 0 else { return }
        store.addTransaction(AppTransaction(
            id: UUID().uuidString, bucketId: bucket.id,
            amount: -amt, date: todayISO(),
            note: spendNote.isEmpty ? "Spending" : spendNote,
            type: "spend"
        ))
        withAnimation(.snappy) { showSpendForm = false }
        spendAmt = ""; spendNote = ""
    }

    private func saveTransfer() {
        guard let amt = Double(transferAmt), amt > 0, let otherId = transferOtherId else { return }
        let (fromId, toId) = transferDirection == .to ? (bucket.id, otherId) : (otherId, bucket.id)
        store.transferBetweenBuckets(fromId: fromId, toId: toId, amount: amt, note: transferNote)
        resetTransferForm()
    }

    private func resetTransferForm() {
        withAnimation(.snappy) { showTransferForm = false }
        transferAmt = ""; transferNote = ""; transferOtherId = nil
    }
}
