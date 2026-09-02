import SwiftUI

struct RecurringTransfersSettingsView: View {
    @Environment(AppStore.self) var store
    @Environment(\.tabAccentColor) private var accentColor
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
                Button { showAddTransfer = true } label: {
                    AddRow(title: "New Recurring Transfer", tint: accentColor)
                }
                .buttonStyle(.plain)
            } footer: {
                Text("Scheduled deposits post automatically when the app opens on or after each due date.")
            }
        }
        .listStyle(.insetGrouped)
        .screenBackground()
        .navigationTitle("Recurring Transfers")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingTransfer) { RecurringTransferEditView(transfer: $0) }
        .sheet(isPresented: $showAddTransfer) { RecurringTransferAddView() }
    }
}
