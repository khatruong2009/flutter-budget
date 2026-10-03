# AGENTS.md

Guidance for AI coding agents working in this repository. Read this before
making changes.

## What this repo is

A personal budget tracking app ("Budgie"), in two codebases:

- [`budget_app/`](budget_app) — the Flutter app that is on the App Store
  today (3.4.0). It is also the **reference implementation**: the native app
  and its parity harness are checked against it.
- [`native/`](native) — the SwiftUI replacement (4.0.0), a full rewrite with
  the same bundle ID, App Group and store file, so users upgrade in place and
  can go back to the Flutter build without losing data. See
  [Native app](#native-app-native) below.

Unless a task says otherwise, ask which app it is about. Work on the native
app must not modify `budget_app/` (its code is exported by the parity harness;
see `native/ParityHarness/README.md`).

All persistence is **local**. Financial data (transactions, net worth,
budgets, goals, recurring templates, categories, tags, rules, app settings)
lives in one checksummed JSON file with a last-known-good backup, managed by
[`AtomicFinancialStore`](budget_app/lib/storage/atomic_financial_store.dart)
in the app-support directory. `shared_preferences` is only used for real
preferences (theme, onboarding flag, small settings). There is no backend, no
auth, no network sync.

### Legacy / inactive directories — do not modify unless asked

- [`amplify/`](amplify) — AWS Amplify scaffolding. Not wired into the Flutter app.
- [`src/graphql/`](src/graphql), [`src/models/`](src/models) — generated AppSync
  artifacts from the abandoned Amplify experiment. Unused.

If a task touches these, confirm with the user first — the user is almost
certainly talking about `budget_app/`.

## Working directory

`cd budget_app` for every Flutter command. The `pubspec.yaml`, `analysis_options.yaml`,
and `test/` directory all live there.

## Commands

```bash
# from budget_app/
flutter pub get          # install deps
flutter analyze          # lint (uses flutter_lints)
flutter test             # run widget + unit tests
flutter run              # run on connected device / simulator
flutter run -d chrome    # run in browser
```

There is no separate type-check step — `flutter analyze` covers it.

There is no formatter config beyond Dart defaults (`dart format .`).

## Architecture at a glance

State management is **Provider + ChangeNotifier**. Three top-level providers are
wired in [`lib/main.dart`](budget_app/lib/main.dart):

| Provider | File | Responsibility |
|---|---|---|
| `TransactionModel` | [`lib/transaction_model.dart`](budget_app/lib/transaction_model.dart) | Transactions list, selected month, net worth entries/snapshots, CSV export |
| `RecurringTransactionModel` | [`lib/recurring_transaction_model.dart`](budget_app/lib/recurring_transaction_model.dart) | Recurring transaction templates (weekly/biweekly/monthly) |
| `ThemeProvider` | [`lib/theme_provider.dart`](budget_app/lib/theme_provider.dart) | Light/dark/system theme mode |

Each provider:
1. Holds its data in memory.
2. Loads its section from / saves it to `AtomicFinancialStore` (one section
   per feature inside a single versioned file).
3. Calls `notifyListeners()` after any mutation.

Mutations on `TransactionModel` and `RecurringTransactionModel` return
`Future<bool>`: memory updates first, then the write is awaited and verified by
reading the file back from disk. A `false` result means the change is still
only in memory; the model flags it (`hasUnsavedChanges`, via the
`PersistenceStatus` mixin), the home page shows a retry banner, and the app
retries when it goes to the background. Never fire-and-forget a save and
never treat a save as done before its future resolves.

If you add a field to a model, you **must** update `toJson` / `fromJson` and
handle the case where the key is missing (existing users have old data).

### Domain models

- `Transaction` ([`lib/transaction.dart`](budget_app/lib/transaction.dart)) —
  income or expense, optional `recurringTemplateId` linking to a recurring template.
- `RecurringTransaction` ([`lib/recurring_transaction.dart`](budget_app/lib/recurring_transaction.dart)) —
  template with a `RecurrencePattern` (weekly/biweekly/monthly), a `nextOccurrence`
  cursor, and an `isActive` flag.
- `NetWorthEntry` ([`lib/net_worth_entry.dart`](budget_app/lib/net_worth_entry.dart)) —
  asset or liability with month-keyed `NetWorthSnapshot`s. Read this carefully
  before touching net worth code; the snapshot/month-key logic is non-obvious.

### Recurring transaction generation

[`TransactionGenerator`](budget_app/lib/transaction_generator.dart) runs once on
app launch (see `_initializeApp` in `main.dart`). It walks every active
recurring template, generates concrete `Transaction` rows for each missed
occurrence up to today, and advances the template's `nextOccurrence`. There is
a **90-day lookback cap** so installing the app after a long gap doesn't flood
the ledger.

### UI structure

`MyApp` → `BudgetHomePage` ([`lib/home_page.dart`](budget_app/lib/home_page.dart))
hosts six tabs in a custom floating dock, each in its own nested `Navigator`:

1. Home — [`lib/spending_page.dart`](budget_app/lib/spending_page.dart)
2. Worth — [`lib/net_worth_page.dart`](budget_app/lib/net_worth_page.dart) *(2700+ lines — the biggest file in the app)*
3. Goals — [`lib/savings_goals_page.dart`](budget_app/lib/savings_goals_page.dart)
4. Spend — [`lib/category_page.dart`](budget_app/lib/category_page.dart)
5. Flow — [`lib/history_page.dart`](budget_app/lib/history_page.dart)
6. More — [`lib/settings_page.dart`](budget_app/lib/settings_page.dart) (Recurring is a pushed page here)

### Design system

Centralized in [`lib/design_system.dart`](budget_app/lib/design_system.dart) and
[`lib/theme/`](budget_app/lib/theme). Always use `AppDesign.spacingM`,
`AppColors.*`, `AppTypography.*` rather than hard-coding numbers/colors. Reusable
widgets live in [`lib/widgets/`](budget_app/lib/widgets) — check there before
building new components.

Categories (icons + labels) are defined in
[`lib/common.dart`](budget_app/lib/common.dart). Add new categories there.

### Native integrations

- **iOS Home Screen Widget** (`ios/BudgetWidgets/`) deep-links via the
  `budgetapp://` scheme to add-income / add-expense flows. Channel is
  `budget_app/deeplink` — see `_setupDeepLinks` in `main.dart`.
- **Quick Actions** (long-press app icon) — registered in `main.dart`
  via the `quick_actions` plugin. Icons live in
  `ios/Runner/Assets.xcassets`; see [`QUICK_ACTIONS_ICONS_GUIDE.md`](budget_app/QUICK_ACTIONS_ICONS_GUIDE.md).

If you change deep-link or quick-action behavior, test on a real device or
simulator — these paths are not covered by widget tests.

## Native app (`native/`)

SwiftUI, iOS 17+, Swift 6, `@Observable`, no third-party dependencies. The
Xcode project is generated: `cd native && xcodegen generate` after adding or
removing files (commit `project.pbxproj`).

| Path | What |
|---|---|
| `native/BudgieCore/` | Swift package: store (byte-compatible with Flutter's `AtomicFinancialStore`), migration, Dart-exact dates/strings/numbers, domain logic. `cd native/BudgieCore && swift test` |
| `native/Budgie/` | The app: `App/AppModel.swift` (single `@Observable` model; mutations `await persist(...)` and return the verified `Bool`), `Views/`, `DesignSystem/` (tokens, Gabarito / Spline Sans Mono, components) |
| `native/BudgetWidgets/` | Home screen widgets (same `kind`s as Flutter) |
| `native/BudgieUITests/`, `native/BudgieAppTests/` | XCUITests per tab, accessibility audit, app unit tests |
| `native/ParityHarness/`, `native/Fixtures/` | Dart tests that run the real Flutter code to produce fixtures, and verify Swift-written stores load in Flutter |
| `native/docs/` | `FULL_APP_PLAN.md` (decisions, cross-cutting rules), `MIGRATION_SPEC.md` (store format, migration), `UI_SPEC.md`, `PARITY_GAPS.md` (every difference from Flutter), `PERFORMANCE.md`, `REAL_DEVICE_CHECKLISTS.md`, `full-app/` per-area specs |

Shell: a native `TabView` with five tabs — **Home, Worth, Goals, Spend,
Flow** — each in its own `NavigationStack`. Settings (Flutter's More) is
pushed from a gear in the Home header; Recurring, Categories, Tags & rules,
backup and CSV import live under Settings. SEE ALL lists are pushed pages.

Rules that every native change follows (FULL_APP_PLAN.md section 3):
- Persistence: mutate memory, then `await persist([sections])`; patch stored
  records' raw JSON in place; keep Dart number lexemes (`100.0`).
- Dates only through `DartDateTime` / `DartCalendar` and the net-worth month
  helpers; the clock comes from `AppModel.now`.
- Compare strings as UTF-16 where Dart does (`DartString`); money through
  `model.moneyFormatter`.
- Every ported calculation has a Dart-oracle fixture; every mutation is
  checked by `native/scripts/verify-swift-output-in-dart.sh <dir>` (New York,
  Santiago, Beirut). Any difference from Flutter goes in `PARITY_GAPS.md`.
- Every animation has a Reduce Motion path; VoiceOver labels; Dynamic Type
  through the design system's text styles.

Before calling native work done:

```bash
cd native/BudgieCore && swift test
cd native && xcodegen generate   # then build for a simulator with zero warnings
native/scripts/verify-swift-output-in-dart.sh /tmp/budgie-swift-out
```

plus the UI tests for what changed (`native/scripts/ui_flow.sh`, and
`native/scripts/system_flow.sh <Flutter Runner.app>` when quick actions,
deep links, the widget or the scene delegate change).

## Conventions

- **Single quotes** for strings (Dart default).
- **No new top-level abstractions** unless the task needs them. The codebase
  is pragmatic, not layered.
- **Persistence**: financial data goes into a `FinancialSections` entry of
  `AtomicFinancialStore`, never into `shared_preferences` (iOS backs that with
  `NSUserDefaults`, which caps the domain at ~4 MB, gives no durability
  guarantee, and reads back empty during a prewarmed launch). Only genuine
  preferences get a `StorageKeys` entry. Any new field needs a graceful
  fallback when loading (the user has existing data).
- **`debugPrint` over `print`** for diagnostics.
- **Money is `double`** throughout. Don't introduce `Decimal` partway — either
  migrate everything or stick with `double`.
- **Dates**: months are typically normalized to `DateTime(year, month)` (day=1).
  Net-worth code uses helper functions in `net_worth_entry.dart`
  (`netWorthMonthKey`, `endOfNetWorthMonth`, etc.) — use them, don't reinvent.

## Testing

Tests live in [`budget_app/test/`](budget_app/test). They are mostly widget
tests (golden-ish UI checks) plus model unit tests. When adding logic to a
model, add a unit test next to the existing ones (e.g.
`transaction_model_net_worth_test.dart`).

Run before claiming a task is done:

```bash
cd budget_app && flutter analyze && flutter test
```

## Things to avoid

- Don't edit the `*.backup` files (e.g. `history_page.dart.backup`).
- Don't run `flutter pub upgrade --major-versions` casually — `pubspec.yaml`
  pins some versions and uses a `dependency_overrides` for `path_provider_foundation`.
- Don't delete `amplify/` or `src/` without explicit user approval, even though
  they're inactive.
- Don't add new state management libraries (riverpod, bloc, etc.). Stick with Provider.
- Don't introduce a backend / network layer without an explicit ask. This app
  is offline-first by design.
  - One deliberate exception, in the native SwiftUI app (`native/`): voice entry
    sends the recording and its transcript to OpenAI (plan D11,
    `native/docs/FULL_APP_PLAN.md` section 6). The key comes from the gitignored
    `native/Config/Secrets.xcconfig`, never `.env` or committed files.
