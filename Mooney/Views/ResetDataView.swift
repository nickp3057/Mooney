import SwiftUI

struct ResetDataView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var resetText: String
    let onReset: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This clears incomes, transactions, and unpaid bill history. Your bucket and bill setup stays, but balances go to $0.")
                        .foregroundStyle(.secondary)
                    TextField("Type Lauren", text: $resetText)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Type Lauren to reset all data")
                }

                Section {
                    Button("Reset All Data", role: .destructive) {
                        onReset()
                    }
                    .disabled(resetText != "Lauren")
                }
            }
            .navigationTitle("Reset Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        resetText = ""
                        dismiss()
                    }
                }
            }
        }
    }
}
