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

Text styles (`TextSpec` + `.textStyle`, `DesignSystem/Typography`) reproduce
Flutter's line box as the app renders it: every line is
`round(size * height)` points (SkParagraph rounds each line), and the
leading over the faces' natural 1.2 x size is split evenly above and below
(Material's `Typography` sets `leadingDistribution: even`, which the
`AppTypography` styles inherit), so one line of `bodyMedium` (15 / 1.5) is
23pt and a breakdown row 35pt. The modifier also removes SwiftUI's
round-up of a Text's height to the pixel grid.

## Shell

Native `TabView` (Liquid Glass on iOS 26+, accent tint) with five tabs, each
in its own `NavigationStack`: Home (`dollarsign.circle`), Worth
(`chart.line.uptrend.xyaxis`), Goals (`flag`), Spend (`chart.pie`), Flow
(`chart.bar`). Tab roots hide the navigation bar and draw a `BudgieHeader`;
pushed pages keep the system bar and back gesture. Settings is pushed from
the gear in the Home header; Recurring is a row under Settings > Data; the
month's transaction list (Transactions) is pushed from Home's "SEE ALL".
Goals is `GoalsView` (see "Goals" below).

An `UnsavedChangesBanner` (danger strip, white content, "Some changes are
not saved to this device yet." + "Retry" calling `model.retrySaves()`) sits
above the tabs whenever `model.hasUnsavedChanges`; it never hides data.
`model.pendingAdd` (from quick actions, widget, deep links) opens the add
sheet preset to income or expense over the current tab, once the data is
ready, App Lock is passed and onboarding is done (`takePendingAdd()`); until
then it stays queued. As Flutter pushes the form on the root navigator, it
opens on top of whatever is presented (a Home sheet, an edit form or its
date picker, a Goals or Worth dialog, an alert) and leaves that untouched
underneath; a route arriving while a form is open stacks another. One
presenter, `AddFormPresenter`, handles every route: from the key window's
topmost presented controller it presents, unanimated, a transparent
`.overFullScreen` host whose SwiftUI root shows the form as a normal
`.sheet` and dismisses itself when the sheet goes. A route is taken only
when there is a controller to present from; while one is mid-transition it
stays queued and is retried every 150ms, so no route is lost or blocks the
next. The screens beneath are hidden from VoiceOver while the host is up.
Toasts float above the tab bar (`toastHost`), so a toast posted by a form
opened over a sheet is under that sheet.

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

## Worth (spec full-app/05; Flutter `net_worth_page.dart` `NetWorthPage`)

`Views/Worth/`. Totals, rows and history come from the Core net worth
queries on `model.data`; every mutation is an awaited `AppModel` call
(failure: the save-failed toast). Money through `model.moneyFormatter`
(Hide balances masks the hero, legend, row amounts, hover card and the
delta pill's amount; never percentages, share labels, the chart shape or
the editor's prefill).

- Empty (`!model.hasNetWorthEntries`): `BudgieHeader("Net worth")`, then 56
  below a card with a 56pt accent trend tile, "No net worth accounts yet",
  "Create your first asset or liability to start tracking net worth over
  time." and a filled 48pt "Add account" pill. The FAB shows too.
- Page order: header, month strip, hero (padding 24, 16, 24, 0), 24, growth
  card, 16, split card, 24, toggle, 16, accounts (horizontal padding 20),
  96 bottom clearance for the FAB.
- Month strip (D13): the shared `MonthStrip` over
  `model.netWorthAvailableMonths`, bound to `model.selectedNetWorthMonth`; a
  tap ticks and awaits `model.selectNetWorthMonth` (also for the selected
  chip, as Flutter).
- Hero: `NetWorthText.heroEyebrow`, then `RollingAmount` in heroMedium,
  leading, rolling `formatSigned(netWorth, 0 digits)` (rounded, base
  currency, D6) with a green (>= 0) / rose text glow at .35; VoiceOver
  "Net worth -$1,234.56". Delta pill (`NetWorthText.deltaPill`) when
  `netWorthChange(forMonth:)` is non-nil.
- Growth: `SegmentedPills` mono 6M / 1Y / ALL (`NetWorthGrowthRange`,
  default 1Y, page state) over `netWorthHistory(limit: 24)` oldest first;
  a Canvas plot drawn like fl_chart: `NetWorthChartScale.growth`, index x
  (`points`), grid at `gridLines`, 9pt glow + area gradient from the
  topmost spot + 3pt line through `CashFlowMath.trendControlPoints`
  (smoothness 0.28), end / selected dots; axis labels at
  `growthAxisLabelIndices`. A 150ms long press scrubs (`nearestSpot`, x
  only, 48pt) with a selection tick per spot and the hover card at
  `hoverAlignment`; lifting clears it. Same-length data changes animate
  150ms linear (none under Reduce Motion). VoiceOver: "Net worth growth",
  a summary value, swipe up / down steps through the points.
- Split card: `SplitGlowBar(splitFraction)` (flex via `splitFlex`) over the
  Assets / Liabilities legend (whole units).
- Toggle: Flutter's two chips (accent fill + glow when selected), page
  state, default Assets; the FAB adds on the active side.
- Accounts: `netWorthEntries(forMonth:type:)` rows in a `GlowListCard`
  (`NetWorthAccountIcon` symbol on a 44pt tile tinted by type, name,
  `NetWorthText.rowShare`, whole-unit amount, `rowChange` coloured by
  `changeIsFavorable`, 6pt share bar), or "No assets tracked for March
  2026." Tap: light haptic, opens the editor for the selected month.
  Context menu: Edit Balance (the same editor), View History (pushes
  `AccountHistoryView(entryID:)`), Delete Account ("Delete account?",
  `NetWorthText.deleteAccountMessage`, Cancel / Delete, plain role);
  VoiceOver activates Edit and offers View History and Delete Account as
  actions. No carry-forward control (Flutter has none;
  `carryNetWorthMonthForward` stays Core-only).
- Editor: `budgieDialog(padding: 0)` with the type glow; banner (type
  tile, "Add account" / "Edit account", `yMMMM` of the balance month,
  close), Asset / Liability pills, "Balance month" `DateTile` opening an
  inline month grid (1970 to this month), "Account name" and "Asset
  balance" / "Liability balance" `BudgieField`s (`NetWorthAmountInput`
  sanitize and prefill), Cancel and Add / Save. Save: "Name is required",
  "Enter a valid balance", then `addNetWorthEntry` / `updateNetWorthEntry`
  with the balance month, awaited before closing; scrim and buttons
  disabled while saving.
- Accessibility identifiers: `worth.add` (FAB), `worth.empty.add`,
  `worth.hero`, `worth.delta`, `worth.growth`, `worth.growth.range`,
  `worth.growth.chart`, `worth.split`, `worth.toggle.assets`,
  `worth.toggle.liabilities`, `worth.accounts.empty`,
  `worth.account.<name>` (rows), `worth.editor`, `worth.editor.asset`,
  `worth.editor.liability`, `worth.editor.month`, `worth.editor.close`,
  `worth.editor.cancel`, `worth.editor.save`; the fields are the text
  fields "Account name" and "Asset balance" / "Liability balance".

## Worth: account history (Flutter `_AccountHistoryPage`)

`AccountHistoryView(entryID:)`, pushed from a Worth row's View History
(system back, D2). Reads `model.netWorthEntry(id:)` and
`NetWorthAccountHistory` over `model.netWorthEntryHistory(id:)` on every
change, so it is live; every value is all-time, independent of the
selected month.

- Navigation bar: the account name (cardTitle, centred), a `pencil` edit
  button opening the Worth editor (`AccountEditorDialog`) for the account
  at `model.selectedNetWorthMonth`, and a danger trash button: "Delete
  account?" / `NetWorthText.deleteAccountMessage` / Cancel, Delete (plain
  role). The delete is awaited; a failed write shows `.saveFailed`; the
  page pops whenever the account is gone afterwards.
