import SwiftUI

struct BalanceOverrideView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss
    @State private var targetStr = ""
    @State private var note = ""
    @FocusState private var amountFocused: Bool

    var target: Double? { Double(targetStr) }
    var delta: Double? { target.map { $0 - store.totalSavings } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Current")
                        Spacer()
                        Text(fmt(store.totalSavings)).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Set To")
                        Spacer()
                        MoneyEntryField(text: $targetStr, placeholder: "0.00", width: 110, isFocused: $amountFocused)
                    }
                    if let delta, delta != 0 {
                        HStack {
                            Text("Change")
                            Spacer()
                            Text((delta >= 0 ? "+" : "") + fmt(delta))
                                .foregroundStyle(delta >= 0 ? .green : .red)
                        }
                    }
                    TextField("Reason (optional) — e.g. interest, initial setup", text: $note)
                }
                Section {
                    Text("This logs the difference as an adjustment on the general Savings bucket, so it stays visible in that bucket's history and in the ledger — it doesn't just overwrite the number.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Correct Balance")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                targetStr = String(format: "%.2f", store.totalSavings)
                amountFocused = true
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let target { store.overrideTotalSavings(to: target, note: note) }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(target == nil)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { amountFocused = false }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
