import SwiftUI

// Reused from both the Credit Cards settings list and the Calendar view —
// logging a payment always debits primary savings (the general bucket),
// never a bucket, and can be done multiple times against the same cycle
// since the amount varies and you don't always pay it all at once.
struct LogCardPaymentView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss

    let paymentId: String

    @State private var amountStr = ""
    @State private var showMarkPaidConfirm = false
    @State private var showConfetti = false

    private var payment: CardPayment? {
        store.state.cardPayments.first { $0.id == paymentId }
    }

    private var card: CreditCard? {
        payment.flatMap { p in store.state.creditCards.first { $0.id == p.cardId } }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Card"); Spacer()
                        Text(card?.name ?? "—").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Due"); Spacer()
                        Text(fmtDate(payment?.dueDate ?? "")).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Paid So Far"); Spacer()
                        Text(fmt(payment?.amountPaid ?? 0)).foregroundStyle(.secondary)
                    }
                }

                Section {
                    HStack {
                        Text("Amount"); Spacer()
                        Text("$").foregroundStyle(.secondary)
                        TextField("0.00", text: $amountStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                    Button("Log Payment") {
                        guard let amount = Double(amountStr), amount > 0 else { return }
                        store.logCardPayment(paymentId: paymentId, amount: amount)
                        amountStr = ""
                    }
                    .disabled(Double(amountStr) == nil)
                } footer: {
                    Text("Pulls straight from primary savings. Log as many partial payments as you need.")
                        .foregroundStyle(Color.helperText)
                }

                Section {
                    Button("Mark Paid Off", role: .destructive) { showMarkPaidConfirm = true }
                } footer: {
                    Text("Closes out this cycle and rolls \(card?.name ?? "this card") forward to its next due date, regardless of the amount paid so far.")
                        .foregroundStyle(Color.helperText)
                }
            }
            .navigationTitle("Log Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Mark \(card?.name ?? "this card") as paid off?", isPresented: $showMarkPaidConfirm, titleVisibility: .visible) {
                Button("Mark Paid Off", role: .destructive) {
                    store.markCardPaidOff(paymentId: paymentId)
                    showConfetti = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { dismiss() }
                }
                Button("Cancel", role: .cancel) {}
            }
            .overlay {
                if showConfetti { ConfettiView() }
            }
        }
    }
}
