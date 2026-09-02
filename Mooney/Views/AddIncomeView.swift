import SwiftUI
import UIKit

struct AddIncomeView: View {
    @Environment(AppStore.self) var store

    var incomeToEdit: Income?
    var onSaved: (() -> Void)?

    @State private var date     = Date()
    @State private var totalStr = ""
    @State private var note     = ""
    @State private var sourceId: String? = nil
    @State private var billAmounts = [String: String]()
    @State private var includedBills = Set<String>()
    @State private var allocs   = [String: String]()
    @State private var saved    = false
    @FocusState private var moneyFieldFocused: Bool

    var total: Double { Double(totalStr) ?? 0 }
    var billTotal: Double {
        store.activeBills.reduce(0) { sum, bill in
            guard includedBills.contains(bill.id) else { return sum }
            return sum + (Double(billAmounts[bill.id] ?? "") ?? 0)
        }
    }

    // Active buckets, plus — when editing — any bucket the income already
    // allocates to that has since been paused/archived. Without that, saving
    // an edit would silently drop those allocations (and the money would
    // quietly resettle into the general bucket).
    var allocationBuckets: [Bucket] {
        var list = store.activeBuckets
        guard let incomeToEdit else { return list }
        let known = Set(list.map(\.id))
        for allocation in incomeToEdit.allocations where !known.contains(allocation.bucketId) {
            if let bucket = store.state.buckets.first(where: { $0.id == allocation.bucketId }) {
                list.append(bucket)
            }
        }
        return list
    }

    var allocated: Double {
        allocationBuckets.reduce(0) { $0 + (Double(allocs[$1.id] ?? "") ?? 0) }
    }
    var envelopeMoney: Double { total - billTotal }
    var remaining: Double { envelopeMoney - allocated }
    var isGood:  Bool { abs(remaining) < 0.005 }
    var isEditing: Bool { incomeToEdit != nil }

    var body: some View {
        let accentColor = store.accentColor(for: .add)
        NavigationStack {
            Group {
                if saved {
                    savedState(accentColor)
                } else {
                    form(accentColor)
                }
            }
            .screenBackground()
            .navigationTitle(isEditing ? "Edit Income" : "Add Income")
        }
        .environment(\.tabAccentColor, accentColor)
    }

    // MARK: - Saved

