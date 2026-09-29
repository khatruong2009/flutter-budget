# Parity gaps: what the Swift MVP does not do yet

Everything below is either missing from the MVP UI or a deliberate
difference. In every case the data is preserved: sections the MVP does not
edit are written back exactly as read, and the Flutter build can be
reinstalled over the Swift app at any time (verified, see
UPGRADE_TEST_RESULTS.md).

## Features not in the MVP (data preserved)

| Flutter feature | Stored in | MVP status |
|---|---|---|
| Voice entry (OpenAI) | nothing persisted | Removed; no API key in the binary. `budgetapp://voice-add`, the Voice Add widget and the old voice quick action open the expense form. The widget gallery text still says "Speak a transaction". |
| Net worth editing (add account, update balance, carry forward, delete snapshot) | `netWorthEntries`, `selectedNetWorthMonth` | Read-only list, totals and chart. |
| Savings goals UI | `savingsGoals` | Read (safe-to-spend reserves goal contributions exactly like Flutter); no UI to view/edit. |
| Insights | `local_insights_*` prefs | Not shown; prefs untouched. |
| Categorization rules, tags | `categorizationRules`, `transactionTags`, `Transaction.tagIds` | The transaction form applies rules and toggles tags; no rule or tag management UI yet. |
| Category management (add, rename, archive, reorder) | `categories` | Launch materialises legacy names (transactions, templates, budget keys) and normalises sort orders exactly like Flutter; no editing UI yet. |
| Onboarding tour | `flutter.onboarding_completed` | Never shown; flag untouched. |
| Backup export/import (JSON envelope v3) | files chosen by the user | Not available. CSV export is. |
| CSV import | ledger | Not available. |
| Hide balances toggle, locale override picker, auto-lock timeout picker | `appSettings` | Honoured when set by the Flutter app; no toggles in the MVP. |
| Month picker limited to the selected year | UI state | Fixed (D13): Home's month panel has a year stepper above the wheel, and the wheel always shows the selected month. |

## Flutter behaviour reproduced on purpose (approved Q1; fix in both apps later)

- Weekly/biweekly recurrences advance by 7/14 x 24 hours of elapsed time,
  so after a DST change they drift an hour (a midnight template lands at
  23:00 the previous day after the November change).
- Safe-to-spend compares full timestamps against midnight of "today": an
  expense entered today with the default date/time is not counted in
  "Expenses recorded" until tomorrow, while the month totals include it.
- `daysRemaining` counts elapsed 24-hour units, one day short in
  spring-forward months.
- Suggested goal contributions use the wall clock, not the viewed month.
- Legacy `starting_assets`/`starting_liabilities` preferences recreate
  "Starting Assets/Liabilities" accounts whenever the net worth list is
  empty (Flutter never removes those keys).
- An empty bare `transactions` legacy key (`[]`) replaces the ledger of a
  v1 backup envelope during legacy migration.
- "Match device" formats money as en_US (the Flutter app never sets an intl
  locale); JPY/KRW show two decimals.
- CSV rows with identical timestamps keep input order (Swift stable sort);
  Dart's sort is not stable above 32 rows, so tie order can differ from a
  Flutter export of the same data. Bytes are otherwise identical.
- Categorization rules with equal priority are tried in stored order (Swift
  stable sort); Dart's sort is not stable above 32 rules, so with more than
  32 rules the suggestion among equal-priority matches can differ.
- Spend tab: categories with equal month totals keep first-appearance order
  (Swift stable sort); Dart's sort is not stable above 33 categories in a
  month, so there the order of tied categories (their rows, colours and
  which of them fall into "Other") can differ (Fixtures/spend `forty_ties`).
- Worth: accounts with the same month value and the same lowercased name
  keep stored order, and snapshots recorded at the same instant keep stored
  order (Swift stable sorts); Dart's sort is not stable above 32 items.
- Goals: goals with the same completion state and target date keep stored
  order (Swift stable sort); Dart's sort is not stable above 32 goals.
- Goals: a goal is "Behind" on its target day unless fully funded (the
  deadline is 00:00 of that day), and a goal created today for today is
  "Behind" at once. Overdue goals show "bump to ... to catch up".
