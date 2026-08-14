import SwiftUI

enum SubscriptionSortOption: String, CaseIterable, Identifiable {
    case nextDue = "Next Up"
    case added = "Order Added"
    case amount = "Amount"

    var id: String { rawValue }
}

struct SubscriptionsView: View {
    @Environment(AppStore.self) var store
    @State private var editingSubscription: Subscription?
    @State private var showAdd = false
    @AppStorage("subscriptionSortOption") private var sortOption: SubscriptionSortOption = .nextDue

    private var sortedSubscriptions: [Subscription] {
        switch sortOption {
        case .nextDue: return store.state.subscriptions.sorted { $0.nextDueDate < $1.nextDueDate }
        case .added:   return store.state.subscriptions
        case .amount:  return store.state.subscriptions.sorted { $0.amount > $1.amount }
        }
    }

    var body: some View {
        List {
            if store.state.subscriptions.isEmpty {
                Section {
                    Text("No subscriptions yet.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    HStack {
                        Text("Total / mo")
                        Spacer()
                        Text(fmt(store.monthlySubscriptionTotal)).foregroundStyle(.secondary)
                    }
                    Picker("Sort by", selection: $sortOption) {
                        ForEach(SubscriptionSortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    ForEach(sortedSubscriptions) { sub in
                        Button { editingSubscription = sub } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .foregroundStyle(store.accentColor)
                                    .frame(width: 26, height: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sub.name).foregroundStyle(.primary)
                                    Text("\(sub.cadence.label) · due \(fmtDueDate(sub.nextDueDate))")
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
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingSubscription) { SubscriptionEditView(subscription: $0) }
        .sheet(isPresented: $showAdd) { SubscriptionAddView() }
    }
}
