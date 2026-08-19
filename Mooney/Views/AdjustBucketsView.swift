import SwiftUI

// Manual reconciliation tool: nudge individual bucket balances up/down until
// the bucket total matches a target (typically the live MACU balance),
// rather than dumping the whole difference on the general bucket the way
// BalanceOverrideView does. Each nonzero row becomes its own "adjustment"
// AppTransaction on save, so it stays visible per-bucket in the ledger.
struct AdjustBucketsView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss
    let target: Double

    @State private var deltas: [String: Double] = [:]

    private var totalDelta: Double { deltas.values.reduce(0, +) }
    private var previewTotal: Double { store.totalSavings + totalDelta }
    private var remaining: Double { target - previewTotal }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack { Text("Target (MACU)"); Spacer(); Text(fmt(target)).foregroundStyle(.secondary) }
                    HStack { Text("Current Total"); Spacer(); Text(fmt(store.totalSavings)).foregroundStyle(.secondary) }
                    if totalDelta != 0 {
                        HStack { Text("After Changes"); Spacer(); Text(fmt(previewTotal)).foregroundStyle(.secondary) }
                    }
                    HStack {
                        Text("Remaining")
                        Spacer()
                        if abs(remaining) < 0.01 {
                            Label("Matched", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Text(fmt(remaining))
                                .foregroundStyle(remaining > 0 ? .green : .red)
                        }
                    }
                }

                Section("Buckets") {
                    ForEach(store.savingsBuckets) { bucket in
                        BucketAdjustRow(bucket: bucket, delta: Binding(
                            get: { deltas[bucket.id] ?? 0 },
                            set: { deltas[bucket.id] = $0 }
                        ))
                    }
                }
            }
            .navigationTitle("Adjust Buckets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(totalDelta == 0)
                }
            }
        }
    }

    private func save() {
        for (bucketId, delta) in deltas where delta != 0 {
            store.addTransaction(AppTransaction(
                id: UUID().uuidString, bucketId: bucketId, amount: delta,
                date: todayISO(), note: "Balance reconciliation", type: "adjustment"
            ))
        }
        dismiss()
    }
}

private struct BucketAdjustRow: View {
    let bucket: Bucket
    @Binding var delta: Double

    @State private var magnitudeStr = ""
    @State private var isAdd = true

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 7)
                .fill(bucket.color)
                .frame(width: 22, height: 22)
            Text(bucket.name)
            Spacer()
            Picker("", selection: $isAdd) {
                Text("+").tag(true)
                Text("−").tag(false)
            }
            .pickerStyle(.segmented)
            .frame(width: 76)
            MoneyEntryField(text: $magnitudeStr, placeholder: "0.00", width: 80, isFocused: nil)
        }
        .onChange(of: magnitudeStr) { updateDelta() }
        .onChange(of: isAdd) { updateDelta() }
    }

    private func updateDelta() {
        let magnitude = Double(magnitudeStr) ?? 0
        delta = isAdd ? magnitude : -magnitude
    }
}
