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
    var allocated: Double {
        store.activeBuckets.reduce(0) { $0 + (Double(allocs[$1.id] ?? "") ?? 0) }
    }
    var envelopeMoney: Double { total - billTotal }
    var remaining: Double { envelopeMoney - allocated }
    var isGood:  Bool { abs(remaining) < 0.005 }
    var isEditing: Bool { incomeToEdit != nil }

    var body: some View {
        NavigationStack {
            if saved {
                VStack(spacing: 16) {
                    Text(isEditing ? "Saved" : "🎉").font(.system(size: isEditing ? 34 : 64, weight: .bold))
                    Text(isEditing ? "Income updated!" : "Income saved!").font(.title.bold())
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
                                .focused($moneyFieldFocused)
                        }
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
                                        .focused($moneyFieldFocused)
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

                                // Leftover money isn't an error — it just settles into
                                // Savings. Over-allocating (spoken for more than you have)
                                // is the only case worth flagging.
                                let remainingLabel = isGood ? "Fully allocated"
                                    : remaining > 0 ? "\(fmt(remaining)) → Savings"
                                    : "Over-allocated by \(fmt(-remaining))"
                                let color: Color = isGood ? .green : remaining > 0 ? .secondary : .red
                                HStack {
                                    Text(remainingLabel)
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
                                .focused($moneyFieldFocused)
                                if let suggested = suggestedAllocation(for: bucket),
                                   let label = allocationButtonLabel(for: bucket) {
                                    Button(label) {
                                        allocs[bucket.id] = String(format: "%.2f", suggested)
                                    }
                                    .font(.system(size: 12, weight: .semibold))
                                    .buttonStyle(.bordered)
                                    .disabled(total <= 0)
                                }
                                if let goalNeed = store.suggestedGoalContribution(for: bucket), goalNeed > 0 {
                                    Button("Goal") {
                                        allocs[bucket.id] = String(format: "%.2f", goalNeed.rounded(.up))
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
                            Text(isEditing ? "Update Income" : "Save Income")
                                .frame(maxWidth: .infinity).font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(store.accentColor)
                        .disabled(total <= 0)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
                .listStyle(.insetGrouped)
                .navigationTitle(isEditing ? "Edit Income" : "Add Income")
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
        var finalAllocations = store.activeBuckets.compactMap { b -> Allocation? in
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
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if isEditing {
                onSaved?()
            } else {
                saved = false; totalStr = ""; allocs = [:]; note = ""; date = Date(); sourceId = nil
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
