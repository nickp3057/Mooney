import SwiftUI

struct IncomeSourcesSettingsView: View {
    @Environment(AppStore.self) var store
    @State private var showAddSource = false

    var body: some View {
        List {
            Section {
                ForEach(store.state.incomeSources) { source in
                    Text(source.name)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                store.deleteIncomeSource(id: source.id)
                            }
                        }
                }
                Button("+ New Source") { showAddSource = true }
                    .foregroundStyle(store.accentColor)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Income Sources")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddSource) { IncomeSourceAddView() }
    }
}
