import SwiftUI

struct RecurringTransferAddView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var amountStr = ""
    @State private var bucketId: String?
    @State private var frequency: TransferFrequency = .weekly
    @State private var startDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Name"); Spacer()
                        TextField("e.g. Charles Schwab", text: $name).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Amount"); Spacer()
                        Text("$").foregroundStyle(.secondary)
                        TextField("0.00", text: $amountStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                    Picker("To Bucket", selection: $bucketId) {
                        Text("Choose…").tag(String?.none)
                        ForEach(store.activeBuckets) { bucket in
                            Text(bucket.name).tag(String?.some(bucket.id))
                        }
                    }
                    Picker("Frequency", selection: $frequency) {
                        ForEach(TransferFrequency.allCases) { f in
                            Text(f.label).tag(f)
                        }
                    }
                    DatePicker("Starting", selection: $startDate, displayedComponents: .date)
                }
            }
            .navigationTitle("New Recurring Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty, let amount = Double(amountStr), amount > 0, let bucketId else { return }
                        store.addRecurringTransfer(RecurringTransfer(
                            id: UUID().uuidString,
                            name: trimmed,
                            bucketId: bucketId,
                            amount: amount,
                            frequency: frequency,
                            startDate: isoDateFormatter.string(from: startDate),
                            lastRunDate: nil,
                            isActive: true
                        ))
                        store.runScheduledTransfers()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || Double(amountStr) == nil || bucketId == nil)
                }
            }
        }
    }
}
