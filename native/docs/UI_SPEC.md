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

Pages are pushed with a `NavigationLink` or `navigationDestination(item:)`,
never `navigationDestination(isPresented:)`. With `isPresented` the stack
re-installs the pushed page (a fresh root view in its hosting controller)
whenever the tab root's preferences are re-derived, and an accessibility
client re-derives them on every read of the screen. Each re-install
updates the navigation bar, which the client reads again, so under
XCUITest the first SEE ALL push re-rendered its page about 200 times a
second for up to a minute (budgie-uia.55).

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
  `FlowInsightsSlot` (the Insights section below; nothing and so 32pt when
  there are no cards), 16, net cash flow, 16, year over year, 16, 12-month trend, 16,
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

### Flow: Insights (Flutter `LocalInsightsSection`, local_insights_section.dart)

`FlowInsightsSlot` (FlowView.swift) and `InsightCard` (InsightCard.swift);
cards from `model.insights` (BudgieCore `InsightEngine`, limit 3).

- Section (padding 20): `SectionHeader("Insights")`, 12, the cards 10
  apart, 8, "Calculated privately on this device · Not financial advice"
  (caption, text tertiary, no inset). No cards: the slot takes no space.
- Card: plain `GlowCard` (no tap): 40pt `IconTile` in the severity colour
  (urgent danger, warning warning, positive income, info accent), 12, a
  column of headline (rowTitle, primary), 4, explanation (rowSubtitle,
  secondary), 8, suggested action (caption, severity colour), all wrapping
  without limits; trailing `Menu` with a bold 24pt `ellipsis` in a 48pt box
  (Flutter's 48pt IconButton, top-aligned), items "Snooze for 30 days" and
  "Dismiss" (fixed order, no icons, no destructive role). Icons (D3):
  pace `speedometer`, monthly change `chart.line.uptrend.xyaxis`, unusual
  `bell.badge.fill` (Material `notification_important`, a bell), savings
  rate `banknote`, recurring `repeat`, under budget `hand.thumbsup.fill`,
  goal `flag.fill`, negative flow `chart.line.downtrend.xyaxis`, duplicate
  `doc.on.doc`.
- A menu pick acts at once: no confirmation, no undo, no haptic, no
  animation (Flutter has none, so Reduce Motion changes nothing). Every
  card with that id goes (ids can repeat; cards are keyed by position) and
  the next candidate fills in when the recomputation lands.
- Data: `AppModel` recomputes `insights` off the main thread (a generation
  counter drops stale results) on every `data` change, month change,
  dismiss and snooze, and when Flow appears or the scene becomes active
  (the clock ends snoozes and moves budget pace). The first cards are
  computed in the bootstrap before `.ready`. The dismissed/snoozed ids are
  the two `flutter.local_insights_*` preferences, loaded after the
  protected-data wait and written synchronously like the theme mode (never
  the store, the retry banner or the backup). Money formatting, Hide
  balances, currency and locale do not apply (the copy has no amounts).
- VoiceOver: the tile and the three texts are one element with the actions
  "Snooze for 30 days" and "Dismiss"; the menu is a separate button
  "Insight options" (value: the headline); the header has the header trait.
  Dynamic Type through `TextSpec`.
- Accessibility identifiers: `flow.insights` (section), `flow.insight.card`
  and `flow.insight.menu` (each card), `flow.insight.snooze`,
  `flow.insight.dismiss`.
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

## Categories (spec full-app/06 section 1.5; Flutter `category_settings_page.dart`)

`Views/Settings/CategoriesView.swift`, pushed from Settings >
PERSONALIZATION > Categories (system back; "Categories" in cardTitle in
the bar, a "+" "Add category" button trailing, no FAB). Reads
`model.categoryDefinitions(type:includeArchived:)` (Dart `categoriesFor`);
every mutation is an awaited `AppModel` call returning `CategoryOutcome`.

- Top: the centred `SegmentedPills` "Expenses" | "Income" (padding 16, 8,
  16, 0), then "Show archived" (M3 bodyLarge 16 / 1.5, systemGreen switch,
  padding 24 leading and 32 trailing so the track ends where
  CupertinoSwitch's does, 56 tall; the title also toggles it). Neither is
  persisted.
- List (padding 16, 0, 16, 32; 8 apart, lazy): one `GlowCard(padding: 8)`
  per definition in sort order, archived rows interleaved only while the
  switch is on. A new list per type (`.id(typeIndex)`), so switching type
  starts at the top. Row: 72 tall, content padding 16 / 24, 16 gaps, the
  40pt `IconTile` with its symbol at `Metrics.categoryGlyph` (17), the name
  (rowTitle, tracking 0.5) over "Built in" / "Archived" joined with " · "
  (rowSubtitle, tracking 0.25; 4 apart; an empty subtitle keeps its line),
  and the 48pt `ellipsis` (17, bold) system `Menu` "Category actions". No row
  tap.
- Menu (`CategoryRowAction.menu`): Edit; Move up unless archived or first
  shown; Move down unless archived or last shown; Restore (archived) or
  Archive. Moves pass `model.categoryMoveOffset` (relative to the rows
  shown). Saved and no-op outcomes are silent; `.failed` shows
  `Toast.saveFailed`; `.rejected` shows `error.message` in the neutral
  toast (`CategoryRowAction.refusedToast`: "At least one category must
  remain active").
- Editor (`CategoryEditorDialog`, `budgieDialog(item:)` centred card):
  "New category" / "Edit category" (goalTitle), the autofocused
  `BudgieField` "Name" (words, Done return key that dismisses the
  keyboard), "Icon" and "Color" captions over `FlowLayout`s (8 / 8,
  capped at five buttons a row: 5 x 44 + 4 x 8) of 44pt choice buttons
  (radius 12; selected accent 18% + accent border, else surface + border):
  the 18 `CategoryCatalog.iconIdentifiers` symbols in textPrimary (17,
  regular), then the 8 `colorTokens` as 20pt circles; Cancel / Add | Save
  pills (44). A new
  category's type is the selected segment. Save validates inline:
  "Enter a category name" (empty after trim), else
  `validateCategoryName`'s message; after the first Save the error follows
  the text. The edit is then awaited with the dialog inert
  (`budgieDialogDismissDisabled`); it closes on `.saved` / `.unchanged`,
  and on `.failed` with the save-failed toast; `.rejected` shows inline.
  A rename's cascade is one commit and rebuilds the ledger, so every screen
  shows the new name.
- VoiceOver: each row's text is one element (name, value = subtitle) with
  the menu items as custom actions, followed by the "Category actions"
  menu, valued with the category's name; choice buttons are named ("Cart", "Green", ...) with the selected
  trait; the "Icon" / "Color" captions are headers.
- UI-test identifiers: `settings.categories`, `categories.add`,
  `categories.type`, `categories.showArchived`, `categories.list`,
  `categories.row.<id>`, `categories.row.menu.<id>`,
  `categories.editor.name`, `categories.editor.icon.<identifier>`,
  `categories.editor.color.<token>`, `categories.editor.submit`,
  `categories.editor.cancel`; the field is the text field "Name".

## Tags & rules (spec full-app/06 section 1.6; Flutter `categorization_settings_page.dart`)

`Views/Settings/TagsRulesView.swift`, pushed from Settings >
PERSONALIZATION > Tags & rules (system back; "Tags & rules" in cardTitle
in the bar). Reads `model.tags` (stored order) and `model.rules` (Flutter's
`rules`, priority descending); every mutation is an awaited `AppModel` call
returning `TagRuleOutcome`. Scope is Flutter's: add / delete tag, add /
delete rule (no rule edit, toggle, bounds or reorder).

- Page: a scroll view padded 16 (Flutter's ListView). "Tags"
  (headingMedium) with a trailing "ADD" text button (accent, M3 labelLarge
  14 / w500, min 64 x 48; VoiceOver "Add tag"), 8, the tags card; 32;
  "Merchant rules" with "ADD" ("Add merchant rule"), 8, the rules card.
- Empty cards: `GlowCard` with bodyMedium in textSecondary: "Add tags to
  group transactions across categories." / "Rules can automatically choose
  a category and tags from a merchant name."
- Rows (`GlowListCard`, padding 16 / 24, 16 gaps, trailing 48pt `trash`
  button in textSecondary; no row tap): a tag is the `tag` IconTile in
  accent and the name (rowTitle), 56 tall; a rule is the `sparkles`
  IconTile in info, the merchant text (rowTitle) over Flutter's exact
  subtitle (rowSubtitle, secondary): `"{matchType raw} · {category}"` plus
  `" · {n} tags"` when it has tags ("contains · Groceries · 1 tags"), 72
  tall.
- Delete rule: instant (Flutter); memory changes first, so the row goes
  at once and the write follows (failure: `Toast.saveFailed` and the
  unsaved banner). Delete
  tag: the "Delete tag?" centred card ("This removes "{name}" from your
  tags and from any merchant rule that uses it.", Cancel / Delete in
  danger), awaited with the dialog inert, closing afterwards.
  Transactions keep the id (D9); the form and SEE ALL chips no longer
  show it.
- "New tag" (`NewTagDialog`, `budgieDialog(item:)` centred card, goalTitle
  title): the autofocused `BudgieField` "Tag name" (prompt "Travel
  planning", words; Return adds), Cancel / Add pills (44). A blank name
  closes silently (Flutter); `validateTagName`'s "A tag with this name
  already exists" shows inline and then follows the text.
- "New merchant rule" (`NewRuleDialog`): "Merchant text" (prompt "Whole
  Foods", autofocus, no capitalisation, Done closes the keyboard), then
  dropdowns in the field style (caption above, chip-surface box radius 14,
  52 tall, value in rowTitle, footnote up-down chevron): a tap opens a
  popover list anchored to the box (rowTitle rows at least 48 tall, accent
  check on the current one, scrolled to it, about nine rows high), and
  with the keyboard up it first dismisses the keyboard and opens once
  it has gone. "Type" (Income, Expense; default Expense), "Match"
  (Contains, Starts with, Exact match; default Contains), "Category"
  (`model.categories(for:)` names; default the first; a type change keeps
  the shown name when the new type has it, else its first); then, when
  tags exist, a "Tags" caption over the form's tag pills (FlowLayout 8,
  one line, truncated at the card's width), selected in tap order. The
  fields are a `DialogScroll`: its indicator flashes when the keyboard has
  shown, and its bottom 48pt fades while more is below (iOS 18+). Add is
  disabled (38%) while the trimmed text is empty. The draft sets only
  Flutter's fields. A refusal shows in danger caption above the buttons.
- Outcomes: `.saved` / `.unchanged` close silently; `.failed` closes with
  `Toast.saveFailed`; `.rejected` shows `error.message` inline.
- VoiceOver: a tag row's name and a rule row's text (label pattern, value
  subtitle) are one element each with a "Delete" action, followed by the
  "Delete {name}" / "Delete rule {pattern}" button; section titles and
  dialog titles are headers; dropdowns read "Type, Expense"; tag pills
  and the dropdown list's current row carry the selected trait.
- UI-test identifiers: `tagsRules.list`, `tags.add`, `rules.add`,
  `tags.empty`, `rules.empty`, `tags.row.<id>`, `tags.row.delete.<id>`,
  `rules.row.<id>`, `rules.row.delete.<id>`, `tags.editor.name`,
  `tags.editor.submit`, `tags.editor.cancel`, `tags.delete.confirm`,
  `tags.delete.cancel`, `rules.editor.pattern`, `rules.editor.type`,
  `rules.editor.match`, `rules.editor.category`,
  `rules.editor.tag.<id>`, `rules.editor.submit`, `rules.editor.cancel`;
  the Settings row is the button "Tags & rules"; the fields are the text
  fields "Tag name" and "Merchant text".

## Toasts

`Toast.Style`: `.success` (income), `.danger` (danger) and `.neutral`
(Flutter's default SnackBar: `textPrimary` fill with `background` text,
standing in for M3 inverseSurface / onInverseSurface), all floating,
radius 12, above the tab bar (`toastHost`).

## Recurring

`Views/Recurring/` (`recurring_transactions_page.dart`,
`recurring_transaction_form.dart`, on the redesign tokens: D1, D15).
Pushed from Settings > DATA "Recurring transactions". System bar with the
principal title "Recurring Transactions" (`cardTitle`) and a trailing
group: refresh (`arrow.clockwise`, "Generate Due Transactions",
`recurring.generate`) and "+" ("Add recurring transaction",
`recurring.add`).

- Generate: `model.generateDueNow()`, then its toast: "Due transactions
  generated and next occurrences updated" (also when nothing was due) or
  the save-failed toast. With nothing due it first retries any unsaved
  write and reports success only once nothing is unsaved. The button is
  disabled while it runs.
- Empty state (`recurring.empty`): 120pt `primaryGradient` circle with a
  white 52pt semibold `repeat` glyph, "No Recurring Transactions" (`headingLarge`), "Create
  recurring transactions to automatically\ngenerate expenses and income on
  a schedule" (`bodyMedium`, secondary), centred, padding 32; plus a filled
  "Add Recurring" pill (Swift only).
- List: `data.templates`, active first then paused, each in stored order,
  `RecurringCard`s 8pt apart, padding 16. Card (`recurring.card`, a
  GlowCard with padding 16): 44pt `IconTile` (category icon, income green
  or accent; fallback `bag.fill` / `dollarsign`), description (`cardTitle`)
  with a 16pt `RecurrenceGlyph` and, when paused, a warning "Paused" chip,
  the category (`caption`, tertiary), the amount (`numericMediumBold`,
  22 bold tabular, scaling down to 0.6; income green or primary text,
  masked by Hide balances); a hairline with 16pt above and below; two
  columns "Pattern" (`repeat`; Weekly / Bi-weekly / Monthly) and "Next
  Occurrence" (`calendar`; `MMM dd, yyyy`), 18pt symbols in a 20pt frame,
  labels `captionStrong` secondary, values `bodySmall`; then three outlined
  pills at least 44pt tall (`PillButton(minHeight:)`, growing with the
  text): Edit (accent), Pause (warning) / Resume (income), Delete
  (danger), stacked vertically when they do not fit (large text). At
  accessibility text sizes the description wraps freely, the Paused chip
  and the amount move under it, and the two detail columns stack. A paused card's
  content is at 0.65 opacity, its buttons are not. VoiceOver: one summary
  element (`recurring.summary`) "description, income|expense, amount,
  category, pattern, next occurrence date[, paused]", then the three
  buttons (`recurring.edit`, `recurring.pause`, `recurring.delete`).
- Pause / Resume: `setTemplateActive`, save-failed toast on a failed write.
  Resume moves the cursor to the first occurrence on or after today
  (`RecurringGenerator.resumedCursor`): nothing missed while paused is
  generated; one due today still is.
- Delete: alert "Delete Recurring Transaction?", message `This will stop
  generating future transactions for "<description>". Previously generated
  transactions will not be affected.`, Cancel / Delete (destructive, heavy
  haptic); the awaited `deleteTemplate` shows "Recurring transaction
  deleted" or the save-failed toast.

Form (`RecurringFormView`, a sheet with `budgieSheetChrome`, large detent;
also swapped in place into the transaction form by "Make this recurring"):
title "Add|Edit Recurring Expense|Income" (`headingMedium`); the
Expense/Income pills when adding only; Amount (`BudgieField`, currency
symbol, "0.00", decimal pad, focused on open; prefill
`toStringAsFixed(2)`); Description ("What is this for?", `doc.text`);
"Category" wheel (`CategoryWheelRow`: the tile in the fixed `expenseFixed` /
`incomeFixed` red or green, the same in dark mode),
"Recurrence Pattern" wheel (Weekly, Bi-weekly, Monthly; default Monthly) and,
for monthly, "Day of Month" wheel 1-31 (90pt boxes, chip surface, radius 12,
1.5pt border, selection haptic), each captioned in `captionStrong` (as are
the `BudgieField` labels); "Start Date" `DateTile` (`MMM dd, yyyy`;
danger border, label and icon with the error below it) opening
`DayPickerSheet` over `RecurringForm.startDateRange` (which also offers an
edit's stored start day, so an older template's picker opens on it and OK
keeps it); the "Next 3
Occurrences" card (`eye`, `EEEE, MMM dd, yyyy` lines, `bodySmall`); footer
Cancel (outlined) and Save / Update (expense or income gradient, spinner
while saving, interactive dismiss disabled). The start is
`RecurringForm.resolvedStart` (the form-open moment with its time, a picked
day at midnight, an edit's stored value). Day of Month starts at
`RecurringForm.initialDayOfMonth` (today's day when adding, else the stored
day) and follows the resulting start day until the wheel is moved (an
edit whose stored day differs from its start day counts as moved). Save runs `RecurringForm.validate`
(all three errors at once, the first announced to VoiceOver; typing clears
the amount / description error, a pick re-checks the date), then
`addTemplate` / `updateTemplate` with `RecurringForm.edit`, and dismisses
after the awaited Bool (save-failed toast on false). The preview is
`previewOccurrences(pattern:start:...)` when adding and
`previewOccurrences(editing:...)` from the cursor the edit will leave when
editing (`lastGeneratedDate` is read once when the form opens).

Recurrence glyph: every transaction row shows a 16pt `RecurrenceGlyph`
after the description when `isRecurring` (Home Recent activity, Home SEE
ALL, Flow preview, Flow SEE ALL, Spend category drill-in), and adds
", recurring" to the row's VoiceOver label or value.

## Settings

- Appearance: System / Light / Dark (`setThemeMode`).
- Currency: the 11 codes the Flutter app offers
  (USD CAD EUR GBP AUD JPY CNY INR KRW MXN BRL) (`setBaseCurrency`).
- Face ID lock toggle (`setAppLockEnabled`), shown with the device's
  biometry name; enabling requires a successful authentication first.
- About: version, "Data diagnostics" (the existing `DiagnosticsView`).

### Settings > DATA (spec full-app/06 sections 1.7-1.8; Flutter `settings_page.dart`)

- Rows: Recurring transactions, Export as CSV ("All N transactions"),
  Import from CSV, Export backup, Import backup (identifiers
  `settings.exportCSV`, `settings.importCSV`, `settings.exportBackup`,
  `settings.importBackup`). While one of the four data rows runs (from the
  tap until its message, through the share sheet, the document picker and
  the confirmation) all four are disabled and the running one shows the
  20pt spinner; VoiceOver reads "Exporting", "Importing" or
  "Restoring" for it.
  Recurring is never disabled.
- Share sheet (`ShareSheet`: `UIActivityViewController` with a
  `UIActivityItemSource`): the subject ("Budgie Backup", "Budget
  Transactions Export") is the Mail subject and the sheet's header title.
  The success toast ("Backup exported", "Transactions exported
  successfully!") shows only when an activity completed; the temporary
  file is deleted when the sheet reports back. The backup file is built
  off the main thread (`model.exportBackup()`).
- Document picker: one `.fileImporter` on the page, typed by what it is
  choosing (`.json` for a backup, `.commaSeparatedText` for CSV); the
  file is read in place (security scope, `NSFileCoordinator`) off the
  main thread. Cancel is silent; an unreadable file toasts "Could not
  import backup: The file could not be read" / "Could not import: The file
  could not be read".
- Confirmation: `DataImportDialog`, the centred `budgieDialog` card
  (goalTitle title, bodyMedium secondary message in a `DialogScroll`,
  Cancel and the action as 44pt pills). The action is awaited with the
  card inert (no Cancel, no scrim dismiss); a scrim tap is Cancel.
  - Backup: "Replace all data?", `RestorePlan.confirmationMessage`
    (Flutter's text, plus the kept-items sentence for a file that leaves
    sections out), Cancel / Replace (danger fill). Identifiers
    `backup.confirm.title|message|cancel|confirm`. Then "Backup restored"
    (success) or "Could not import backup: <reason>" (danger).
  - CSV: `Summary.confirmTitle` ("Import 2 transactions?"),
    `confirmMessage` (counts only, "2 duplicates will be skipped\n1 row
    could not be read"; no body when nothing was skipped), Cancel / Import
    (accent fill). Identifiers `csvimport.confirm.*`. Then
    `successMessage` (success) once the write verified, else the
    save-failed toast.
- A file the decoder refuses toasts "Could not import backup: <Flutter
  message>" (danger), e.g. "This is not a valid Budgie backup file".
- CSV: parsed off the main thread (`model.previewCSVImport`); nothing to
  import shows `emptyResultMessage` in its tone (neutral for "All
  transactions in this file already exist" and "No transactions found in
  this file", danger when rows could not be read) and no dialog; a
  refused file shows "Could not import: Not a valid transactions CSV
  export" (danger).

## Onboarding (spec full-app/07 section B; Flutter `onboarding_tutorial.dart`)

Shown once, when `flutter.onboarding_completed` is not true
(`model.showsOnboarding`, read at bootstrap): `MainView` shows
`OnboardingView` instead of the tabs, before `.appLock()`, so the lock
screen and privacy cover sit above it (not a `fullScreenCover`), and
VoiceOver cannot reach it while locked. Skip and
"Start budgeting" call `model.completeOnboarding()` (`OnboardingFlag
.markCompleted`: the key is removed, then set to a bool true); the tabs replace the
tour at once (Home) and a queued quick action, widget tap or link opens
then. Launch hook (DEBUG): `BUDGIE_SKIP_ONBOARDING=1` starts past the tour,
`=0` removes the flag.

- Background `background`; padding 24 / 8 top / 24 bottom inside the safe
  area. "Skip" top right: accent, Gabarito Medium 14 (+0.1), 64x48 minimum.
- Pager: a paged `TabView`, swipeable. Each page, centred (scrolls at large
  text sizes), padding 8: a 116pt circle (accent 14%) with a `GlowHalo`
  (blur 32, alpha 0.25; the light-mode ambient version in light) holding a
  40pt accent symbol (`wallet.bifold.fill` or `creditcard.fill`,
  `chart.bar.xaxis.ascending`, `chart.xyaxis.line`); 48pt; eyebrow
  (`.eyebrow`, accent); 16pt; title (`.displayMedium`, primary, header);
  16pt; body (Gabarito 17, -0.4, line height 1.45, secondary, max width
  390).
- Copy: WELCOME TO BUDGIE / "Your money, made clearer." / "Budgie keeps
  your budget simple and private. Financial data and insights stay on this
  device unless you choose to export or share a backup."; START HERE /
  "Track what comes and goes." / "On Home, use the add button for income or
  expenses. Your balance and recent activity update as you go."; EXPLORE
  WHEN READY / "Plan ahead, then look back." / "Worth tracks accounts, Goals
  keeps savings in view, and Spend, Flow, and Settings (behind the gear on
  Home) help you understand and manage your budget."
- Dots: active 22x8 accent capsule, others 8x8 `border`, 4pt margins,
  resized over 150ms linear. VoiceOver: one adjustable element "Tutorial
  page", value "n of 3".
- 24pt, then a full-width button (min 56pt, radius 16, accent fill,
  `onAccent` Gabarito Medium 14): "Continue" moves to the next page (300ms
  easeInOut; a jump under Reduce Motion) and announces it to VoiceOver;
  "Start budgeting" on page 3.
- Identifiers: `onboarding.skip`, `onboarding.next`, `onboarding.dots`,
  `onboarding.page.<n>`.

## App lock

When `appSettings.appLockEnabled`: an opaque privacy cover whenever the
scene is inactive/background; on returning after
`autoLockTimeoutSeconds` (0 = immediately), or at launch, require
`LAContext.evaluatePolicy(.deviceOwnerAuthentication)` before showing data.
The lock never blocks the bootstrap or saves. While locked, everything
beneath the lock screen (the tabs, or the onboarding tour) is hidden from
VoiceOver (`accessibilityHidden(model.isLocked)`, Flutter's
`ExcludeSemantics`), and the lock screen is modal (`.isModal`).
