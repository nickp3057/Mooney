import SwiftUI

struct SubscriptionsView: View {
    @Environment(AppStore.self) var store
    @State private var editingSubscription: Subscription?
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            List {
                if store.sortedSubscriptions.isEmpty {
                    Section {
                        Text("No subscriptions yet.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(store.sortedSubscriptions) { sub in
                            Button { editingSubscription = sub } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                        .foregroundStyle(store.accentColor)
                                        .frame(width: 26, height: 26)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(sub.name).foregroundStyle(.primary)
                                        Text("\(sub.cadence.label) · due \(fmtDate(sub.nextDueDate))")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(fmt(sub.amount)).foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", role: .destructive) {
                                    store.deleteSubscription(id: sub.id)
                                }
                            }
                        }
                    }
                }
                Section {
                    Button("+ New Subscription") { showAdd = true }
                        .foregroundStyle(store.accentColor)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Subscriptions")
            .sheet(item: $editingSubscription) { SubscriptionEditView(subscription: $0) }
            .sheet(isPresented: $showAdd) { SubscriptionAddView() }
        }
    }
}