- Goals: on hand-edited data with a zero or negative target, any
  allocation stamps `completedAt` although the goal never shows Complete.
- Goals: only Add money celebrates. Raising "Saved so far" to the target in
  the edit form completes the goal with no haptic or overlay, and whether
  Add money celebrates is judged on the goal as shown before the dialog
  (`amount >= remaining`), not on the model's own completion test.

## Deliberate differences (approved)

- Net worth mutations (add, update, delete account, delete snapshot, carry
  forward, select month) are awaited and return the verified write result.
  Flutter's add/update/delete/select return nothing and ignore the save
  result (the retry banner still shows); its carry-forward returns whether
  anything changed, which Swift's returns only when the write also
  succeeded.
- Net worth: updating or deleting an account id that does not exist
  writes nothing (Flutter rewrites the unchanged list, revision +1).
  Deleting a snapshot shared by several accounts with the same id writes
  when any of them changed (Flutter decides by the last one only).
- Net worth: an edited account is patched in place. Unknown keys, `id` and
  `createdAt` lexemes, and the stored JSON of kept snapshots survive;
  legacy-shaped snapshots (`monthKey`/`updatedAt`, or no date) of that
  account are written as Flutter writes them. Flutter rewrites every
  account from `toJson`, dropping unknown keys. For data Flutter wrote the
  bytes are identical (Fixtures/worth).
- Net worth amounts must be finite: a NaN/Infinity balance (Flutter's
  editor accepts a 330-digit number as Infinity) is refused before memory
  changes; Flutter keeps it in memory and fails every later save.
- Savings goal mutations (add, edit, delete, add money) are awaited and
  return the verified write result. Flutter's return nothing and ignore the
  save result (its page shows the success snackbar either way; the retry
  banner still shows). Invalid input and unknown ids write nothing in both.
- Savings goals: an edited goal is patched in place. `id` and unknown keys
  survive, and every other key keeps its stored JSON when it already holds
  the value Flutter would write; otherwise Flutter's value is written (int
  or string amounts become doubles, a date that fell back to "now" is
  written out, `completedAt` is always present). Untouched goals and
  unreadable rows are written back verbatim. Flutter rewrites every goal
  from `toJson`, dropping unknown keys and pinning fallback dates of all of
  them. For data Flutter wrote the bytes are identical (Fixtures/goals).
- Savings goal amounts must be finite: NaN/Infinity (Flutter's form accepts
  "NaN", "Infinity" and "1e999") are refused before memory changes, as is an
  allocation whose sum overflows or a goal whose stored amount is a
  non-finite string (an edit, which replaces both amounts, repairs it).
  Flutter keeps the value in memory, and then every later save of the model,
  transactions included, fails until restart. A NaN progress shows 0%
  (Flutter's card throws).
- Savings goals: a row Flutter cannot read (not an object, or a non-string
  `id` or `name`) makes Flutter's whole app load fail (initialization error
  screen). Swift keeps the row verbatim, hides it, and loads the rest.
- Savings goals: editing a goal whose id is duplicated patches each copy
  with the edit, keeping each copy's own `createdAt` and completion stamp
  (Flutter overwrites every copy with the edited card, `createdAt` and stamp
  included). Add money and delete act on every copy in both.
- Savings goals: a new goal's id uses Flutter's format and counter, with
  the timestamp of its `createdAt` (Flutter reads the clock twice,
  microseconds apart). A stored goal without an id gets a UUID that is
  saved with the next goal write; Flutter generates a new
  `savings_goal_...` id at every launch until a goal save.
- Goals dialogs (add / edit, Add money, delete) stay open while the write
  is awaited, with the scrim and buttons inert, then close (Flutter closes
  the dialog first and saves afterwards).
- Goals toasts: "Savings goal added / updated / deleted" and "Allocation
  added" show only when the write is verified; a failed write shows the
  save-failed toast with Retry instead (Flutter shows the success snackbar
  either way), and a change the model refuses (the goal is gone, a sum
  that overflows) closes the dialog without a toast. Toasts replace each
  other rather than queue (shared toast host).
