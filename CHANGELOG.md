# Changelog

All notable changes to CatatUang are documented here.

## [1.1.0+2]

### Fixed
- Transfer handling: explicit `transferGroupId`, paired delete, and no more
  accidental edit/duplicate of transfer legs.
- Category rename no longer rewrites transactions of the wrong type and now
  propagates to recurring templates.
- Stats: correct weekday labels, budget ratio uses the current month and the
  true (unclamped) percentage, and period comparisons use equal elapsed spans.
- Startup no longer hangs when auth/onboarding state reads fail.
- Restore now reports key mismatch/corrupt backup instead of crashing.
- Biometric lock and sensitive actions fail closed when biometrics are
  unavailable; PIN-only protection actually locks the app.

### Added
- Debts & receivables module with installment payments.
- Payoff strategy planner (snowball / avalanche) with interest input.
- CSV statement import with offline auto-categorization.
- Split transaction (multi-category) editor.
- Recurring transfer templates.
- Cashflow forecast card (safe-to-spend) on Home.
- Net worth & monthly cash flow report.
- Delete all data flow (type-to-confirm + PIN/biometric verification).
- Optional crash reporting via Sentry (`--dart-define=SENTRY_DSN=...`).
- Release signing via `android/key.properties` (falls back to debug signing).
- Localization for financial strings, plus unit/widget tests.

### Changed
- Reactive Isar streams replace manual store refreshes.
- Receipts are persisted into app documents instead of temporary paths.
- Transactions store the currency used at record time.
- **Database engine migrated from Isar to SQLite + SQLCipher**
  (`sqflite_sqlcipher`). The local database is now encrypted at rest with a
  32-byte key stored in secure storage. The public `DatabaseService` API is
  unchanged, so stores and screens are unaffected.
- Removed the unmaintained `isar` dependency and the local
  `isar_flutter_libs` plugin override; `.local_plugins/` deleted.
- Release version bumped to 1.1.0+2.

### Migration notes
- The database file changed from `catatuang_db.isar` to `catatuang.db` and is
  now encrypted. Data from pre-1.1 development builds is not read
  automatically. Before updating such a build, export a backup and restore it
  after upgrading. Production users are not affected (no prior release).
- New database tests cover CRUD, transfers, splits, aggregation, reactive
  streams, debt payments, and backup round-trip.

## [1.0.0+1]
- Initial release.
