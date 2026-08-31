import SwiftUI

struct CreditCardAddView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var dueDay = 1
    @State private var bankApp: BankApp?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Name"); Spacer()
                        TextField("e.g. Amex", text: $name).multilineTextAlignment(.trailing)
                    }
                    Picker("Due Day", selection: $dueDay) {
                        ForEach(1...31, id: \.self) { day in
                            Text(ordinal(day)).tag(day)
                        }
                    }
                    .pickerStyle(.menu)
                    Picker("Bank App", selection: $bankApp) {
                        Text("None").tag(BankApp?.none)
                        ForEach(BankApp.allCases) { app in
                            Text(app.label).tag(BankApp?.some(app))
                        }
                    }
                    .pickerStyle(.menu)
                } footer: {
                    Text("The day of the month this card's payment is due. In months without that day, it's due on the last day instead. Bank App adds a quick-open button on the Ledger's Cards Due section — best-effort, may just open the bank's website if the app doesn't support it.")
                        .foregroundStyle(Color.helperText)
                }
            }
            .navigationTitle("New Credit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        store.addCreditCard(CreditCard(id: UUID().uuidString, name: trimmed, dueDay: dueDay, isActive: true, bankApp: bankApp))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        switch (n % 10, n % 100) {
        case (1, let h) where h != 11: suffix = "st"
        case (2, let h) where h != 12: suffix = "nd"
        case (3, let h) where h != 13: suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }
}