- Goals celebration: the medium haptic and overlay play only when the Add
  money write succeeded (Flutter plays them after a failed save too).
  VoiceOver hears "Goal complete, {name}" queued after the toast, and the
  overlay is one labelled element; Flutter announces nothing.
- Goals amount fields (Target amount, Saved so far, Allocation amount) parse
  with the money format's separators (`AmountInput`, D6): "1.500,00" is 1500
  under de_DE and a lone "12,5" is 12.5; signs, exponents, hex, "NaN" and
  "Infinity" are rejected with the field's error. Flutter strips every ","
  and "$" and uses `double.tryParse` ("1,5" is 15). The prefix symbol is the
  base currency's (Flutter always shows `$`).
- Goals edit form: the amounts prefill locale-grouped ("5,000.00", like the
  budget limit sheet; Flutter "5000.00"), and a field left as prefilled saves
  the stored amount exactly (Flutter re-parses the 2-decimal prefill, so an
  untouched 33.333 becomes 33.33).
- Goals Add money: while the field reads the "Finish goal" text the exact
  remainder is saved, so the goal always completes (Flutter fills the
  remainder rounded to cents and can fall short, e.g. 33.334 -> 33.33).
- Goals target date: the shared graphical day picker sheet (Cancel / OK)
  instead of Material's calendar dialog, over Flutter's range (Jan 1 of
  last year to Jan 1 of year + 20, inclusive) stretched to include the
  shown date, so an old overdue goal can be edited (Flutter asserts, D6).
