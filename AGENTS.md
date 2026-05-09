# AGENTS.md

Guidance for AI coding agents working in this repository. Read this before
making changes.

## What this repo is

A personal budget tracking app. The **only active code** lives in
[`budget_app/`](budget_app) — a Flutter mobile app (iOS-first, also builds for
Android/macOS/web/Linux/Windows).

All persistence is **local** via `shared_preferences` (JSON-encoded). There is
no backend, no auth, no network sync.

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
2. Loads from / saves to `SharedPreferences` (JSON).
3. Calls `notifyListeners()` after any mutation.

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
hosts a `PageView` with five tabs, each in its own nested `Navigator`:

1. Spending — [`lib/spending_page.dart`](budget_app/lib/spending_page.dart)
2. Net Worth — [`lib/net_worth_page.dart`](budget_app/lib/net_worth_page.dart) *(2700+ lines — the biggest file in the app)*
3. Categories — [`lib/category_page.dart`](budget_app/lib/category_page.dart)
4. History — [`lib/history_page.dart`](budget_app/lib/history_page.dart)
5. Settings — [`lib/settings_page.dart`](budget_app/lib/settings_page.dart)

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

## Conventions

- **Single quotes** for strings (Dart default).
- **No new top-level abstractions** unless the task needs them. The codebase
  is pragmatic, not layered.
- **Persistence**: any new persisted field needs a `SharedPreferences` key
  defined as a `static const String` on its model and a graceful fallback when
  loading (the user has existing data).
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
