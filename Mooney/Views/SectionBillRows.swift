import SwiftUI

struct SectionBillRows: View {
    @Environment(AppStore.self) var store
    let incomeId: String
    let bills: [BillPayment]

    var body: some View {
        ForEach(bills) { bill in
            let unpaidGroup = store.unpaidBillGroup(for: bill.billId)
            let canPay = bill.isPaid || unpaidGroup?.canPay == true
            HStack(spacing: 8) {
                Button {
                    if bill.isPaid {
                        store.setBillPaymentPaid(incomeId: incomeId, paymentId: bill.id, isPaid: false)
                    } else if canPay {
                        store.setUnpaidBillGroupPaid(billId: bill.billId)
                    }
                } label: {
                    Image(systemName: bill.isPaid ? "checkmark.circle.fill" : canPay ? "circle" : "lock.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(bill.isPaid ? .green : canPay ? store.accentColor : .secondary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .disabled(!bill.isPaid && !canPay)
                VStack(alignment: .leading, spacing: 1) {
                    Text(bill.name)
                        .font(.subheadline)
                    Text(bill.isPaid ? "Paid" : canPay ? "Ready to pay" : "\(fmt(unpaidGroup?.savedAmount ?? bill.amount)) of \(fmt(unpaidGroup?.requiredAmount ?? bill.amount)) saved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(fmt(bill.amount)).font(.subheadline)
            }
        }
    }
}
