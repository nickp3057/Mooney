import SwiftUI

struct IncomeSourcesSettingsView: View {
    @Environment(AppStore.self) var store
    @Environment(\.tabAccentColor) private var accentColor
    @State private var showAddSource = false

    var body: some View {
        List {
            Section {
                ForEach(store.state.incomeSources) { source in
                    HStack(spacing: 12) {
                        IconTile(systemName: "dollarsign", color: accentColor, size: 32)
                        Text(source.name)
                        Spacer()
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) {
                            store.deleteIncomeSource(id: source.id)
                        }
                    }
                }
                Button { showAddSource = true } label: {
                    AddRow(title: "New Source", tint: accentColor)
                }
                .buttonStyle(.plain)
            } footer: {
                Text("Where money comes from — a job, a side gig — so incomes can be tagged when you log them.")
            }
        }
        .listStyle(.insetGrouped)
        .screenBackground()
        .navigationTitle("Income Sources")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddSource) { IncomeSourceAddView() }
    }
}
