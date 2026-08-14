import SwiftUI
import Charts

struct DashboardView: View {
    @Environment(AppStore.self) var store
    @State private var selectedBucket: Bucket?
    @State private var showBalanceOverride = false
    @State private var plaidBalance: PlaidBalance?
    @State private var plaidError: String?
    @State private var plaidLoading = false

    private let plaidClient = PlaidClient()

    private var plaidConfigured: Bool {
        !(PlaidClient.backendURL ?? "").isEmpty
    }

    private struct LedgerGroup: Identifiable {
        var id: String { label }
        var label: String
        var entries: [LedgerEntry]
    }

    private var heroPoints: [SavingsPoint] {
        let all = store.savingsBalancePoints()
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else { return all }
        let trimmed = all.filter { $0.date >= cutoff }
        return trimmed.count >= 2 ? trimmed : Array(all.suffix(2))
    }

    private var heroDelta: Double {
        guard let first = heroPoints.first, let last = heroPoints.last else { return 0 }
        return last.balance - first.balance
    }

    private var groupedLedger: [LedgerGroup] {
        var groups: [LedgerGroup] = []
        for entry in store.ledgerEntries {
            let label = dayLabel(for: entry.date)
            if !groups.isEmpty, groups[groups.count - 1].label == label {
                groups[groups.count - 1].entries.append(entry)
            } else {
                groups.append(LedgerGroup(label: label, entries: [entry]))
            }
        }
        return groups
    }

    private func dayLabel(for iso: String) -> String {
        guard let d = isoDateFormatter.date(from: iso) else { return iso.uppercased() }
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "TODAY" }
        if cal.isDateInYesterday(d) { return "YESTERDAY" }
        let df = DateFormatter()
        df.dateFormat = "EEEE, MMM d"
        return df.string(from: d).uppercased()
    }

    var body: some View {
        NavigationStack {
            List {
                // ── Hero balance + 30-day sparkline, with the live bank
                // balance folded in as a subordinate line rather than a
                // second competing headline number ──
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("SAVINGS BALANCE")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                showBalanceOverride = true
                            } label: {
                                Text("Correct Balance")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(store.accentColor)
                        }
                        Text(fmt(store.totalSavings))
                            .font(.system(size: 40, weight: .bold))
                            .monospacedDigit()
                        if heroDelta != 0 {
                            Text("\(heroDelta >= 0 ? "+" : "")\(fmt(heroDelta)) · 30d")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(heroDelta >= 0 ? .green : .primary)
                        }
                        if heroPoints.count > 1 {
                            Chart {
                                ForEach(heroPoints) { point in
                                    LineMark(x: .value("Date", point.date), y: .value("Balance", point.balance))
                                        .foregroundStyle(Color.primary)
                                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                                        .interpolationMethod(.catmullRom)
                                }
                                if let last = heroPoints.last {
                                    PointMark(x: .value("Date", last.date), y: .value("Balance", last.balance))
                                        .foregroundStyle(store.accentColor)
                                        .symbolSize(30)
                                }
                            }
                            .chartXAxis(.hidden)
                            .chartYAxis(.hidden)
                            .frame(height: 50)
                            .padding(.top, 4)
                        }

                        if !store.isDecoyMode && plaidConfigured {
                            Divider().padding(.top, 4)
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("MACU Checking")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let plaidBalance {
                                    Text(fmt(plaidBalance.current ?? 0))
                                        .font(.subheadline.weight(.semibold))
                                        .monospacedDigit()
                                } else if let plaidError {
                                    Text(plaidError)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Loading…")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if plaidLoading {
                                    ProgressView()
                                } else {
                                    Button {
                                        Task { await refreshPlaidBalance() }
                                    } label: {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(store.accentColor)
                                }
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 6)
                    .task {
                        if !store.isDecoyMode && plaidConfigured {
                            await refreshPlaidBalance()
                        }
                    }
                }
                .listRowSeparator(.hidden)

                // ── Bucket quick access ──
                if !store.activeBuckets.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(store.activeBuckets) { bucket in
                                    BucketChip(bucket: bucket) { selectedBucket = bucket }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 2)
                            .padding(.bottom, 10)
                        }
                        .listRowInsets(EdgeInsets())
                    }
                    .listRowSeparator(.hidden)
                }

                if !store.unpaidBillGroups.isEmpty {
                    Section("Bills To Pay") {
                        ForEach(store.unpaidBillGroups) { bill in
                            HStack(spacing: 10) {
                                Button {
                                    store.setUnpaidBillGroupPaid(billId: bill.billId)
                                } label: {
                                    Image(systemName: bill.canPay ? "circle" : "lock.circle")
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(bill.canPay ? store.accentColor : .secondary)
                                .disabled(!bill.canPay)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bill.name)
                                    Text(bill.canPay
                                         ? "\(fmt(bill.savedAmount)) ready to pay"
                                         : "\(fmt(bill.savedAmount)) of \(fmt(bill.requiredAmount)) saved")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(fmt(bill.requiredAmount))
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }

                // ── Chronological ledger ──
                ForEach(groupedLedger) { group in
                    Section(group.label) {
                        ForEach(group.entries) { entry in
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(entry.color)
                                    .frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title)
                                    Text(entry.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text((entry.amount >= 0 ? "+" : "") + fmt(entry.amount))
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                                    .foregroundStyle(entry.amount >= 0 ? .green : .red)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let id = entry.bucketId,
                                   let bucket = store.state.buckets.first(where: { $0.id == id }) {
                                    selectedBucket = bucket
                                }
                            }
                        }
                    }
                }

                if groupedLedger.isEmpty {
                    Section {
                        Text("No activity yet").foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Ledger")
            .sheet(item: $selectedBucket) { BucketDetailView(bucket: $0) }
            .sheet(isPresented: $showBalanceOverride) { BalanceOverrideView() }
        }
    }

    private func refreshPlaidBalance() async {
        plaidLoading = true
        defer { plaidLoading = false }
        do {
            plaidBalance = try await plaidClient.fetchBalance()
            plaidError = nil
        } catch {
            plaidError = error.localizedDescription
        }
    }
}
