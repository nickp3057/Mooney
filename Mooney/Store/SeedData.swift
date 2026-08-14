import Foundation

// Intentionally blank — this is what every first install starts from.
// AppStore.ensureGeneralBucket() creates the one required general bucket
// automatically once there are no buckets at all, so buckets don't need a
// seeded entry either.
let seedBills: [Bill] = []
let seedIncomeSources: [IncomeSource] = []
let seedBuckets: [Bucket] = []
let seedRecurringTransfers: [RecurringTransfer] = []
let seedIncomes: [Income] = []
let seedTransactions: [AppTransaction] = []
