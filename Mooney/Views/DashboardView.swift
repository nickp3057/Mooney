import SwiftUI
import Charts
import WidgetKit

struct DashboardView: View {
    @Environment(AppStore.self) var store
    @Environment(\.openURL) private var openURL
    @State private var selectedBucket: Bucket?
    @State private var showBalanceOverride = false
    @State private var showAdjustBuckets = false
    @State private var loggingPaymentId: String?
    @State private var plaidBalance: PlaidBalance?
    @State private var plaidError: String?
    @State private var plaidLoading = false
    // @AppStorage instead of reading PlaidClient.backendURL directly — the
    // latter is a plain UserDefaults read SwiftUI can't observe, so this
    // view would never notice the Bank Connection screen setting it until
    // something else happened to force a re-render.
    @AppStorage(PlaidClient.backendURLDefaultsKey) private var plaidBackendURL: String = ""
    @AppStorage(PlaidClient.bankDisplayNameDefaultsKey) private var bankDisplayName: String = "MACU"
    @AppStorage(PlaidClient.autoSyncBalanceDefaultsKey) private var autoSyncBalance: Bool = false

    private let plaidClient = PlaidClient()

    private var plaidConfigured: Bool {
        !plaidBackendURL.isEmpty
    }

    private var showLiveBankSection: Bool {
        !store.isDecoyMode && plaidConfigured
    }

    // In auto-sync mode, the hero number IS the live bank balance — no
    // separate ledger-total vs. bank-total split — so the headline can never
    // itself be "wrong," only the buckets under it can be under- or
    // over-allocated relative to what's actually in the bank.
    private var heroBalance: Double {
        if autoSyncBalance, showLiveBankSection, let current = plaidBalance?.current {
            return current
        }
        return store.totalSavings
    }

    private var plaidDiscrepancy: (message: String, isOver: Bool)? {
        guard let current = plaidBalance?.current else { return nil }
        let diff = current - store.totalSavings
        guard abs(diff) >= 0.01 else { return nil }
        if diff > 0 {
            return autoSyncBalance
                ? ("Unallocated: \(fmt(diff))", true)
                : ("Unallocated balance: \(fmt(diff))", true)
        } else {
            return autoSyncBalance
                ? ("Over-allocated by \(fmt(abs(diff)))", false)
                : ("Yo you broke by \(fmt(abs(diff)))", false)
        }
    }

