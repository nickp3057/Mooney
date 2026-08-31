import SwiftUI

struct RecurringTransferEditView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss
    let transfer: RecurringTransfer

    @State private var name: String
    @State private var amountStr: String
    @State private var bucketId: String?
    @State private var frequency: TransferFrequency
    @State private var startDate: Date
    @State private var isExternal: Bool
    @State private var destination: String

    private var trimmedDestination: String { destination.trimmingCharacters(in: .whitespaces) }

    init(transfer: RecurringTransfer) {
        self.transfer = transfer
        _name = State(initialValue: transfer.name)
        _amountStr = State(initialValue: String(format: "%.2f", transfer.amount))
        _bucketId = State(initialValue: transfer.bucketId)
        _frequency = State(initialValue: transfer.frequency)
        _startDate = State(initialValue: isoDateFormatter.date(from: transfer.startDate) ?? Date())
        _isExternal = State(initialValue: transfer.externalDestination != nil)
        _destination = State(initialValue: transfer.externalDestination ?? "")
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
                    Picker(isExternal ? "From Bucket" : "To Bucket", selection: $bucketId) {
                        ForEach(store.activeBuckets) { bucket in
                            Text(bucket.name).tag(String?.some(bucket.id))
                        }
                    }
                    .pickerStyle(.menu)
                    Picker("Frequency", selection: $frequency) {
                        ForEach(TransferFrequency.allCases) { f in
                            Text(f.label).tag(f)
                        }
                    }
                    .pickerStyle(.menu)
                    DatePicker("Starting", selection: $startDate, displayedComponents: .date)
                }
                Section {
                    Toggle("Leaves Mooney", isOn: $isExternal)
                    if isExternal {
                        HStack {
                            Text("Destination"); Spacer()
                            TextField("e.g. CD, Charles Schwab", text: $destination)
                                .multilineTextAlignment(.trailing)
                        }
                        HStack(spacing: 8) {
                            ForEach(["CD", "Charles Schwab"], id: \.self) { preset in
                                Button(preset) { destination = preset }
                                    .font(.caption.weight(.semibold))
                                    .buttonStyle(.bordered)
                            }
                            Spacer()
                        }
                    }
                } footer: {
                    Text(isExternal
                         ? "Each occurrence pulls the amount out of the bucket above and out of your savings total for good — for money moving somewhere Mooney doesn't track, like a CD or an outside brokerage."
                         : "Each occurrence deposits the amount into the bucket above.")
                        .foregroundStyle(Color.helperText)
                }
            }
            .navigationTitle("Edit Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty, let amount = Double(amountStr), amount > 0, let bucketId else { return }
                        guard !isExternal || !trimmedDestination.isEmpty else { return }
                        store.updateRecurringTransfer(RecurringTransfer(
                            id: transfer.id,
                            name: trimmed,
                            bucketId: bucketId,
                            amount: amount,
                            frequency: frequency,
                            startDate: isoDateFormatter.string(from: startDate),
                            lastRunDate: transfer.lastRunDate,
                            isActive: transfer.isActive,
                            externalDestination: isExternal ? trimmedDestination : nil
                        ))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || Double(amountStr) == nil || bucketId == nil || (isExternal && trimmedDestination.isEmpty))
                }
            }
        }
    }
}
