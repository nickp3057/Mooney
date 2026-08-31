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
                    CreditCardSettingRow(card: card) { editingCard = card }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                store.deleteCreditCard(id: card.id)
                            }
                        }
                }
                Button("+ New Credit Card") { showAdd = true }
                    .foregroundStyle(accentColor)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Credit Cards")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingCard) { CreditCardEditView(card: $0) }
        .sheet(isPresented: $showAdd) { CreditCardAddView() }
    }
}
