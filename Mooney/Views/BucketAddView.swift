import SwiftUI

struct BucketAddView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss

    @State private var name          = ""
    @State private var selectedColorHex = bucketPalette.first!
    @State private var goalStr       = ""
    @State private var hasGoalDate   = false
    @State private var goalDate      = Date()
    @State private var isSpending    = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Name"); Spacer()
                        TextField("Bucket name", text: $name).multilineTextAlignment(.trailing)
                    }
                    ColorSwatchPicker(selectedHex: $selectedColorHex)
                    HStack {
                        Text("Savings Goal"); Spacer()
                        Text("$").foregroundStyle(.secondary)
                        TextField("Optional", text: $goalStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing).frame(width: 80)
                    }
                    Toggle("Save By Date", isOn: $hasGoalDate)
                    if hasGoalDate {
                        DatePicker("Save By", selection: $goalDate, displayedComponents: .date)
                    }
                    Toggle("Spending Bucket", isOn: $isSpending)
                }
            }
            .navigationTitle("New Bucket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        let maxOrder = store.state.buckets.map { $0.order }.max() ?? -1
                        store.addBucket(Bucket(
                            id: UUID().uuidString, name: trimmed,
                            colorHex: selectedColorHex,
                            isActive: true, archived: false,
                            goal: Double(goalStr),
                            goalDate: hasGoalDate ? isoDateFormatter.string(from: goalDate) : nil,
                            isSpending: isSpending,
                            order: maxOrder + 1
                        ))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
