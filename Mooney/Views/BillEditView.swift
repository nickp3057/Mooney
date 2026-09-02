import SwiftUI

struct BillEditView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss
    let bill: Bill

    @State private var name: String
    @State private var amountStr: String
    @State private var showDelete = false

    init(bill: Bill) {
        self.bill = bill
        _name = State(initialValue: bill.name)
        _amountStr = State(initialValue: String(format: "%.2f", bill.amount))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Name"); Spacer()
                        TextField("Bill name", text: $name).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Amount"); Spacer()
                        Text("$").foregroundStyle(.secondary)
                        TextField("0.00", text: $amountStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                }
                Section {
                    Button("Delete Bill", role: .destructive) { showDelete = true }
                }
            }
            .screenBackground()
            .navigationTitle("Edit Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty, let amount = Double(amountStr), amount >= 0 else { return }
                        store.updateBill(id: bill.id, name: trimmed, amount: amount)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || Double(amountStr) == nil)
                }
            }
            .confirmationDialog("Delete \(bill.name)?", isPresented: $showDelete, titleVisibility: .visible) {
                Button("Delete Bill", role: .destructive) { store.deleteBill(id: bill.id); dismiss() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}