    @ViewBuilder
    private func savedState(_ accent: Color) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.green.gradient)
                .symbolEffect(.bounce, value: saved)
            Text(isEditing ? "Income updated" : "Income saved")
                .font(.title.bold())
            Text(isEditing ? "Your changes are in." : "Nice work staying on top of it.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if !isEditing { ConfettiView() }
        }
    }

    // MARK: - Form

    @ViewBuilder
    private func form(_ accent: Color) -> some View {
        List {
            Section {
                totalCard(accent)
            }
            .cardRow()

            Section("Details") {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Picker("Source", selection: $sourceId) {
                    Text("None").tag(String?.none)
                    ForEach(store.state.incomeSources) { source in
                        Text(source.name).tag(String?.some(source.id))
                    }
                }
                .pickerStyle(.menu)
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
                    Section {
                        ForEach(store.activeBills) { bill in
                            billRow(bill)
                        }
                    } header: {
                        HStack {
                            Text("Bills")
                            Spacer()
                            HStack(spacing: 6) {
                                Button("Half") { fillBills(multiplier: 0.5) }
                                    .buttonStyle(.pill(accent, compact: true))
                                Button("Full") { fillBills(multiplier: 1.0) }
                                    .buttonStyle(.pill(accent, compact: true))
                            }
                            .textCase(nil)
                        }
                    }
                }

                Section {
                    summaryCard(accent)
                }
                .cardRow()
            }

            Section("Allocate") {
                ForEach(allocationBuckets) { bucket in
                    allocationRow(bucket, accent: accent)
                }
            }

            Section {
                Button { handleSave() } label: {
                    Text(isEditing ? "Update Income" : "Save Income")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(accent)
                .disabled(total <= 0)
            }
            .cardRow(verticalPadding: 4)
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(14)
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

    @ViewBuilder
    private func totalCard(_ accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total Received")
                .sectionLabelStyle()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("$")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                TextField("0.00", text: $totalStr)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .focused($moneyFieldFocused)
            }
            if total > 0, billTotal > 0 {
                Text("\(fmt(billTotal)) set aside for bills · \(fmt(envelopeMoney)) to allocate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .heroCard(tint: accent)
        .contentShape(Rectangle())
        .onTapGesture { moneyFieldFocused = true }
    }

    @ViewBuilder
    private func billRow(_ bill: Bill) -> some View {
        let included = includedBills.contains(bill.id)
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { included },
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
                .foregroundStyle(included ? Color.primary : Color.secondary)
            Spacer()
            MoneyEntryField(text: Binding(
                get: { billAmounts[bill.id] ?? String(format: "%.2f", bill.amount) },
                set: { billAmounts[bill.id] = $0 }
            ), placeholder: "0.00", width: 92, isFocused: $moneyFieldFocused)
            .disabled(!included)
            .foregroundStyle(included ? Color.primary : Color.secondary)
        }
    }

    @ViewBuilder
    private func summaryCard(_ accent: Color) -> some View {
        // Leftover money isn't an error — it just settles into Savings.
        // Over-allocating (spoken for more than you have) is the only case
        // worth flagging.
        let statusLabel = isGood ? "Fully allocated"
            : remaining > 0 ? "\(fmt(remaining)) → Savings"
            : "Over by \(fmt(-remaining))"
        let statusColor: Color = isGood ? .green : remaining > 0 ? accent : .red
        let progress = envelopeMoney > 0 ? allocated / envelopeMoney : 0

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("After bills")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(fmt(envelopeMoney))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(statusLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                    Text("\(fmt(allocated)) allocated")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            GoalBar(progress: progress, color: statusColor, height: 6)
        }
        .surfaceCard()
    }

    @ViewBuilder
    private func allocationRow(_ bucket: Bucket, accent: Color) -> some View {
        HStack(spacing: 12) {
            BucketBadge(bucket: bucket, size: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(bucket.name)
                    .lineLimit(1)
                if let hint = allocationHint(for: bucket) {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                let suggested = suggestedAllocation(for: bucket)
                let goalNeed = store.suggestedGoalContribution(for: bucket)
                if (suggested != nil) || (goalNeed ?? 0) > 0 {
                    HStack(spacing: 6) {
                        if let suggested, let label = allocationButtonLabel(for: bucket) {
                            Button(label) {
                                allocs[bucket.id] = String(format: "%.2f", suggested)
                            }
                            .buttonStyle(.pill(accent, compact: true))
                            .disabled(total <= 0)
                        }
                        if let goalNeed, goalNeed > 0 {
                            Button("Goal") {
                                allocs[bucket.id] = String(format: "%.2f", goalNeed.rounded(.up))
                            }
                            .buttonStyle(.pill(bucket.color, compact: true))
                            .disabled(total <= 0)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            Spacer()
            MoneyEntryField(text: Binding(
                get: { allocs[bucket.id] ?? "" },
                set: { allocs[bucket.id] = $0 }
            ), placeholder: "0", width: 90, isFocused: $moneyFieldFocused)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Actions

    private func handleSave() {
        guard total > 0 else { return }
        let bills = store.activeBills.compactMap { bill -> BillPayment? in
            guard includedBills.contains(bill.id),
                  let amount = Double(billAmounts[bill.id] ?? ""),
                  amount > 0 else { return nil }
            let existing = incomeToEdit?.bills.first { $0.billId == bill.id }
            return BillPayment(
                id: existing?.id ?? UUID().uuidString,
                billId: bill.id,
                name: bill.name,
                amount: amount,
                isPaid: existing?.isPaid ?? false,
                paidDate: existing?.paidDate
            )
        }
        var finalAllocations = allocationBuckets.compactMap { b -> Allocation? in
            guard let v = Double(allocs[b.id] ?? ""), v > 0 else { return nil }
            return Allocation(bucketId: b.id, amount: v)
        }
        // Anything left unallocated (or, rarely, over-allocated) automatically
        // settles into the general savings bucket, so bucket balances always
        // sum to total savings — nothing just vanishes.
        if let generalId = store.generalBucket?.id, remaining != 0 {
            if let idx = finalAllocations.firstIndex(where: { $0.bucketId == generalId }) {
                finalAllocations[idx].amount += remaining
            } else {
                finalAllocations.append(Allocation(bucketId: generalId, amount: remaining))
            }
        }
        let income = Income(
            id: incomeToEdit?.id ?? UUID().uuidString,
            date: isoDateFormatter.string(from: date),
            amount: total,
            note: note,
            sourceId: sourceId,
            bills: bills,
            allocations: finalAllocations
        )
        if isEditing {
            store.updateIncome(income)
        } else {
            store.addIncome(income)
        }
        hideKeyboard()
        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if isEditing {
                onSaved?()
            } else {
                withAnimation { saved = false }
                totalStr = ""; allocs = [:]; note = ""; date = Date(); sourceId = nil
                billAmounts = [:]; includedBills = []; prepareBills()
            }
        }
    }

    private func prepareForm() {
        if let incomeToEdit, totalStr.isEmpty, allocs.isEmpty, billAmounts.isEmpty {
            totalStr = String(format: "%.2f", incomeToEdit.amount)
            date = isoDateFormatter.date(from: incomeToEdit.date) ?? Date()
            note = incomeToEdit.note
            sourceId = incomeToEdit.sourceId
            allocs = Dictionary(uniqueKeysWithValues: incomeToEdit.allocations.map { ($0.bucketId, String(format: "%.2f", $0.amount)) })
            billAmounts = Dictionary(uniqueKeysWithValues: incomeToEdit.bills.map { ($0.billId, String(format: "%.2f", $0.amount)) })
            includedBills = Set(incomeToEdit.bills.map(\.billId))
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
        if let suggested = suggestedAllocation(for: bucket), suggested > 0, total > 0 {
            let label = bucket.allocationPercent.map { "\(formatPercent($0))%" } ?? "Suggested"
            return "\(label): \(fmt(suggested))"
        }
        let last = store.lastAlloc(for: bucket.id)
        if last > 0 { return "Last: \(fmt(last))" }
        let average = store.averageAlloc(for: bucket.id)
        if average > 0 { return "Avg: \(fmt(average))" }
        return nil
    }

    private func suggestedAllocation(for bucket: Bucket) -> Double? {
        if let pct = bucket.allocationPercent { return total * (pct / 100) }
        if let amt = bucket.allocationAmount { return amt }
        return nil
    }

    private func allocationButtonLabel(for bucket: Bucket) -> String? {
        if let pct = bucket.allocationPercent { return "\(formatPercent(pct))%" }
        if bucket.allocationAmount != nil { return "Fill" }
        return nil
    }

    private func formatPercent(_ p: Double) -> String {
        p.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", p) : String(format: "%.1f", p)
    }

    private func hideKeyboard() {
        moneyFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
