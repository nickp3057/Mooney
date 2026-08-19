import SwiftUI

struct CreditCardsSettingsView: View {
    @Environment(AppStore.self) var store
    @Environment(\.tabAccentColor) private var accentColor
    @State private var editingCard: CreditCard?
    @State private var showAdd = false

    var body: some View {
        List {
            Section {
                ForEach(store.sortedCreditCards) { card in
                    Button { editingCard = card } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "creditcard.fill")
                                .foregroundStyle(accentColor)
                                .frame(width: 26, height: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.name).foregroundStyle(.primary)
                                Text("Due on the \(card.dueDay)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) {
                            store.deleteCreditCard(id: card.id)
                        }
                    }
                    .bubbleCardRow()
                }
                Button("+ New Credit Card") { showAdd = true }
                    .foregroundStyle(accentColor)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Credit Cards")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingCard) { CreditCardEditView(card: $0) }
        .sheet(isPresented: $showAdd) { CreditCardAddView() }
    }
}