- Scroll content padding (20, 8, 20, 32) inside the safe area (clears the
  tab bar). Blocks: hero, 16, stat cards, 16, trend card, 24, timeline
  header, 12, timeline.
- Hero: GlowCard padding 24, gradient account colour 16% / 6% / card (stops
  0, .4, 1), border 18%, glow halo (24, .16). 48pt tile (`arrow.up.right`
  asset, `arrow.down.left` liability), 'Balance history' +
  `NetWorthText.lastUpdate`, 'Asset' / 'Liability' chip; 'CURRENT BALANCE';
  `formatSigned(latest)` in heroSmall shrunk to one line; chips
  (`snapshotCount`, "{+compact} vs prior" by sign, "{+compact} overall" by
  `totalChangeIsPositive`) wrapped with 8pt gaps.
- Stat cards: CURRENT / PEAK (account colour), LOW (text colour),
  `formatCompact`, '—' when there is no history; radius 22, padding 16.
- Trend card: empty 'No chart data yet for {name}.' (200pt). Otherwise
  'Trend' + `NetWorthText.trendRange` + latest compact chip, then the
  chart: 176pt plot + 24pt titles, `NetWorthChartScale.account` with index
  x (`points`; one snapshot drawn at 0 and 1), grid at `gridLines`, glow
  line 9pt 35%, area 35% to 0 from the highest spot, main line 3pt, round
  caps, fl_chart cubic (`CashFlowMath.trendControlPoints`,
  `curveSmoothness` 0.28) only when more than two snapshots, last dot
  #F2F2FA with a 3pt 50% ring. Titles: `accountAxisLabelIndices`, `trendAxisLabel`,
  monoAxis tertiary, centred on the spot 8pt below the plot. Touch: while a
  finger is down, the `nearestSpot` (x only, 48pt) gets fl_chart's default
  indicators and one tooltip (yMMMd over `formatSigned`, chip surface,
  radius 4, 16pt above the spot, clamped inside the plot); lifting clears it.
