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

Native `TabView` (Liquid Glass on iOS 26+, accent tint) with five tabs, each
in its own `NavigationStack`: Home (`dollarsign.circle`), Worth
(`chart.line.uptrend.xyaxis`), Goals (`flag`), Spend (`chart.pie`), Flow
(`chart.bar`). Tab roots hide the navigation bar and draw a `BudgieHeader`;
pushed pages keep the system bar and back gesture. Settings is pushed from
the gear in the Home header; Recurring is a row under Settings > Data; the
month's transaction list (Transactions) is pushed from Home's "SEE ALL".
Goals and Flow show a placeholder until their Phase 2 streams land.

An `UnsavedChangesBanner` (danger strip, white content, "Some changes are
not saved to this device yet." + "Retry" calling `model.retrySaves()`) sits
above the tabs whenever `model.hasUnsavedChanges`; it never hides data.
`model.pendingAdd` (from quick actions, widget, deep links) opens the add
sheet preset to income or expense over the current tab, once the data is
ready, App Lock is passed and onboarding is done (`takePendingAdd()`); until
then it stays queued. Toasts float above the tab bar (`toastHost`).

## Home (spec full-app/02; Flutter `spending_page.dart`)

- Header: logo, month pill (`DartDateFormat.yMMMM(model.selectedMonth)`),
  Settings gear. The pill opens a panel with a year stepper (D13) and a
  five-row month drum always bound to `model.selectedMonth`.
- Hero: "CASH FLOW", `format(abs(income - expenses))` with a forward-rolling
  odometer (900 ms; none under Reduce Motion; plain "••••" when balances
  are hidden), "$X in · $Y out", SAVED / SHORT THIS MONTH / BREAKING EVEN.
- Spend gauge (spent / income), Income and Expenses chips with deltas vs
  the previous month (`HomeSummary`), the safe-to-spend card and its
  breakdown sheet (`SafeToSpend.calculate(... month:, asOf: model.now,
  wallClock: model.now ...)`).
- Budgets (`model.budgetOverview(forMonth:)`): rows by spent desc with
  status colours, EDIT and "Add a budget" pickers, and the limit sheet
  (`setBudgetLimit` / `removeBudgetLimit`, awaited before dismissing).
- Recent activity: the 3 newest rows across all months (`ledger.recent`),
  "SEE ALL" pushes Transactions.
- Expense / Income pills and the FAB open the form; a FAB long-press opens
  the quick-expense category sheet.

## Transaction form (sheet, D5)

Card-styled sheet. Fields: type toggle (Expense/Income), Amount (validated
on Add/Update: "Amount is required" / "Please enter a valid number" /
"Amount must be greater than 0"; Dart `double.tryParse` forms plus the
locale decimal separator; non-finite rejected), Description (trimmed;
empty saves "Transaction"), Category wheel, Tags (when any exist), Date
tile. Date semantics match the Flutter form: a new transaction's date is
`model.now` (with time) unless the user picks a day, stored as
`calendar.date(y, m, d)`; editing keeps the stored date unless a new one is
picked. Categorisation rules apply on every Amount/Description edit
(`model.suggestion`). Add/Update await the write; a failure shows the
Retry toast, an add outside the selected month shows "Added to <Month>".
Edit mode offers Delete (confirm). "Make this recurring" turns the sheet
into the recurring form.

## Transactions (SEE ALL; Flutter `transaction_page.dart`)

Month chip strip (months with data, newest first; page-local selection),
monthly summary card, rows of the selected month grouped under pinned
`yMMMd` day headers. Tap to edit (D7), swipe left to delete with a
"Delete Transaction" confirmation. Reads `model.ledger` only.

## Spend (spec full-app/04 section 1.1; Flutter `category_page.dart`)

`SpendView` (`Views/Spend/`), titled "Categories". Its month is local to the
tab (never `model.selectedMonth`): the newest month with any transaction,
re-resolved with `SpendMonth.resolve` on every ledger change; a month that
loses its last row falls back to the newest and clears the slice and the
expanded tail. `CategoryBreakdown.build` runs once per render from the
ledger's month summaries (no transaction scan).

- Header: `BudgieHeader` with a `MonthPill` (`MMMM`, hidden with no
  months). The pill opens `SpendMonthSheet`: card fill, 26pt top corners
  with the border along the top only, 40x4 grabber, "Select month", one
  56pt row per month with data (`yMMMM`, newest first, the list capped at
  320pt), the selected row accent with a check. Picking closes the sheet
  and clears the slice and tail. Haptics: light (pill), selection (open),
  selection (pick).
- Empty states: "No Expenses Yet" (no months) and "No Expenses" (the
  month's expense total is 0; the pill stays), `chart.pie`.
- Donut (`DonutChart`, 240pt, D16 `Canvas` from `DonutGeometry`): the
  accent glow is a filled blurred circle behind the ring, so it tints the
  band inside it and the gaps; the centre disc is the page background.
  The ring sweeps in over 500 ms (Flutter `easeOut`) on first appearance
  and on a month change only (the ring is keyed by month), instant under
  Reduce Motion. The whole square takes taps; `DonutGeometry.tap` selects,
  deselects or ignores, and the selection haptic plays only on a change.
  Centre: "SPENT", whole-unit total and the delta pill, or the selected
  slice's name, value and percent. VoiceOver: one adjustable element,
  "Spending by category", valued "Spent $X, up 12% vs August" or
  "<name>, <amount>, <percent>"; swipe up/down selects slices.
- List (`GlowListCard`): up to six ranked rows (tile in the rank colour
  with the active category's icon by exact name, else the grid; name;
  `Record.subtitle(money:)`; whole-unit amount; a 6pt bar against the
  largest category), the selected slice's row tinted (200 ms), then
  "N more categories" (expands in place) or "Show less". Row taps play a
  light impact; a category row pushes `CategoryTransactionsView`.
- Drill-in (`CategoryTransactionsView`): system back bar with the
  category as title, the tinted "TOTAL SPENT" card (two decimals, text
  glow, `MMMM yyyy` and count pills, 56pt tile), "TRANSACTIONS", then the
  month's expense rows of that exact category name, newest first. Rows tap
  to edit and swipe to delete (awaited, then "Transaction deleted" or the
  save-failed toast). Colour and icon follow the category's current rank;
  with no rows left it shows "No Transactions" under the card.
- State (month, slice, tail, pushed drill-in) survives tab switches.
- Accessibility identifiers: `spend.monthPill`, `spend.monthSheet`,
  `spend.month.<yyyy-MM>`, `spend.donut`, `spend.row.<rank>`,
  `spend.tail`, `spend.showLess`, `spend.empty`, `spend.drillIn.summary`,
  `spend.drillIn.row`.

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
