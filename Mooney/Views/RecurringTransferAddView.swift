import SwiftUI

struct RecurringTransferAddView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var amountStr = ""
    @State private var bucketId: String?
    @State private var frequency: TransferFrequency = .weekly
    @State private var startDate = Date()
    @State private var isExternal = false
    @State private var destination = ""

    private var trimmedDestination: String { destination.trimmingCharacters(in: .whitespaces) }

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
                    Picker(isExternal ? "From Bucket" : "To Bucket", selection: $bucketId) {
                        Text("Choose…").tag(String?.none)
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
            .screenBackground()
            .navigationTitle("New Recurring Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty, let amount = Double(amountStr), amount > 0, let bucketId else { return }
                        guard !isExternal || !trimmedDestination.isEmpty else { return }
                        store.addRecurringTransfer(RecurringTransfer(
                            id: UUID().uuidString,
                            name: trimmed,
                            bucketId: bucketId,
                            amount: amount,
                            frequency: frequency,
                            startDate: isoDateFormatter.string(from: startDate),
                            lastRunDate: nil,
                            isActive: true,
                            externalDestination: isExternal ? trimmedDestination : nil
                        ))
                        store.runScheduledTransfers()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || Double(amountStr) == nil || bucketId == nil || (isExternal && trimmedDestination.isEmpty))
                }
            }
        }
    }
}
