# Mooney

A personal budgeting app for iPhone, built in SwiftUI around savings **buckets**. Every dollar you save belongs to a bucket, and the app tracks your bills, subscriptions, credit cards, paychecks and recurring transfers. It can also show your live bank balance through a small Plaid backend you host yourself.

## Features

- **Buckets**: split savings into goals with custom icons and colors. A General bucket catches anything not yet assigned, and you can move money between buckets.
- **Income**: income sources, pay schedules and payday notifications.
- **Bills and subscriptions**: track what's due and what's unpaid, sorted however you like.
- **Credit cards**: due dates and logged payments.
- **Recurring transfers**: automatic, scheduled moves between buckets.
- **Ledger and History**: every income and transaction in one feed, plus savings-over-time charts.
- **Calendar**: paydays, subscriptions and card due dates for the month.
- **Live bank balance (optional)**: through Plaid, via the self-hosted backend in `Backend/`.
- **Home Screen widget**: checking and savings balances at a glance.
- **Privacy**: Face ID / PIN lock with a *decoy PIN* that opens a separate, believable set of fake data. PINs live in the Keychain.
- **Backups**: export and import your data as a JSON document.
- **Theming**: light/dark design system with a custom color picker.

## Repository layout

| Path | What's in it |
|---|---|
| `Mooney/Models/` | Data types: buckets, bills, incomes, cards, app lock, backups, etc. |
| `Mooney/Store/` | `AppStore` (all state and mutations), Plaid client, seed and decoy data |
| `Mooney/Views/` | All screens, plus the shared `DesignSystem.swift` |
| `MooneyWidget/` | WidgetKit extension |
| `Backend/` | Node/Express Plaid service (the only place Plaid secrets live) |

All app data is one `AppState` struct saved as JSON in `UserDefaults`. There's no Core Data or SwiftData. See [CLAUDE.md](CLAUDE.md) for the architecture in detail.

## Running the app

Targets iOS 17+.

```bash
open Mooney.xcodeproj
```

Select the **Mooney** scheme and run on a simulator or device. The app works fully offline; the bank connection is optional.

## Plaid backend (optional)

A single-user service that keeps the Plaid secret and access token on the server so the app never holds them.

```bash
cd Backend
npm install
cp .env.example .env    # PLAID_CLIENT_ID, PLAID_SECRET, PLAID_ENV, PLAID_REDIRECT_URI, TOKEN_ENCRYPTION_KEY
npm start               # listens on :4001
```

Endpoints: `POST /link_token`, `POST /exchange_public_token`, `GET /balance`, `POST /disconnect`.

To deploy on a home NAS: `docker compose up -d`. **Expose it only over Tailscale. Don't port-forward it.** Then enter the backend URL in the app under Settings → Bank Connection.

The OAuth redirect for banks that need it is served from [nickpearson.me](https://github.com/nickp3057/nickpearson-site) (`/plaid-oauth`), which hosts the app's `apple-app-site-association` file.

## Versioning

`MARKETING_VERSION` follows `X.Y.Z`. Every commit bumps exactly one part: Z for small fixes, Y for real features, X only for major releases.
