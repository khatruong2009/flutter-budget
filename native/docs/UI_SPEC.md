# MVP UI spec (Phase 4)

Views are thin: they read `AppModel` (`@Environment(AppModel.self)`) and call
its async methods. They never touch `FinancialStore`, JSON, preferences or
files. Money is shown with `model.moneyFormatter` (a port of the Flutter
formatter: same symbols, rounding and "Match device" = en_US), dates with
`DartDateTime` fields (never `Date` arithmetic for stored values).

Visual language: native SwiftUI (List/Form, NavigationStack, sheets) with the
Flutter app's accent palette so it feels like the same product, not a
pixel copy. Tokens live in `Budgie/Views/Theme.swift`:

| Token | Light | Dark |
|---|---|---|
| accent | `#6366F1` | `#818CF8` |
| income | `#10B981` | `#34D399` |
| expense / danger | `#EF4444` | `#FB7185` |
| warning | `#F59E0B` | `#FBBF24` |
| background | `#F9FAFB` | `#0A0A12` |
| card | `#FFFFFF` | `#13131F` |

Monospaced digits (`.monospacedDigit()`) for amounts. Respect Dynamic Type
and VoiceOver labels on every control. No third-party packages.

## Shell

`TabView` with five tabs (SF Symbols): Spending (`dollarsign.circle`),
History (`list.bullet.rectangle`), Net Worth (`chart.line.uptrend.xyaxis`),
Recurring (`arrow.triangle.2.circlepath`), Settings (`gearshape`). An
`UnsavedChangesBanner` sits above the tabs whenever
`model.hasUnsavedChanges` (text: "Some changes aren't saved yet." + "Retry"
calling `model.retrySaves()`); it never hides data. `model.pendingAdd`
(from quick actions, widget, deep links) opens the add sheet preset to
income or expense on the Spending tab and is then cleared.

## Spending

- Month selector: previous/next chevrons around "September 2026"; menu of
  `data.availableMonths()` plus the current month. Starts at the current
  month (not persisted, like Flutter).
- Totals for the month (`data.totals(forMonth:)`): income, expenses, net
  (net coloured income/danger; label "Saved this month" / "Short this month"
  / "Breaking even").
- Safe-to-spend card: `SafeToSpend.calculate(... month:, asOf: model.now,
  wallClock: model.now ...)`; title "Safe to spend" or "Projected shortfall";
  subtitle "$X/day for N days left" | "This month is already closed out" |
  "Add income or reduce planned spending"; tap opens a breakdown sheet with
  the six rows of the Flutter sheet.
- Expenses by category for the month (`totals.categoryExpenses`, sorted by
  amount desc), with icon.
- The month's transactions (newest first), tap to edit, swipe to delete
  (confirm).
- Toolbar "+" menu: Add Expense / Add Income.

## Transaction form (sheet)

Fields: type (segmented Expense/Income), amount (decimal keyboard; valid iff
parsed > 0 and finite; accepts the locale's decimal separator), description
(optional; empty is saved as "Transaction", as the Flutter form does),
category (picker from `model.categories(for:)`), date (DatePicker, not after
today). Date semantics match the Flutter form: a new transaction's date is
`model.now` (with time) unless the user picks a date, which is stored as that
day at midnight (`calendar.date(y, m, d)`); editing keeps the stored date
unless a new one is picked. Save calls `addTransaction` /
`updateTransaction`. Edit mode shows Delete (confirm). Disable Save while invalid or
while saving.

## History

All transactions newest first (`data.transactionsNewestFirst()`), grouped
by calendar day with a day header ("Mon, Sep 28, 2026") and a day net;
search field filtering description/category; tap to edit, swipe to delete.
Lazy (10k rows must scroll smoothly).

## Net Worth (read-only in the MVP)

- Month menu from `data.netWorthAvailableMonths(now:)`, default
  `data.selectedNetWorthMonth` (view state only; not persisted in the MVP).
- Header: net worth, assets, liabilities for the month; change vs previous
  month (`netWorthChange(forMonth:)`) when non-nil.
- Swift Charts `LineMark` over `data.netWorthHistory(limit: 24)` reversed to
  chronological order, x = point date, y = netWorth; `PointMark` for each.
- Two sections, Assets and Liabilities: `netWorthEntries(forMonth:type:)`
  with amount for the month; a "carried from <Month>" note when the entry's
  latest snapshot is from an earlier month.
- Empty state: "No accounts yet" with a note that accounts are managed in
  the previous app version for now.

## Recurring

List of `data.templates` (active first, then paused), each showing
description, amount, pattern ("Weekly", "Every 2 weeks", "Monthly on the
31st"), next date (`nextOccurrence`), and a Paused badge. Swipe actions:
Pause/Resume (`setTemplateActive`), Delete (confirm). "+" opens the template
form: type, description, amount, category, frequency (weekly / biweekly /
monthly), start date, day of month (1-31, monthly only; default the start
date's day). `dayOfWeek` = start date's Dart weekday (Mon=1..Sun=7) for
weekly/biweekly, nil for monthly. Edit uses `updateTemplate`.

## Settings

- Appearance: System / Light / Dark (`setThemeMode`).
- Currency: the 11 codes the Flutter app offers
  (USD CAD EUR GBP AUD JPY CNY INR KRW MXN BRL) (`setBaseCurrency`).
- Face ID lock toggle (`setAppLockEnabled`), shown with the device's
  biometry name; enabling requires a successful authentication first.
- Export CSV: `ShareLink` of `model.exportCSV()` ("Export transactions").
- About: version, "Data diagnostics" (the existing `DiagnosticsView`).

## App lock

When `appSettings.appLockEnabled`: an opaque privacy cover whenever the
scene is inactive/background; on returning after
`autoLockTimeoutSeconds` (0 = immediately), or at launch, require
`LAContext.evaluatePolicy(.deviceOwnerAuthentication)` before showing data.
The lock never blocks the bootstrap or saves.
