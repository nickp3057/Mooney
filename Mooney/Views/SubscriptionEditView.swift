import SwiftUI

struct SubscriptionEditView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss
    let subscription: Subscription

    @State private var name: String
    @State private var amountStr: String
    @State private var cadence: TransferFrequency
    @State private var nextDueDate: Date
    @State private var creditCardId: String?
    @State private var status: SubscriptionStatus
    @State private var showDelete = false

    init(subscription: Subscription) {
        self.subscription = subscription
        _name = State(initialValue: subscription.name)
        _amountStr = State(initialValue: String(format: "%.2f", subscription.amount))
        _cadence = State(initialValue: subscription.cadence)
        _nextDueDate = State(initialValue: isoDateFormatter.date(from: subscription.nextDueDate) ?? Date())
        _creditCardId = State(initialValue: subscription.creditCardId)
        _status = State(initialValue: subscription.status)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Name"); Spacer()
                        TextField("Name", text: $name).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Amount"); Spacer()
                        Text("$").foregroundStyle(.secondary)
                        TextField("0.00", text: $amountStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                    Picker("Cadence", selection: $cadence) {
                        ForEach(TransferFrequency.allCases) { f in
                            Text(f.label).tag(f)
                        }
                    }
                    .pickerStyle(.menu)
                    DatePicker("Next Due", selection: $nextDueDate, displayedComponents: .date)
                    Picker("Card Charged", selection: $creditCardId) {
                        Text("None").tag(String?.none)
                        ForEach(store.sortedCreditCards) { card in
                            Text(card.name).tag(String?.some(card.id))
                        }
                    }
                    .pickerStyle(.menu)
                    Picker("Status", selection: $status) {
                        ForEach(SubscriptionStatus.allCases) { s in
                            Text(s.label).tag(s)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section {
                    Button("Delete Subscription", role: .destructive) { showDelete = true }
                }
            }
            .screenBackground()
            .navigationTitle("Edit Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty, let amount = Double(amountStr), amount >= 0 else { return }
                        store.updateSubscription(Subscription(
                            id: subscription.id,
                            name: trimmed,
                            amount: amount,
                            cadence: cadence,
                            nextDueDate: isoDateFormatter.string(from: nextDueDate),
                            creditCardId: creditCardId,
                            status: status
                        ))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || Double(amountStr) == nil)
                }
            }
            .confirmationDialog("Delete \(subscription.name)?", isPresented: $showDelete, titleVisibility: .visible) {
                Button("Delete Subscription", role: .destructive) { store.deleteSubscription(id: subscription.id); dismiss() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}