- Timeline: 'Timeline' + `NetWorthText.entryCount`; empty 'Add updates to
  this account to build a balance timeline.'; else one list card, newest
  first: glowing 12pt dot, yMMMd over jm, `formatSigned` over the compact
  delta from the next older update (green when good for the type), and a
  48pt trash button, disabled (tertiary) when only one update is left.
  Trash (or the row's VoiceOver Delete action) confirms "Delete balance
  update?" / `NetWorthText.deleteSnapshotMessage` / Cancel, Delete (plain
  role), then awaits `deleteNetWorthSnapshot`; a failed write shows
  `.saveFailed`. No haptics (as Flutter).
- Account gone while open: 'Account deleted' empty state, no edit or delete
  button.
- Money through `model.moneyFormatter` (Hide balances masks the hero,
  chips, stat cards, pill, tooltip, rows and the chart's VoiceOver value).
- UI-test identifiers: `worth.history` (scroll view), `worth.history.hero`,
  `worth.history.stat.current`, `worth.history.stat.peak`,
  `worth.history.stat.low`, `worth.history.chart`,
  `worth.history.chartEmpty`, `worth.history.timeline.count`,
  `worth.history.timeline.row`, `worth.history.timeline.delete`,
  `worth.history.timeline.empty`, `worth.history.edit`,
  `worth.history.deleteAccount`, `worth.history.missing`.

## Goals (spec full-app/03; Flutter `savings_goals_page.dart`)

`Views/Goals/`. Reads `model.savingsGoals` (incomplete first, then target
date, stable) and `model.savingsGoalsSummary`; copy from `SavingsGoalText`;
money through `model.moneyFormatter` (Hide balances masks amounts, the pace
line and the $25 / $100 chips, never percentages, statuses, dates or the
form's prefilled amounts).

- Header `BudgieHeader("Goals")`; the add button (`GlowFab`, "Add savings
  goal") floats bottom-trailing and opens the add form.
- Empty state: GlowCard (padding 28) with a 56pt accent `banknote` tile,
  "No savings goals yet", the body copy and a filled "Add goal" pill.
- Summary card: 72/8 accent `ProgressRing` with the overall percent, "SAVED
  SO FAR", the saved total (0 decimals) and "of {target} · {n} of {count}
  complete".
- Goal card: 84/9 ring in the status colour (accent On track, warning
  Behind, income Complete; percent, or a check when complete), name and
  status `PillChip`, "{saved} of {target}" or "{saved} saved", the pace line
  or "Fully funded on {MMMd} — nice work" in green, then a filled "Add money"
  pill and the 44pt ellipsis ("More goal actions"); a completed card has
  only the ellipsis, a green gradient and border, and long-presses (medium
  haptic) to its actions. Cards are keyed by goal id.
- Actions sheet (ellipsis): floating card with the name, "Edit goal" and
  "Delete goal"; the chosen dialog opens after the sheet closes.
- Dialogs (`budgieDialog`): the add / edit form (Goal name, Target amount,
  Saved so far when editing, Target date tile opening `DayPickerSheet` over
  Jan 1 of last year to Jan 1 of year + 20, stretched to the shown date;
  errors "Name is required", "Enter a target greater than 0", "Enter 0 or
  more" on submit), Add money (autofocused amount, chips that replace the
  text: $25.00, $100.00, "Finish goal" while something remains; "Enter an
  amount greater than 0"), and "Delete savings goal?". Amounts parse with
  `AmountInput`; an edit's untouched prefill, and the untouched "Finish
  goal" text, keep the exact stored / remaining value.
- Every mutation is awaited with its dialog open (scrim and buttons inert),
  then the dialog closes and toasts "Savings goal added / updated /
  deleted" or "Allocation added", or the save-failed toast when the write
  failed. An Add money that completes the goal (`willComplete` on the goal
  as shown) then plays the medium haptic, queues a "Goal complete, {name}"
  announcement and, unless Reduce Motion is on, the 1600 ms celebration
  (scrim, 18 dots, scaling card; no touches).
- UI-test identifiers: `goals.fab`, `goals.empty`, `goals.empty.add`,
  `goals.summary`, `goals.card` (one per goal; label "{name}, {status}"),
  `goals.card.addMoney`, `goals.card.more`, `goals.actions.edit`,
  `goals.actions.delete`, `goals.form.date`, `goals.form.cancel`,
  `goals.form.submit`, `goals.allocate.chip.25`, `goals.allocate.chip.100`,
  `goals.allocate.chip.finish`, `goals.allocate.cancel`,
  `goals.allocate.submit`, `goals.delete.cancel`, `goals.delete.confirm`,
  `goals.celebration`. Fields by label: "Goal name", "Target amount",
  "Saved so far", "Allocation amount".

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
