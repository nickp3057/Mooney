import Foundation

struct UnpaidBillGroup: Identifiable {
    var id: String { billId }
    var billId: String
    var name: String
    var savedAmount: Double
    var requiredAmount: Double
    var paymentCount: Int

    var canPay: Bool {
        savedAmount + 0.005 >= requiredAmount
    }
}
