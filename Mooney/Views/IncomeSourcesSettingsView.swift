import SwiftUI

struct IncomeSourcesSettingsView: View {
    @Environment(AppStore.self) var store
    @Environment(\.tabAccentColor) private var accentColor
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
                        .bubbleCardRow()
                }
                Button("+ New Source") { showAddSource = true }
                    .foregroundStyle(accentColor)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Income Sources")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddSource) { IncomeSourceAddView() }
    }
}
