import Foundation

struct PaySchedule: Codable, Equatable {
    var nextPayDate: String  // yyyy-MM-dd
    var frequency: TransferFrequency
}