- Goals cards are keyed by goal id, so ring state follows its goal when the
  order changes (Flutter's cards are unkeyed and keep it by position).
- Goals tab state survives tab switches (native `TabView`): the rings and
  the add button do not replay their entry animations on return (Flutter
  rebuilds the page). A celebration still ends when the tab is left. The
  status and pace re-read the clock when the app returns to the foreground.
- Goals icons (D3): `banknote` stands in for Material's piggy bank
  (`savings_rounded`) on the empty state and the "Saved so far" field; the
  ellipsis button's ring uses the 8% pill border token (Flutter 10%).
- Goals actions sheet: a native sheet with a clear background and a
  content-sized detent holding the floating card (Flutter's Material modal
  bottom sheet); the Add money dialog shares the 500pt dialog width
  (Flutter 460, only visible on screens wider than 548pt); a celebration
  card for a long name keeps a 20pt margin (Flutter's reaches the edges).
- Goals accessibility: each card reads as one element ("{name}, {status}",
  valued percent, amounts and pace) with Add money, Edit goal and Delete
  goal actions, the Add money and ellipsis buttons staying separate; the
  summary card reads "Saved so far" with its totals. Flutter labels only
  the add button and the ellipsis.

- Transactions page: when the selected month loses its last transaction,
  the page falls back to the newest month with data (Flutter keeps the
  stale month selected, with no chip highlighted and a "No Transactions"
  list).
- Transactions page: the swipe's medium haptic fires as the drag crosses
  40% of the width (Flutter's fires on release), and the row springs back
  while the confirmation shows (Flutter slides it out first).
- Transactions page: a delete is awaited and shows "Transaction deleted"
  only when the write succeeded, otherwise the save-failed toast (Flutter
  fires and forgets the write and always shows the deleted snackbar).
- Editing a recurring template keeps its next occurrence and paused state
  (Flutter resets both and re-creates up to 90 days of duplicates). A
  schedule change restarts the cursor from the new start date but never on
  or before the last generated occurrence. Pause/resume is available.
- Generated recurring transactions and the advanced cursor are saved in
  one write (Flutter saves them separately; a crash in between duplicates).
- Both store files unreadable: Swift stops with "Your data couldn't be read"
  until the user chooses to start empty (Flutter silently starts empty). The
  set-aside `.corrupt-*` files are kept in both.
- Unreadable rows (malformed JSON rows in a section) are kept verbatim and
  hidden; Flutter drops them on its next save (transactions) or fails to
  load (recurring, net worth, goals). For categories, one malformed row
  makes Flutter replace the whole list with the built-in seeds, and for
  tags and rules it makes Flutter load an empty list; Swift keeps using the
  readable rows (the seeds only when none are readable).
- At launch Flutter rewrites the whole `categories` list in canonical
  `toJson` form whenever it differs from the stored JSON (a row missing
  `isBuiltIn`, say). Swift writes the list only when a definition was added
  or a sort order changed, and patches just those keys, so unknown keys
  survive.
- A quick action, widget tap or deep link on a locked launch opens its
  form only after App Lock is passed (Flutter pushes it on the root
  navigator, above the lock screen).
- A preference with an unexpected type reads as absent; Dart would throw.
- Numbers typed into Swift are validated finite; Dart would fail to save a
  NaN/Infinity forever.
- App Lock on a device with no passcode lets the user in with a message
  (Flutter shows its lock screen with an unlock button that cannot
  succeed). Without a passcode there is nothing to authenticate against.
- Editing a transaction without touching the amount keeps the stored
  value exactly; the Flutter form re-parses its 2-decimal prefill.
- Transaction form (D5): a card-styled sheet instead of a centred dialog,
  with an Expense/Income toggle (Flutter's type is fixed by the entry
  point) and "Edit Expense/Income" titles when editing (Flutter says "Add").
- Transaction form: saving blocks swipe-to-dismiss, so a failed write
  always shows its toast (a barrier tap in Flutter drops the snackbar).
- Transaction form: NaN, Infinity and overflowing amounts ("1e400") are
  rejected with "Please enter a valid number" (Flutter accepts them).
- Transaction form: the device's decimal separator is accepted ("12,5" in
  a comma locale, as the MVP did); Flutter's `double.tryParse` rejects it.
  Rule suggestions parse the amount the same way.
- Transaction form: clearing the description on an edit saves
  "Transaction" (Flutter keeps the old description), and the non-blocking
  "Description is recommended" warning is dropped (Flutter shows it only
  while the save is in flight).
- Transaction form: when a rule changes the category, the wheel scrolls to
  it (Flutter's wheel stays on the old row while the saved value changes).
- Transaction form: the date picker's range stretches to include a stored
  date before 2000 or in the future (Flutter's `showDatePicker` asserts).
  The picker is a graphical calendar sheet with Cancel / OK.
- Transaction form: switching Expense/Income (D5) gives an edit its stored
  category back on the record's own type (else a category the new type
  lacks becomes its first), drops the tags the last rule suggestion added
  (manual picks and the record's stored tags stay), then runs the new
  type's rules on the current description and amount.
- Transaction form: the amount icon is the base currency's symbol (Flutter
  always shows `$`); the wheel tiles use the danger/income tokens (Flutter
  uses fixed #EF4444/#10B981 in both themes); tags are redesign pill chips
  (accent tint with a checkmark when selected) instead of Material
  FilterChips.
- Transaction form: an edit offers "Delete Transaction" with a
  confirmation (Flutter deletes only by swiping the row).
- Transaction form: "Make this recurring" turns the same sheet into the
  recurring form for the form's type (Flutter pops the dialog and opens a
  new one); as in Flutter nothing is carried over and an edit is discarded.
- Budget limit sheet (D6): the field prefix is the base currency's symbol
  (Flutter hard-codes "$").
- Budget limit sheet and Flow SEE ALL Min / Max amounts (D6): both parse
  with the number format's separators (`AmountInput`): "1.500,00" is 1500
  under de_DE (Flutter's limit strips `[^0-9.]` and reads 1.5; its filter
  drops ',' and reads 1.5 from "1.500,00" and 1.23456 from "1.234,56"). A
  lone grouping separator not followed by three digits is read as the
  decimal key of a keyboard in another locale ("12,5" is 12.5 under en_US;
  Flutter's limit and filter read 125). Only digits and separators are
  accepted: Flutter saved "-5" as 5 and "1e3" as 13, and its filter took
  "-5", "+5", "1e3", "0x10", "NaN" and "Infinity" (NaN marked the filter
  active but excluded nothing; an infinite minimum hid every row); Swift
  leaves such a bound unset. A limit must be above 0; a filter bound may be
  0.
- Budget limit sheet: an untouched prefill saves the stored limit exactly
  (99.999 stays 99.999, and 0.001 can be saved); Flutter re-parses the
  2-decimal prefill, saving 100.0 and refusing "0.00".
- Budget limit field: filled with the chip-surface token (Flutter's theme
  fill is #F9FAFB light / #15151F dark; dark is identical).
- Home month panel: a year stepper (previous/next year, light haptic,
  keeps the month) sits above the wheel (D13), and the wheel always shows
  `selectedMonth` (Flutter's wheel keeps the month it first showed, so it
  can disagree with the pill).
- Home month wheel: a custom snapping drum with the CupertinoPicker
  geometry (34pt rows, diameter ratio 1.07, squeeze 1.45, about five rows
  in 128pt, 0.447 dimming, band inset 9 / radius 8) that selects every
  month it passes like Flutter. Rows are compressed and foreshortened but
  drawn flat (no 3D tilt), and each row is dimmed by its share inside the
  band (Flutter dims the part of each glyph outside the band). Row height
  and box scale with Dynamic Type; VoiceOver gets one adjustable "Month".
- Home hero: the odometer rolls the rounded amount (Flutter's rolling
  widget truncates the cents, so it can show 0.01 less than the halo and
  VoiceOver), is not re-rolled by a text-size change, and scales down to
  fit instead of overflowing a narrow screen.
- Home: the page's bottom padding clears the add button (Flutter lets the
  Expense/Income pills sit under it); there is no mic button until voice
  entry returns.
- Home spend gauge: under Reduce Motion a changed value jumps (Flutter
  only skips the first fill and still animates changes).
- Home accessibility: the gauge reads "Spent X of Y income" and the year
  stepper's buttons are labelled; a recent-activity row's VoiceOver label
  is the description ("Transaction" when empty) with the rest as its
  value, which reads the same as Flutter's single label.
- Category icons: a transaction, template or budget row finds its
  category's icon by name case-insensitively, archived definitions
  included (`categoryInfo(named:type:)`). Flutter reads its active
  `expenseCategories` / `incomeCategories` map by exact name and shows its
  fallback icon (the grid; a bag or dollar on the recurring list) for an
  archived category or a case variant.
- Transactions page (SEE ALL): a row's VoiceOver label reads the amount
  through the money formatter ("expense $12.50": base currency, masked
  under Hide balances); Flutter's reads "expense of 12 dollars and 50
  cents" whatever the currency. Both read the date as yMMMMd.
- Flow SEE ALL category options: names whose lower-case forms are equal
  ("Groceries" / "groceries") keep first-appearance order (Swift stable
  sort); Dart's sort is not stable above 32 options, so their relative order
  can differ.
- Flow SEE ALL rows (D7): a tap opens the edit form and a left swipe asks
  "Delete Transaction" before deleting; the delete is awaited and toasts
  "Transaction deleted" or the save-failed message (a row already gone just
  closes the alert). Flutter's rows are read-only.
- Flow SEE ALL month pill (D6): picking a month in 'SELECT MONTH' also sets
  From/To to that month's first and last day, so the list shows that month;
  Flutter changes only the shared month and the list ignores it. While
  From/To are not exactly that month (before any pick, after RESET or after
  editing a date) the pill's label is dimmed to the secondary colour, no
  month is ticked in the sheet, and VoiceOver adds "not filtering the list";
  Flutter's pill always looks applied and ticks the shared month.
- Flow SEE ALL amount fields (D6): the prefix is the base currency's symbol
  (Flutter hard-codes "$ ").
- Flow SEE ALL chrome: the system navigation bar's back button and swipe
  replace the 36pt chip back button, and the 'Transactions' title (in
  sectionHeader, beside the back button) and the month pill sit in that
  bar, so the list scrolls under a normal bar; Flutter's header row
  (pageTitle) scrolls away with the page.
- Flow SEE ALL tag chips: redesign pills (accent tint with a check when
  selected, outlined otherwise) instead of Material `ChoiceChip`s.
- Flow SEE ALL sheets: 'SELECT CATEGORY' / 'SELECT MONTH' use the redesign
  sheet chrome (44x4 handle) with plain rows (no Material ripple); the From/To
  date picker is the shared graphical day picker sheet (Cancel / OK) instead
  of Material's calendar dialog.
- Flow SEE ALL: dragging the page dismisses the keyboard (the decimal pad has
  no return key); Flutter keeps it up.
- Flow SEE ALL accessibility: rows read "description, category, date, signed
  amount" with an edit hint and a Delete action; filter controls are
  labelled. Flutter authors no semantics on this page.
- Safe-to-spend breakdown sheet: redesign sheet chrome (card colour, 44x4
  grab handle, 28 radius) instead of Material's default sheet and 32x4
  handle; the divider uses the border token.
- Quick-expense sheet: a native sheet at 66% or 90% height; Flutter's
  draggable sheet also shrinks to 36% and closes there.
- Spend drill-in (like D7): rows open the edit form and swipe to delete;
  the delete is awaited and shows "Transaction deleted" or the save-failed
  toast (Flutter's rows do nothing on tap, and its delete is fire-and-forget
  with no snackbar). The swipe's medium haptic fires at the 40% threshold
  and the row springs back while the confirmation shows, as on SEE ALL.
- Spend drill-in: the colour and icon follow the category's current rank
  in the month (Flutter keeps the ones it was pushed with, so a delete that
  re-ranks the category shows a different colour there than on the list).
- Spend drill-in: the system navigation bar (back button, edge swipe,
  category title in cardTitle) instead of Flutter's 36pt header; the back
  tap has no light haptic.
- Spend empty states: `EmptyStateView`'s plain 56pt symbol in the
  secondary colour instead of Flutter's 96pt expense-gradient tile with a
  white glyph.
- Spend donut: VoiceOver reads it as one adjustable element ("Spending by
  category", the total or the selected slice as its value; swipe up/down
  selects slices). Flutter's donut has no semantics.
- Spend tab: the month, selected slice, expanded tail and a pushed
  drill-in survive a tab switch, and the donut does not sweep again
  (Flutter's tab pages are probably rebuilt; not verified on device).
- Spend tab: under Reduce Motion a changed bar value jumps (Flutter only
  skips the first fill and still tweens month changes).
- Spend tail row: the tile's neutral fill is the hairline token (white 6%
  dark, ink 6% light; Flutter's light value is black 5%).
- Spend month sheet: a native sheet (system scrim, drag to dismiss)
  sized to its content, instead of Material's bottom sheet.
- Home sheets (safe-to-spend breakdown, EDIT / Add pickers, limit sheet):
  native sheets sized to their content with the system's bottom allowance
  (floating and inset on iOS 26) instead of Flutter's `SafeArea`; the
  pickers cap at 75% of the screen, and the limit sheet sits on the
  keyboard with Flutter's 16pt gap under Save.
- Flow tab: the chart range and a pushed SEE ALL page survive switching
  tabs (the native `TabView` keeps each tab's state); Flutter's `PageView`
  disposes the tab, so its range resets to 6 months on every tab switch.
- Flow tab accessibility: bars, metric chips, year-over-year rows and the
  trend have VoiceOver labels ("September 2026, net +$3,158", "12-month net
  trend, From ... to ..."); Flutter has no semantics there and reads only
  the bare texts.
- Flow sheets (chart range, month detail): the redesign sheet chrome (44x4
  handle at 60%, 24 radius, content-sized detent) instead of Material's
  sheet with a 40x4 handle at 30%; range rows dim on press instead of the
  Material ripple.
- Flow bars: the current month's badge capsule grows to fit its text
  (Flutter clips it to four bar widths), and month labels overflow their
  column rather than clip at large text sizes.
- Flow month detail sheet: the net amount scales down to fit one line
  (Flutter's row overflows); SF Symbols stand in for Material's
  `bar_chart`, `south_west`, `north_east` and `check`; a negative net shows
  a down-trend symbol (Flutter shows `trending_up`, D6).
- Flow trend: a data change interpolates the twelve values (and the bound
  derived from them) over 150ms; fl_chart interpolates the spots and the
  axis bounds separately, so mid-animation frames can differ slightly.
- Flow preview rows find the category icon like the other transaction rows
  (case-insensitive, archived included; see "Category icons" above).
- Worth account rows: the long press is a native context menu with the
  sheet's actions (Edit Balance, View History, Delete Account) instead of a
  Material bottom sheet.
- Worth hero (D6): the odometer rolls the rounded whole-unit amount in the
  base currency (Flutter truncates the fraction and hard-codes "$"), shows
  "••••" under Hide balances like Home's hero (Flutter shows the digits),
  scales down to fit (Flutter overflows), and a sign change rebuilds the
  reels (Flutter's "-" is a separate text beside them).
- Worth editor: a failed write closes the dialog and shows the save-failed
  toast (Flutter only shows the banner); Save, Cancel, close and the scrim
  are disabled while saving (a Flutter double tap adds the account twice).
- Worth editor: the balance month is an inline month grid with a year
  stepper (January 1970 to this month) instead of Material's calendar
  picker, so a persisted future month cannot hit the picker's assert.
- Worth editor: an untouched balance saves the stored value exactly
  (Flutter re-parses its 2-decimal prefill); a comma-decimal keyboard's ","
  typed at the end reads as "." (Flutter's formatter drops it, D6); the
  field glyph follows the base currency (Flutter: `attach_money`).
- Worth editor fields are the shared `BudgieField` and `DateTile` (caption
  labels, 1.5pt focus stroke, chevron) instead of the editor's own chrome
  (w600 labels, 2pt accent focus border, accent calendar icon); the close
  button has a VoiceOver label.
- Worth: "Delete account?" (from a row or the history page) and "Delete
  balance update?" are system alerts with Flutter's copy instead of
  Material dialogs; Delete keeps a plain (not destructive, not red) role,
  as Flutter's accent TextButton. A failed delete or month selection shows
  the save-failed toast (Flutter: banner only).
- Worth tab: the Assets / Liabilities tab, the chart range and a pushed
  history page survive switching tabs (Flutter's `PageView` resets them).
- Worth growth chart: a range change that changes the number of points
  cross-fades over 150ms (fl_chart morphs the spots); VoiceOver reads a
  summary and steps through the points, and rows, hero, split card and
  delta pill have labels (Flutter labels only the hero and FAB).
- Worth account history: the page scrolls inside the safe area, so its last
  timeline row clears the tab bar; Flutter's page keeps only 32pt of bottom
  padding under the floating dock, which covers the last rows.
- Worth account history chart tooltip: drawn once, and kept inside the
  plot horizontally. fl_chart supplies one touched spot per line (glow and
  main), so Flutter stacks the date/amount block twice, and its tooltip is
  not clamped (at the first point it runs off the screen edge).
- Worth account history chart: a data change (a deleted update) redraws at
  once; fl_chart tweens the spots and axis bounds over 150ms linear.
- Worth account history: when the account disappears while the page is
  open (deleted elsewhere, or a restore without it) the page shows "Account
  deleted" / "This account is no longer tracked in your net worth." instead
  of Flutter's stale name over empty cards; the edit and delete buttons
  hide.
- Worth account history: the timeline trash buttons and the bar's edit and
  delete buttons carry VoiceOver labels ("Delete this balance update" /
  "Keep at least one balance update", "Edit balance", "Delete account"),
  each row reads as one element with a Delete action, and the hero, stat
  cards and chart have summaries ("Balance trend, 3 balance updates from
  ... to ..."). Flutter has only the two tooltips.
- Worth account history: SF Symbols stand in for Material's `north_east`
  (`arrow.up.right`), `south_west` (`arrow.down.left`), `calendar_month`
  (`calendar`), `edit_rounded` (`pencil`) and `delete_rounded`
  (`trash.fill`, `trash` in the bar). The snapshot chip's fill uses the
  hairline token (white 5.9% / ink 6.3%) for Flutter's white 6% / black 5%.

## Known MVP limitations

- A sheet open when the app goes to the background (e.g. the transaction
  form) is not covered by the App Lock privacy cover.
- No iPad layout (the Flutter app is iPhone-only too).

## Platform

- Minimum iOS 17 (Flutter: iOS 15). Users on iOS 15/16 stay on the last
  Flutter release.
- Quick action icons use SF Symbols (the Flutter build referenced asset
  names that did not exist, so its items had no icon).
