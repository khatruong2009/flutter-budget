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
Goals shows a placeholder until its Phase 2 stream lands.

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
## Flow (spec full-app/04; Flutter `history_page.dart` `HistoryPage`)

`Views/Flow/`. Every figure comes from `model.ledger` through
`CashFlowMath` (no transaction scans); money through `model.moneyFormatter`
(Hide balances masks amounts and badges, never percentages or shapes).

- Header: `BudgieHeader("Cash flow")` with a `MonthPill` showing the chart
  range (`CashFlowMath.rangeLabel`, default 6 months; page `@State`, not
  persisted). Tap: light haptic, range sheet ("CHART RANGE", rows 3 / 6 /
  12 months, selected accent/bold with a check; a pick gives a selection
  haptic and closes). The range drives only the bars and the metric strip;
  the month is `model.selectedMonth` (read-only here).
- Page order (horizontal padding 20): header, 24, metric strip, 16,
  `FlowInsightsSlot` (empty until the Insights stream; so 32pt when empty),
  16, net cash flow, 16, year over year, 16, 12-month trend, 16,
  "Transactions" / "SEE ALL", 12, preview.
- Metric strip: equal-height chips (radius 22, padding 16): AVG SAVED / MO
  (`avgSavedText`) and SAVINGS RATE (`savingsRateText`), income colour when
  >= 0, danger otherwise; values wrap, no scaling.
- Net cash flow: custom layout (D16) from `CashFlowMath.barLayout` for the
  card's inner width: 190pt band, baseline at 116 (primary @12%), columns of
  `barWidth` spaced like `spaceAround`, bars radius 10; the selected month
  saturated with a glow (blur 20, .6) and its `badgeText` capsule 30pt above
  the bar; `MMM` labels in the bottom band. A column (the whole 190pt) tap:
  light haptic, month detail sheet (`CashFlowMath.MonthDetail`: bar-chart
  tile, `yMMMM`, Income / Expenses tiles, net row). Empty window: "No cash
  flow data yet." No bar animation (Flutter has none).
- Year over year: `CashFlowMath.yearOverYear` rows (Income, Expenses) with
  delta labels and two 12pt `GlowProgressBar`s each (800ms fill, instant
  under Reduce Motion), legend "This year" / "Last year".
- 12-month trend: `TrendLine`, a custom `Path` through
  `CashFlowMath.trendPoints` with `trendControlPoints` (fl_chart's exact
  cubic), 9pt accent @40% underlay, 3pt accent line, dashed zero line on top
  (fl_chart `extraLinesOnTop`), a 5pt #F2F2FA dot on the last point
  overhanging the plot edge; no fill, grid or axes. A data change animates
  150ms linear (none under Reduce Motion). Self-contained so it can become
  Swift Charts.
- Preview: `ledger.recent(3)` rows (category icon on an income or accent
  tile, description, "category · MMM d", signed amount); a row or the empty
  card ("No transactions recorded yet.") pushes `FlowTransactionsView`, as
  does "SEE ALL".
- VoiceOver: each bar is a button "September 2026, net +$3,158" (selected
  trait on the current month); chips read "Average saved per month" /
  "Savings rate" with the value; YoY rows read the delta; the trend reads
  "12-month net trend, From <month>, <net>, to <month>, <net>".
- Accessibility identifiers: `flow.rangePill`, `flow.range.3|6|12`,
  `flow.metric.avgSaved`, `flow.metric.savingsRate`, `flow.netCashFlow`,
  `flow.bar.<yyyy-MM>`, `flow.yoy`, `flow.trend`, `flow.preview.row`,
  `flow.preview.empty`; SEE ALL is the button "See all transactions".
## Flow: all transactions (Flow "SEE ALL"; Flutter `_TransactionsDetailPage`)

`FlowTransactionsView`, pushed from Flow (system back). Every transaction,
newest first, filtered by `TransactionFilter` (all conditions ANDed).

- Navigation bar: 'Transactions' (sectionHeader) beside the back button
  and, when any month has data, the month pill (`MMMM` of
  `model.selectedMonth`) trailing; the list scrolls under the bar. The pill
  opens 'SELECT MONTH' (`yMMMM` rows of `ledger.availableMonths`, list
  capped at 320pt). A pick calls `model.selectMonth` and
  `filter.limit(toMonth:calendar:)` (From/To = the month's first and last
  day, D6 fix). While `filter.isLimited(toMonth:calendar:)` is false the
  pill is dimmed and no month is ticked.
- Filters card: 'Filters' + 'RESET' (only while `filter.isActive`; clears
  every filter and the amount text). Search field (description only, D8;
  hint 'Search descriptions'; a minus button clears it while the trimmed
  query is non-empty). Type pills 'All' / 'Income' / 'Expense' (compact,
  left-aligned). Category button ('All categories' or the name) opening
  'SELECT CATEGORY' ('All categories' + `ledger.categoryNames`). Tag chips
  ('All tags' + `model.tags` in provider order; tapping the selected tag
  clears it) when tags exist. From / To buttons ('Any date' or `MMM d`)
  opening the day picker (2000-01-01 to Dec 31 of now.year + 10; the other
  bound moves when crossed). Min / Max amount fields (decimal pad, floating
  label, base-currency prefix while floated; parsed by `AmountInput.parse`
  with the money format's separators, 0 and up, D6).
- Results: 'Results' + "{matches} of {all}", pills 'Income ...', 'Expenses
  ...', 'Net ...' over every match, then one list card of rows (tile,
  description, "{category} · {MMM d}", signed amount). 50 rows at first;
  while more match, "Showing N of M matches" and 'Load more transactions'
  (+50). The count resets to 50 only when the filter signature changes.
  Empty: 'No transactions match these filters.' / 'No transactions have
  been recorded yet.'
- Rows (D7): tap opens the edit form; swipe left (or the VoiceOver Delete
  action) confirms "Delete Transaction" and awaits `deleteTransaction`.
- Rows are keyed by transaction id and built lazily (`LazyVStack`); each
  row's card slice takes no touches. The filtered rows and summary are
  cached per filter + `ledgerRevision`. Money goes through
  `model.moneyFormatter` (Hide balances masks rows and pills).
- UI-test identifiers: `flow.all.month`, `flow.all.search`,
  `flow.all.type`, `flow.all.category`, `flow.all.from`, `flow.all.to`,
  `flow.all.min`, `flow.all.max`, `flow.all.reset`, `flow.all.count`,
  `flow.all.empty`, `flow.all.row`, `flow.all.showing`,
  `flow.all.loadMore`, `flow.all.option` (sheet rows).

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
