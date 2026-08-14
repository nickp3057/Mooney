# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Mooney is a personal budgeting/finance iOS app (SwiftUI) built around savings "buckets," plus bill/subscription/credit-card tracking and an optional live bank balance via a companion Plaid backend. `Backend/` is a small single-user Node/Express service — it's the only thing in this repo allowed to hold Plaid secrets.

## Commands

### iOS app (`Mooney/`)
Many agent environments running this repo have no iOS SDK, so `xcodebuild`/Simulator runs aren't possible from the CLI — open `Mooney.xcodeproj` in Xcode to build, run, or use Simulator.

Where the iOS SDK isn't available, use a whole-module typecheck against the macOS SDK instead, excluding the couple of files that `import UIKit` (they won't resolve on macOS):
```
swiftc -typecheck -swift-version 5 -sdk $(xcrun --sdk macosx --show-sdk-path) \
  $(find Mooney -name "*.swift" ! -name "NotesView.swift" ! -name "AddIncomeView.swift")
```
Expect a handful of *known* false-positive errors from iOS-only SwiftUI APIs that don't exist on macOS (`.keyboardType(...)`, `.listStyle(.insetGrouped)`, `.navigationBarTitleDisplayMode(...)`) — these aren't real bugs, just SDK-availability noise (Swift also dedupes repeated identical "unavailable" diagnostics across the module, so which single file the error surfaces on can look arbitrary). Anything else reported is a genuine error worth investigating.

There are no test targets, no SwiftLint/SwiftFormat config, and no CI in this repo.

### Backend (`Backend/`)
```
cd Backend
npm install
cp .env.example .env   # fill in Plaid sandbox credentials
npm start                # node server.js, listens on :4001
```
Meant to run on a home NAS reachable only over Tailscale — never port-forwarded publicly (see the comment in `docker-compose.yml`). Deploy there via `docker compose up -d`.

## Architecture

### State: one JSON blob, no Core Data/SwiftData
`AppStore` (`Store/AppStore.swift`, `@Observable`) holds a single `AppState` struct (`Models/AppState.swift`) that *is* the app's entire persisted data — buckets, incomes, transactions, bills, subscriptions, credit cards, etc. — (de)serialized as one JSON blob in `UserDefaults`, not a database. Every mutation is a method on `AppStore` that mutates `state` and then calls the private `save()`.

`AppState`'s `CodingKeys` intentionally keeps old wire names alive (e.g. `incomes` encodes/decodes as `"paychecks"`), and most fields decode with `decodeIfPresent(...) ?? default`. That pattern *is* the app's migration mechanism — there's no separate migration step. When adding a field to `AppState` or any nested model, follow it (optional-decode with a sane default) rather than assuming existing saved data already has the field.

### Real vs. decoy state (privacy/duress PIN)
The app supports an optional PIN lock with a *decoy* PIN (`Models/AppLock.swift`'s `AppLockManager`, `Store/DecoySeedData.swift`). Entering the decoy PIN swaps `AppStore.state` to an entirely separate, plausible-looking generated `AppState` (`generateDecoyState()`), stored under its own UserDefaults key (`decoyStorageKey`) — the real financial data stays untouched under `storageKey`. `AppStore.isDecoyMode` gates this; check it before adding anything that should stay hidden in decoy mode (e.g. `DashboardView` skips the live Plaid balance section, and `SettingsView` skips the App Lock section, when `isDecoyMode` is true).

PIN hashes live in the Keychain (via `AppLockManager`'s private `Keychain` wrapper), deliberately kept out of `AppState`/UserDefaults so they can never end up in a JSON export/backup.

### The general-bucket invariant
Exactly one `Bucket` is flagged `isGeneral` — the catch-all for savings not explicitly assigned to a bucket. `AppStore.totalSavings` is defined as the sum of all bucket balances plus the unpaid-bills total, so that invariant has to hold. `ensureGeneralBucket()` (called every launch via `catchUpState()`) repairs old saved data from before the concept existed.

### Derived view models — never persisted
Several types are computed fresh from `AppState` on demand rather than stored:
- `LedgerEntry` (`AppStore.ledgerEntries`) — merges incomes + standalone transactions into one reverse-chronological feed for the Ledger tab.
- `CalendarEvent` (`Store/CalendarEvents.swift`) — projects subscriptions, credit card due dates, and paychecks into calendar occurrences for a given month. Recurring transfers are deliberately excluded from this projection (see the comment there) — that's plumbing, not a user-facing charge.
- `UnpaidBillGroup`, `SavingsPoint`, `pendingCardPayments` — similar on-the-fly aggregates on `AppStore`.

When adding a new "what does the user need to see right now" surface, prefer a computed property/method on `AppStore` over adding a new persisted field.

### Plaid: the backend holds the secret, the app never does
`Store/PlaidClient.swift` is a thin HTTP client for the 4 endpoints in `Backend/server.js` (`/link_token`, `/exchange_public_token`, `/balance`, `/disconnect`). The Plaid secret and access token only ever live server-side (`Backend/storage.js`); the app just stores the backend's URL as a plain string in `UserDefaults` (`PlaidClient.backendURL`). This mirrors the PIN separation above — secret material never enters the main state blob.

### View organization
`Views/` is flat — no per-feature folders. Conventions to follow:
- `XAddView` / `XEditView` pairs per model (e.g. `BucketAddView`/`BucketEditView`).
- `XSettingsView` for management screens pushed from the Settings tab (`BucketsSettingsView`, `BillsSettingsView`, `IncomeSourcesSettingsView`, `RecurringTransfersSettingsView`).
- `XRow` for list-row subviews reused across screens (`BucketSettingRow`, `RecurringTransferRow`).
- Data-entry `Picker`s use `.pickerStyle(.menu)` (a compact in-place dropdown) — reserve the default push-to-a-new-screen picker style for nothing; reserve `.pickerStyle(.segmented)` for view-mode switches that aren't form fields (e.g. the History range picker, the subscription sort picker).
- `SettingsView.swift` itself is intentionally a short top-level menu, not a place to inline CRUD lists — that's what the `*SettingsView` screens above are for.

## Versioning

`MARKETING_VERSION` in `Mooney.xcodeproj/project.pbxproj` follows `1.X.Y`.

- Every time changes are committed and pushed, bump the patch version (`Y`) by 1 as part of that same commit. Update it in both build configurations (Debug and Release) in `project.pbxproj`.
- Never touch the minor version (`X`) — the user bumps that manually when they judge it's warranted.
