import SwiftUI

struct BucketEditView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss
    let bucket: Bucket

    @State private var name:       String
    @State private var selectedColorHex: String
    @State private var goalStr:    String
    @State private var hasGoalDate: Bool
    @State private var goalDate: Date
    @State private var isSpending: Bool
    @State private var showArchive = false
    @State private var showDelete = false

    init(bucket: Bucket) {
        self.bucket   = bucket
        _name         = State(initialValue: bucket.name)
        _selectedColorHex = State(initialValue: bucket.colorHex)
        _goalStr      = State(initialValue: bucket.goal.map { String($0) } ?? "")
        _hasGoalDate  = State(initialValue: bucket.goalDate != nil)
        _goalDate     = State(initialValue: bucket.goalDate.flatMap { isoDateFormatter.date(from: $0) } ?? Date())
        _isSpending   = State(initialValue: bucket.isSpending)
    }

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
                        TextField("None", text: $goalStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing).frame(width: 80)
                    }
                    Toggle("Save By Date", isOn: $hasGoalDate)
                    if hasGoalDate {
                        DatePicker("Save By", selection: $goalDate, displayedComponents: .date)
                    }
                    Toggle("Spending Bucket", isOn: $isSpending)
                        .disabled(bucket.isGeneral)
                }
                if bucket.isGeneral {
                    Section {
                        Text("This is the general savings bucket — any income you don't explicitly allocate settles here, so it can't be archived or deleted.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        Button("Archive Bucket", role: .destructive) { showArchive = true }
                        Button("Delete Bucket Permanently", role: .destructive) { showDelete = true }
                    }
                }
            }
            .navigationTitle("Edit \(bucket.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateBucket(id: bucket.id, name: name,
                                           colorHex: selectedColorHex,
                                           goal: Double(goalStr),
                                           goalDate: hasGoalDate ? isoDateFormatter.string(from: goalDate) : nil,
                                           isSpending: isSpending)
                        dismiss()
                    }.fontWeight(.semibold)
                }
            }
            .confirmationDialog("Archive \(bucket.name)?", isPresented: $showArchive, titleVisibility: .visible) {
                Button("Archive", role: .destructive) { store.archiveBucket(id: bucket.id); dismiss() }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Delete \(bucket.name) permanently?", isPresented: $showDelete, titleVisibility: .visible) {
                Button("Delete Permanently", role: .destructive) { store.deleteBucket(id: bucket.id); dismiss() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the bucket itself. Past incomes and transactions that reference it will keep showing but won't be linked to it anymore.")
            }
        }
    }
}
