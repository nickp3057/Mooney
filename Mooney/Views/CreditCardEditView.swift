import SwiftUI

struct CreditCardEditView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss
    let card: CreditCard

    @State private var name: String
    @State private var dueDay: Int
    @State private var bankApp: BankApp?
    @State private var showDelete = false

    init(card: CreditCard) {
        self.card = card
        _name = State(initialValue: card.name)
        _dueDay = State(initialValue: card.dueDay)
        _bankApp = State(initialValue: card.bankApp)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Name"); Spacer()
                        TextField("Name", text: $name).multilineTextAlignment(.trailing)
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
                    Text("The day of the month this card's payment is due. In months without that day, it's due on the last day instead.")
                }
                Section {
                    Button("Delete Card", role: .destructive) { showDelete = true }
                }
            }
            .navigationTitle("Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        store.updateCreditCard(CreditCard(id: card.id, name: trimmed, dueDay: dueDay, isActive: card.isActive, bankApp: bankApp))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Delete \(card.name)?", isPresented: $showDelete, titleVisibility: .visible) {
                Button("Delete Card", role: .destructive) { store.deleteCreditCard(id: card.id); dismiss() }
                Button("Cancel", role: .cancel) {}
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
