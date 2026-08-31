import SwiftUI

struct BillsSettingsView: View {
    @Environment(AppStore.self) var store
    @Environment(\.tabAccentColor) private var accentColor
    @State private var editingBill: Bill?
    @State private var showAddBill = false

    var body: some View {
        List {
            Section {
                ForEach(store.sortedBills) { bill in
                    BillSettingRow(bill: bill) { editingBill = bill }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                store.deleteBill(id: bill.id)
                            }
                        }
                }
                Button("+ New Bill") { showAddBill = true }
                    .foregroundStyle(accentColor)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Bills")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingBill) { BillEditView(bill: $0) }
        .sheet(isPresented: $showAddBill) { BillAddView() }
    }
}