    // Easter egg: "69" showing up anywhere in the balance is a classic meme trigger.
    private var balanceHasNiceEasterEgg: Bool {
        guard let current = plaidBalance?.current else { return false }
        return fmt(current).filter(\.isNumber).contains("69")
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
        let accentColor = store.accentColor(for: .ledger)
        NavigationStack {
            List {
                // ── Hero balance + 30-day sparkline, with the live bank
                // balance folded in as a subordinate line rather than a
                // second competing headline number ──
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        if showLiveBankSection {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("\(bankDisplayName) Checking")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if let plaidBalance {
                                    Text(fmt(plaidBalance.current ?? 0))
                                        .font(.caption2.weight(.semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                    if balanceHasNiceEasterEgg {
                                        Text("😏")
                                            .font(.caption2)
                                    }
                                } else if let plaidError {
                                    Text(plaidError)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                } else {
                                    Text("Loading…")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if plaidLoading {
                                    ProgressView().controlSize(.mini)
                                } else {
                                    Button {
                                        Task { await refreshPlaidBalance() }
                                    } label: {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 9, weight: .semibold))
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.bottom, 2)
                        }
                        HStack(alignment: .firstTextBaseline) {
                            Text(autoSyncBalance && showLiveBankSection ? "\(bankDisplayName.uppercased()) BALANCE" : "SAVINGS BALANCE")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                showBalanceOverride = true
                            } label: {
                                Text("Correct Balance")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(accentColor)
                        }
                        Text(fmt(heroBalance))
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
                                        .foregroundStyle(accentColor)
                                        .symbolSize(30)
                                }
                            }
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: 2)) {
                                    AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: false)
                                }
                            }
                            .chartYAxis(.hidden)
                            .frame(height: 40)
                            .padding(.top, 4)
                        }

                        if showLiveBankSection {
                            // Reconciles the live bank balance against what
                            // the buckets/bills ledger thinks exists — these
                            // can legitimately diverge (unspent cash sitting
                            // in checking that isn't assigned to a bucket
                            // yet), but a negative gap means the ledger
                            // thinks there's money that isn't really there.
                            if let plaidDiscrepancy {
                                Text(plaidDiscrepancy.message)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(plaidDiscrepancy.isOver ? Color.secondary : Color.red)
                                    .padding(.top, 1)
                            }

                            if plaidBalance?.current != nil {
                                Button("Adjust Buckets") { showAdjustBuckets = true }
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(accentColor)
                                    .buttonStyle(.plain)
                                    .padding(.top, 4)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .task {
                        if showLiveBankSection {
                            await refreshPlaidBalance()
                        }
                    }
                    .bubbleCard()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                // ── Bucket quick access ── Spending buckets (e.g. a
                // "Checking" pass-through) are deliberately excluded — they're
                // not meant to carry a tracked total, so they don't belong in
                // a strip that implies one.
                if !store.savingsBuckets.isEmpty {
                    Section {
                        LazyVGrid(
                            columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                            alignment: .leading,
                            spacing: 6
                        ) {
                            ForEach(store.savingsBuckets) { bucket in
                                BucketChip(bucket: bucket) { selectedBucket = bucket }
                            }
                        }
                        .padding(.top, 2)
                        .padding(.bottom, 4)
                        .bubbleCard()
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                if !store.currentCardPayments.isEmpty {
                    Section("Credit Cards") {
                        LazyVGrid(
                            columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                            alignment: .leading,
                            spacing: 6
                        ) {
                            ForEach(store.currentCardPayments, id: \.payment.id) { pending in
                                cardChip(pending)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
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
                                .foregroundStyle(bill.canPay ? accentColor : .secondary)
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
                            .bubbleCardRow()
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
                            .bubbleCardRow()
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
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedBucket) { BucketDetailView(bucket: $0) }
            .sheet(isPresented: $showBalanceOverride) {
                BalanceOverrideView(
                    liveBankBalance: showLiveBankSection ? plaidBalance?.current : nil,
                    bankName: bankDisplayName
                )
            }
            .sheet(isPresented: $showAdjustBuckets) {
                AdjustBucketsView(target: plaidBalance?.current ?? store.totalSavings)
            }
            .sheet(isPresented: Binding(
                get: { loggingPaymentId != nil },
                set: { if !$0 { loggingPaymentId = nil } }
            )) {
                if let loggingPaymentId {
                    LogCardPaymentView(paymentId: loggingPaymentId)
                }
            }
        }
        .environment(\.tabAccentColor, accentColor)
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
        await refreshWidgetBalance()
    }

    // Separate from the Dashboard's own balance fetch above — the widget can
    // track a different account (PlaidClient.widgetAccountId), so this may
    // be a second network call. Failures here are silent: the widget just
    // keeps showing its last-known snapshot rather than surfacing an error
    // on the Dashboard for a background sync the user didn't ask to watch.
    private func refreshWidgetBalance() async {
        guard let widgetAccountId = PlaidClient.widgetAccountId else { return }
        guard let balance = try? await plaidClient.fetchBalance(accountId: widgetAccountId),
              let current = balance.current else { return }
        WidgetBalanceStore.write(WidgetBalanceSnapshot(accountName: balance.accountName, balance: current, asOf: balance.asOf))
        WidgetCenter.shared.reloadTimelines(ofKind: "MooneyWidget")
    }

    @ViewBuilder
    private func cardChip(_ pending: (card: CreditCard, payment: CardPayment)) -> some View {
        let isPaid = pending.payment.isPaid
        let accentColor = store.accentColor(for: .ledger)
        HStack(alignment: .top, spacing: 6) {
            Group {
                if isPaid {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                            Text(pending.card.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        Text("Paid")
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                    }
                } else {
                    Button {
                        loggingPaymentId = pending.payment.id
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 5) {
                                Image(systemName: "creditcard.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(accentColor)
                                Text(pending.card.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            Text("Due \(fmtDueDate(pending.payment.dueDate))")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
            if let app = pending.card.bankApp {
                Button { openBankApp(app) } label: {
                    Image(systemName: "arrow.up.forward.app.fill")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(accentColor)
            }
        }
        .bubbleCard()
    }

    private func openBankApp(_ app: BankApp) {
        if let appURL = app.appURL {
            openURL(appURL) { accepted in
                if !accepted, let web = app.webFallbackURL {
                    openURL(web)
                }
            }
        } else if let web = app.webFallbackURL {
            openURL(web)
        }
    }
}
