import SwiftUI
import Charts
import WidgetKit

struct DashboardView: View {
    @Environment(AppStore.self) var store
    @Environment(\.openURL) private var openURL
    @State private var selectedBucket: Bucket?
    @State private var showBalanceOverride = false
    @State private var showSyncConfirm = false
    @State private var loggingPaymentId: String?
    @State private var plaidBalance: PlaidBalance?
    @State private var plaidError: String?
    @State private var plaidLoading = false
    // The widget's account (PlaidClient.widgetAccountId) — spending/checking
    // money, distinct from the Primary Savings account above that the
    // hero balance and bucket reconciliation are based on.
    @State private var checkingBalance: PlaidBalance?
    @State private var checkingError: String?
    @State private var checkingLoading = false
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

    private var showCheckingSection: Bool {
        showLiveBankSection && PlaidClient.widgetAccountId != nil
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

    // Bank balance minus what the ledger thinks exists. With auto-sync on
    // this is booked onto Main Savings the moment a balance arrives, so it
    // only shows here transiently (or if the general bucket is missing).
    private var bankDelta: Double? {
        guard showLiveBankSection, let current = plaidBalance?.current else { return nil }
        let diff = current - store.totalSavings
        return abs(diff) >= 0.01 ? diff : nil
    }

    private var plaidDiscrepancy: (message: String, isOver: Bool)? {
        guard let diff = bankDelta else { return nil }
        if diff > 0 {
            return ("\(fmt(diff)) not in ledger", true)
        } else {
            return ("Yo you broke by \(fmt(abs(diff)))", false)
        }
    }

    private var generalBucketIsNegative: Bool {
        guard let general = store.generalBucket else { return false }
        return store.balance(for: general.id) < -0.005
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

    private var thirtyDayCutoff: Date? {
        Calendar.current.date(byAdding: .day, value: -30, to: Date())
    }

    // The last 30 days of the savings curve, anchored by the most recent
    // point before the window so the line doesn't start mid-air.
    private var heroPoints: [SavingsPoint] {
        let all = store.savingsBalancePoints()
        guard let cutoff = thirtyDayCutoff else { return all }
        let inWindow = all.filter { $0.date >= cutoff }
        if let previous = all.last(where: { $0.date < cutoff }) {
            return [previous] + inWindow
        }
        return inWindow
    }

    // Change over the last 30 days — measured against the balance as it
    // stood at the start of the window, not the oldest point that happens
    // to be in the trimmed list (which could be years old).
    private var heroDelta: Double {
        let all = store.savingsBalancePoints()
        guard let cutoff = thirtyDayCutoff, let last = all.last, last.date >= cutoff else { return 0 }
        let baseline = all.last(where: { $0.date < cutoff })?.balance ?? 0
        return last.balance - baseline
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
        guard let d = isoDateFormatter.date(from: iso) else { return iso }
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Today" }
        if cal.isDateInYesterday(d) { return "Yesterday" }
        let df = DateFormatter()
        df.dateFormat = cal.component(.year, from: d) == cal.component(.year, from: Date()) ? "EEEE, MMM d" : "EEEE, MMM d, yyyy"
        return df.string(from: d)
    }

    private let gridColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        let accentColor = store.accentColor(for: .ledger)
        NavigationStack {
            List {
                Section {
                    heroCard(accentColor)
                        .task {
                            if showLiveBankSection {
                                await refreshPlaidBalance()
                            }
                            if showCheckingSection {
                                await refreshCheckingBalance()
                            }
                        }
                }
                .cardRow()

                bucketsSections

                if !store.currentCardPayments.isEmpty {
                    Section {
                        LazyVGrid(columns: gridColumns, spacing: 10) {
                            ForEach(store.currentCardPayments, id: \.payment.id) { pending in
                                cardChip(pending, accent: accentColor)
                            }
                        }
                    } header: {
                        Text("Credit Cards")
                    }
                    .cardRow()
                }

                if !store.unpaidBillGroups.isEmpty {
                    Section("Bills to Pay") {
                        ForEach(store.unpaidBillGroups) { bill in
                            billRow(bill, accent: accentColor)
                        }
                    }
                }

                ForEach(groupedLedger) { group in
                    Section(group.label) {
                        ForEach(group.entries) { entry in
                            ledgerRow(entry)
                        }
                    }
                }

                if groupedLedger.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("No activity yet", systemImage: "tray")
                        } description: {
                            Text("Log your first paycheck from the Add tab and it'll show up here.")
                        }
                        .padding(.vertical, 8)
                    }
                    .cardRow()
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(14)
            .screenBackground()
            .navigationTitle("Ledger")
            .sheet(item: $selectedBucket) { BucketDetailView(bucket: $0) }
            .sheet(isPresented: $showBalanceOverride) {
                BalanceOverrideView(
                    liveBankBalance: showLiveBankSection ? plaidBalance?.current : nil,
                    bankName: bankDisplayName
                )
            }
            .confirmationDialog(
                "Sync to \(bankDisplayName) balance?",
                isPresented: $showSyncConfirm,
                titleVisibility: .visible
            ) {
                Button("Sync \(bankDelta.map { ($0 >= 0 ? "+" : "") + fmt($0) } ?? "")") {
                    if let current = plaidBalance?.current {
                        store.syncTotalSavings(toBankBalance: current, bankName: bankDisplayName)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Books the difference on Main Savings only. Your other buckets aren't touched — if Main Savings goes negative, transfer from another bucket to cover it.")
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

    // MARK: - Hero

    @ViewBuilder
    private func heroCard(_ accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(autoSyncBalance && showLiveBankSection ? "\(bankDisplayName) Primary Savings" : "Savings Balance")
                    .sectionLabelStyle()
                Spacer()
                Button("Correct") { showBalanceOverride = true }
                    .buttonStyle(.pill(accent, compact: true))
            }

            Text(fmt(heroBalance))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
                .animation(.snappy, value: heroBalance)

            HStack(spacing: 8) {
                if heroDelta != 0 {
                    let up = heroDelta > 0
                    Label {
                        Text("\(up ? "+" : "")\(fmt(heroDelta)) · 30d")
                    } icon: {
                        Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                    }
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(up ? Color.green : Color.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill((up ? Color.green : Color.primary).opacity(0.12)))
                }
                if showLiveBankSection, let plaidDiscrepancy {
                    Text(plaidDiscrepancy.message)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(plaidDiscrepancy.isOver ? Color.secondary : Color.red)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill((plaidDiscrepancy.isOver ? Color.secondary : Color.red).opacity(0.12)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                if !autoSyncBalance, bankDelta != nil {
                    Button("Sync") { showSyncConfirm = true }
                        .buttonStyle(.pill(accent, compact: true))
                }
            }

            if generalBucketIsNegative {
                Label("Main Savings is negative — transfer from another bucket to cover it.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
            }

            if heroPoints.count > 1 {
                Chart {
                    ForEach(heroPoints) { point in
                        AreaMark(x: .value("Date", point.date), y: .value("Balance", point.balance))
                            .foregroundStyle(
                                LinearGradient(colors: [accent.opacity(0.35), accent.opacity(0)], startPoint: .top, endPoint: .bottom)
                            )
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("Date", point.date), y: .value("Balance", point.balance))
                            .foregroundStyle(accent)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                            .interpolationMethod(.catmullRom)
                    }
                    if let last = heroPoints.last {
                        PointMark(x: .value("Date", last.date), y: .value("Balance", last.balance))
                            .foregroundStyle(accent)
                            .symbolSize(40)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 56)
                .padding(.top, 2)
            }

            if showLiveBankSection {
                Divider().padding(.vertical, 2)
                VStack(spacing: 8) {
                    if showCheckingSection {
                        miniBalanceRow(
                            label: "\(bankDisplayName) Checking",
                            balance: checkingBalance,
                            error: checkingError,
                            loading: checkingLoading
                        ) {
                            Task { await refreshCheckingBalance() }
                        }
                    }
                    miniBalanceRow(
                        label: "\(bankDisplayName) Primary Savings",
                        balance: plaidBalance,
                        error: plaidError,
                        loading: plaidLoading,
                        showEasterEgg: balanceHasNiceEasterEgg
                    ) {
                        Task { await refreshPlaidBalance() }
                    }
                }
            }
        }
        .heroCard(tint: accent)
    }

    // MARK: - Buckets

    @ViewBuilder
    private var bucketsSections: some View {
        // Spending buckets (e.g. a "Checking" pass-through) are deliberately
        // excluded — they're not meant to carry a tracked total, so they
        // don't belong in a strip that implies one. The general "main
        // savings" bucket gets its own full-width row above the 2-across
        // grid of everything else.
        if !store.savingsBuckets.isEmpty {
            let generalBucket = store.savingsBuckets.first { $0.isGeneral }
            let otherBuckets = store.savingsBuckets.filter { !$0.isGeneral }

            Section {
                if let generalBucket {
                    BucketHeroRow(bucket: generalBucket) { selectedBucket = generalBucket }
                }
                if !otherBuckets.isEmpty {
                    LazyVGrid(columns: gridColumns, spacing: 10) {
                        ForEach(otherBuckets) { bucket in
                            BucketChip(bucket: bucket) { selectedBucket = bucket }
                        }
                    }
                    .padding(.top, generalBucket == nil ? 0 : 10)
                }
            } header: {
                Text("Buckets")
            }
            .cardRow()
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func billRow(_ bill: UnpaidBillGroup, accent: Color) -> some View {
        HStack(spacing: 12) {
            Button {
                store.setUnpaidBillGroupPaid(billId: bill.billId)
            } label: {
                Image(systemName: bill.canPay ? "circle" : "lock.circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(bill.canPay ? accent : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(!bill.canPay)

            VStack(alignment: .leading, spacing: 3) {
                Text(bill.name)
                Text(bill.canPay
                     ? "Ready to pay"
                     : "\(fmt(bill.savedAmount)) of \(fmt(bill.requiredAmount)) saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !bill.canPay {
                    GoalBar(progress: bill.requiredAmount > 0 ? bill.savedAmount / bill.requiredAmount : 0, color: accent, height: 3)
                        .padding(.top, 2)
                }
            }
            Spacer()
            Text(fmt(bill.requiredAmount))
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func ledgerRow(_ entry: LedgerEntry) -> some View {
        HStack(spacing: 12) {
            IconTile(systemName: entry.kind.systemImage, color: entry.color, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .lineLimit(1)
                Text(entry.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            AmountText(amount: entry.amount, signed: !entry.isTransfer, muted: entry.isTransfer)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            if let id = entry.bucketId,
               let bucket = store.state.buckets.first(where: { $0.id == id }) {
                selectedBucket = bucket
            }
        }
    }

    // MARK: - Plaid

    private func refreshPlaidBalance() async {
        plaidLoading = true
        defer { plaidLoading = false }
        do {
            let balance = try await plaidClient.fetchBalance()
            plaidBalance = balance
            plaidError = nil
            // Auto-sync: the ledger follows the bank, and the whole
            // difference lands on Main Savings — other buckets stay put.
            if autoSyncBalance, !store.isDecoyMode, let current = balance.current {
                store.syncTotalSavings(toBankBalance: current, bankName: bankDisplayName)
            }
        } catch {
            plaidError = error.localizedDescription
        }
    }

    // The widget's account (PlaidClient.widgetAccountId) can be different
    // from the Primary Savings account above, so this is its own fetch. It
    // both drives the tiny "Checking" line on the Dashboard and refreshes
    // the App-Group-backed snapshot the lock-screen widget reads.
    private func refreshCheckingBalance() async {
        guard let widgetAccountId = PlaidClient.widgetAccountId else { return }
        checkingLoading = true
        defer { checkingLoading = false }
        do {
            let balance = try await plaidClient.fetchBalance(accountId: widgetAccountId)
            checkingBalance = balance
            checkingError = nil
            // Prefer available over current for the widget specifically — the
            // widget is meant to answer "what can I actually spend right
            // now," and current doesn't reflect pending holds/purchases yet.
            if let spendable = balance.available ?? balance.current {
                WidgetBalanceStore.write(WidgetBalanceSnapshot(accountName: balance.accountName, balance: spendable, asOf: balance.asOf))
                WidgetCenter.shared.reloadTimelines(ofKind: "MooneyWidget")
            }
        } catch {
            checkingError = error.localizedDescription
        }
    }

    @ViewBuilder
    private func miniBalanceRow(
        label: String,
        balance: PlaidBalance?,
        error: String?,
        loading: Bool,
        showEasterEgg: Bool = false,
        onRefresh: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "building.columns.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if let balance {
                Text(fmt(balance.current ?? 0))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                if showEasterEgg {
                    Text("😏").font(.caption2)
                }
            } else if let error {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("Loading…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if loading {
                ProgressView().controlSize(.mini)
            } else {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.primary.opacity(0.07)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Cards

    @ViewBuilder
    private func cardChip(_ pending: (card: CreditCard, payment: CardPayment), accent: Color) -> some View {
        let isPaid = pending.payment.isPaid
        let tint: Color = isPaid ? .green : accent
        Button {
            if !isPaid { loggingPaymentId = pending.payment.id }
        } label: {
            HStack(spacing: 10) {
                IconTile(systemName: isPaid ? "checkmark" : "creditcard.fill", color: tint, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pending.card.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(isPaid ? "Paid" : "Due \(fmtDueDate(pending.payment.dueDate))")
                        .font(.caption)
                        .foregroundStyle(isPaid ? Color.green : Color.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if let app = pending.card.bankApp {
                    Button { openBankApp(app) } label: {
                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(accent)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(accent.opacity(0.14)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tintedChipBackground(tint)
        }
        .buttonStyle(.plain)
        .disabled(isPaid)
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
