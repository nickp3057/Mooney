import SwiftUI

struct RecurringTransfersSettingsView: View {
    @Environment(AppStore.self) var store
    @State private var editingTransfer: RecurringTransfer?
    @State private var showAddTransfer = false

    var body: some View {
        List {
            Section {
                ForEach(store.sortedRecurringTransfers) { transfer in
                    RecurringTransferRow(transfer: transfer) { editingTransfer = transfer }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                store.deleteRecurringTransfer(id: transfer.id)
                            }
                        }
                }
                Button("+ New Recurring Transfer") { showAddTransfer = true }
                    .foregroundStyle(store.accentColor)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Recurring Transfers")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingTransfer) { RecurringTransferEditView(transfer: $0) }
        .sheet(isPresented: $showAddTransfer) { RecurringTransferAddView() }
    }
}
