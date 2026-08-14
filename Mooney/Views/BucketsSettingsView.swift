import SwiftUI

struct BucketsSettingsView: View {
    @Environment(AppStore.self) var store
    @State private var editingBucket: Bucket?
    @State private var showAddBucket = false
    @State private var showArchived = false

    var active:   [Bucket] { store.sortedNonArchived.filter  { $0.isActive  } }
    var inactive: [Bucket] { store.sortedNonArchived.filter  { !$0.isActive } }
    var archived: [Bucket] { store.state.buckets.filter { $0.archived }.sorted { $0.order < $1.order } }

    var body: some View {
        List {
            if !active.isEmpty {
                Section("Active Buckets") {
                    ForEach(active) { b in
                        BucketSettingRow(bucket: b) { editingBucket = b }
                    }
                    .onMove { store.moveBuckets(from: $0, to: $1, among: active) }
                }
            }

            if !inactive.isEmpty {
                Section("Planned Buckets") {
                    ForEach(inactive) { b in
                        BucketSettingRow(bucket: b) { editingBucket = b }
                    }
                    .onMove { store.moveBuckets(from: $0, to: $1, among: inactive) }
                }
            }

            Section {
                Button("+ New Bucket") { showAddBucket = true }
                    .foregroundStyle(store.accentColor)
            }

            if !archived.isEmpty {
                Section {
                    DisclosureGroup("Archived (\(archived.count))", isExpanded: $showArchived) {
                        ForEach(archived) { b in
                            BucketSettingRow(bucket: b) { editingBucket = b }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Buckets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .sheet(item: $editingBucket) { BucketEditView(bucket: $0) }
        .sheet(isPresented: $showAddBucket) { BucketAddView() }
    }
}
