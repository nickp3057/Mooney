import SwiftUI

struct SubscriptionAddView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var amountStr = ""
    @State private var cadence: TransferFrequency = .monthly
    @State private var nextDueDate = Date()
    @State private var creditCardId: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Name"); Spacer()
                        TextField("e.g. Spotify", text: $name).multilineTextAlignment(.trailing)
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
                }
            }
            .screenBackground()
            .navigationTitle("New Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty, let amount = Double(amountStr), amount >= 0 else { return }
                        store.addSubscription(Subscription(
                            id: UUID().uuidString,
                            name: trimmed,
                            amount: amount,
                            cadence: cadence,
                            nextDueDate: isoDateFormatter.string(from: nextDueDate),
                            creditCardId: creditCardId
                        ))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || Double(amountStr) == nil)
                }
            }
        }
    }
}
