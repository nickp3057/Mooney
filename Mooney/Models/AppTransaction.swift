import Foundation

struct AppTransaction: Identifiable, Codable {
    var id: String
    var bucketId: String
    var amount: Double
    var date: String
    var note: String
    var type: String
    // Points at the paired leg of a bucket-to-bucket transfer (see
    // AppStore.transferBetweenBuckets) so deleting either leg removes both —
    // without this, deleting one side would leave an orphaned entry and
    // silently break the totalSavings invariant. Nil for every other type.
    var linkedId: String? = nil
}
