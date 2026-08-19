import SwiftUI
import Charts

struct HistoryView: View {
    @Environment(AppStore.self) var store
    @Environment(\.tabAccentColor) private var accentColor
    @State private var expandedId: String?
    @State private var editingIncome: Income?
    @State private var incomePendingDelete: Income?
    @State private var savingsRange: SavingsRange = .year

    var sorted: [Income]  { store.state.incomes.sorted { $0.date > $1.date } }
    var savingsChart: [SavingsPoint] {
        let all = store.savingsBalancePoints()
        guard let cutoff = savingsRange.cutoffDate else { return all }
        let previous = all.last { $0.date < cutoff }
        let filtered = all.filter { $0.date >= cutoff }
        if let previous, !filtered.contains(where: { $0.id == previous.id }) {
            return [previous] + filtered
        }
        return filtered
    }

    var body: some View {
        List {
                // ── Savings tracker ──
                if savingsChart.count >= 2 {
                    Section {
                        VStack(spacing: 12) {
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
                            .foregroundStyle(accentColor)
                            .interpolationMethod(.catmullRom)
                            AreaMark(
                                x: .value("Date", point.date),
                                y: .value("Balance", point.balance)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [accentColor.opacity(0.18), .clear],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Balance", point.balance)
                            )
                            .foregroundStyle(accentColor)
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
                                .foregroundStyle(accentColor)
                        }
                        }
                        .bubbleCard()
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                // ── Income list ──
                Section("\(sorted.count) Income Entries") {
                    ForEach(sorted) { p in
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedId == p.id },
                                set: { expandedId = $0 ? p.id : nil }
                            )
                        ) {
                            if !p.bills.isEmpty {
                                SectionBillRows(incomeId: p.id, bills: p.bills)
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
                                            .foregroundStyle(accentColor)
                                    }
                                }
                                Spacer()
                                Text(fmt(p.amount)).foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) { incomePendingDelete = p }
                            Button("Edit") { editingIncome = p }
                                .tint(accentColor)
                        }
                        .contextMenu {
                            Button("Edit Income") { editingIncome = p }
                            Button("Delete Income", role: .destructive) { incomePendingDelete = p }
                        }
                        .bubbleCardRow()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("History")
            .sheet(item: $editingIncome) { income in
                AddIncomeView(incomeToEdit: income) {
                    editingIncome = nil
                }
            }
            .confirmationDialog(
                "Delete this income?",
                isPresented: Binding(
                    get: { incomePendingDelete != nil },
                    set: { if !$0 { incomePendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Income", role: .destructive) {
                    if let p = incomePendingDelete { store.deleteIncome(id: p.id) }
                    incomePendingDelete = nil
                }
                Button("Cancel", role: .cancel) { incomePendingDelete = nil }
            } message: {
                Text("This removes the income and its bucket allocations. This can't be undone.")
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
