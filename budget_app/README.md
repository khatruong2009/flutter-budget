# budget_app

A personal budget tracking app built with Flutter. iOS-first, also builds for
Android, macOS, web, and Linux/Windows.

All data is stored **locally** via `shared_preferences` — no backend, no
account, no network sync.

## Features

- Track income and expenses by category, with month-level views.
- Recurring transactions (weekly, biweekly, monthly) auto-generated on launch
  with a 90-day lookback cap.
- Net worth tracking with month-keyed asset/liability snapshots and history charts.
- CSV export of all transactions.
- iOS Home Screen widget for quick add (small "Budget Quick Add").
- App icon Quick Actions for "Add Income" / "Add Expense" (long-press app icon).
- Light, dark, and system theme modes.

## Requirements

- Flutter SDK >= 3.0.5 (see `pubspec.yaml` `environment.sdk`).
- For iOS builds: Xcode + CocoaPods.
- For Android builds: Android SDK with `min_sdk_android: 21`.

## Quick start

```bash
cd budget_app
flutter pub get
flutter run                # picks first connected device
flutter run -d chrome      # web
```

Common tasks via Makefile (from `budget_app/`):

```bash
make setup     # flutter pub get
make analyze   # flutter analyze
make test      # flutter test
make check     # analyze + test (what CI runs)
make format    # dart format .
make clean     # flutter clean
```

## iOS Home Screen Widget

- Build/run the iOS app once so the WidgetKit extension registers.
- Add the small "Budget Quick Add" widget from the iOS widget gallery.
- Top button → Add Income modal. Bottom button → Add Expense modal.
- Deep-link scheme: `budgetapp://add-income`, `budgetapp://add-expense`.

## Project layout

```
lib/
  main.dart                       # entry, Provider wiring, deep links, quick actions
  home_page.dart                  # bottom-nav shell with 5 tabs
  transaction.dart                # Transaction model
  transaction_model.dart          # state + persistence for transactions + net worth
  recurring_transaction*.dart     # recurring template model, form, list page
  transaction_generator.dart      # runs on launch — generates due recurring txns
  net_worth_entry.dart            # NetWorthEntry/Snapshot model + date helpers
  net_worth_page.dart             # net worth tab (large file)
  spending / category / history / settings / insights pages
  design_system.dart              # design tokens + ElevatedCard / AppButton / AnimatedMetricCard
  theme/                          # AppColors, AppTypography, AppAnimations
  widgets/                        # reusable UI components
  utils/                          # accessibility, platform, micro-interactions
  storage/                        # SharedPreferences key registry
```

See [`AGENTS.md`](../AGENTS.md) at the repo root for guidance on architecture
and conventions when making changes.

## Architecture

State is managed with **Provider + ChangeNotifier**. Three providers, wired at
the top of `lib/main.dart`:

| Provider | Owns |
|---|---|
| `TransactionModel` | transactions, selected month, net worth entries, CSV export |
| `RecurringTransactionModel` | recurring templates (weekly/biweekly/monthly) |
| `ThemeProvider` | light/dark/system theme |

Each provider persists to `SharedPreferences` as JSON. Storage keys are
centralised in [`lib/storage/storage_keys.dart`](lib/storage/storage_keys.dart).

On launch, `TransactionGenerator.generateDueTransactions()` walks active
recurring templates and materialises any missed occurrences (capped at 90 days
back) before the home page mounts.

## Testing

Tests live in [`test/`](test). Mostly widget tests plus model unit tests.

```bash
flutter test                                  # run all
flutter test test/transaction_model_net_worth_test.dart   # one file
flutter test --update-goldens                  # regenerate golden snapshots
```
