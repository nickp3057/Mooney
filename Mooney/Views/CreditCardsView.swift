import SwiftUI

struct CreditCardsView: View {
    @Environment(AppStore.self) var store
    @State private var showAdd = false
    @State private var loggingPaymentId: String?

    private func pendingPayment(for card: CreditCard) -> CardPayment? {
        store.pendingCardPayments.first { $0.card.id == card.id }?.payment
    }

    var body: some View {
        List {
            if store.sortedCreditCards.isEmpty {
                Section {
                    Text("No credit cards yet.").foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(store.sortedCreditCards) { card in
                        Button {
                            loggingPaymentId = pendingPayment(for: card)?.id
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "creditcard.fill")
                                    .foregroundStyle(store.accentColor)
                                    .frame(width: 26, height: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(card.name).foregroundStyle(.primary)
                                    if let payment = pendingPayment(for: card) {
                                        Text(payment.amountPaid > 0
                                             ? "Due \(fmtDate(payment.dueDate)) · \(fmt(payment.amountPaid)) paid"
                                             : "Due \(fmtDate(payment.dueDate))")
                                            .font(.caption).foregroundStyle(.secondary)
                                    } else {
                                        Text("Due on the \(card.dueDay)")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text("Log Payment")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(store.accentColor)
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                store.deleteCreditCard(id: card.id)
                            }
                        }
                    }
                }
            }
            Section {
                Button("+ New Credit Card") { showAdd = true }
                    .foregroundStyle(store.accentColor)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Credit Cards")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAdd) { CreditCardAddView() }
        .sheet(isPresented: Binding(
            get: { loggingPaymentId != nil },
            set: { if !$0 { loggingPaymentId = nil } }
        )) {
            if let loggingPaymentId {
                LogCardPaymentView(paymentId: loggingPaymentId)
            }
        }
    }
}
