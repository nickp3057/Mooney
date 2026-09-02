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

    private var rangeDelta: Double {
        guard let first = savingsChart.first, let last = savingsChart.last else { return 0 }
        return last.balance - first.balance
    }

    var body: some View {
        List {
            if savingsChart.count >= 2 {
                Section {
                    VStack(spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Savings Balance").sectionLabelStyle()
                                Text(fmt(savingsChart.last?.balance ?? 0))
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                            }
                            Spacer()
                            if rangeDelta != 0 {
                                Text("\(rangeDelta > 0 ? "+" : "")\(fmt(rangeDelta))")
                                    .font(.caption.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(rangeDelta > 0 ? Color.green : Color.primary)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill((rangeDelta > 0 ? Color.green : Color.primary).opacity(0.12)))
                            }
                        }

                        Chart(savingsChart) { point in
                            AreaMark(
                                x: .value("Date", point.date),
                                y: .value("Balance", point.balance)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [accentColor.opacity(0.3), .clear],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Balance", point.balance)
                            )
                            .foregroundStyle(accentColor)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                            .interpolationMethod(.catmullRom)
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 4)) {
                                AxisGridLine().foregroundStyle(Color.primary.opacity(0.06))
                                AxisValueLabel().foregroundStyle(Color.secondary)
                            }
                        }
                        .chartYAxis(.hidden)
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 130)
                        .contentTransition(.opacity)

                        Picker("Range", selection: $savingsRange.animation(.snappy)) {
                            ForEach(SavingsRange.allCases) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .heroCard(tint: accentColor)
                }
                .cardRow()
            }

            Section("\(sorted.count) Income Entries") {
                if sorted.isEmpty {
                    HStack(spacing: 12) {
                        SoftIconTile(systemName: "tray", color: .secondary, size: 30)
                        Text("No income logged yet").foregroundStyle(.secondary)
                    }
                }
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
                            HStack(spacing: 10) {
                                if let b {
                                    BucketBadge(bucket: b, size: 20)
                                } else {
                                    RoundedRectangle(cornerRadius: 6).fill(Color.gray).frame(width: 20, height: 20)
                                }
                                Text(b?.name ?? a.bucketId)
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Spacer()
                                Text(fmt(a.amount)).font(.subheadline).monospacedDigit()
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            IconTile(systemName: "arrow.down.left", color: Color(hex: "#34C759"), size: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(fmtDate(p.date))
                                if !p.note.isEmpty {
                                    Text(p.note).font(.caption)
                                        .foregroundStyle(accentColor)
                                } else if let source = store.incomeSourceName(p.sourceId) {
                                    Text(source).font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(fmt(p.amount))
                                .font(.body.weight(.semibold))
                                .monospacedDigit()
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
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(14)
        .screenBackground()
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
