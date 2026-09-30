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
| Insights | `local_insights_*` prefs | Not shown; prefs untouched. |
| Categorization rules, tags | `categorizationRules`, `transactionTags`, `Transaction.tagIds` | Available: Settings > Tags & rules (add and delete tag, the tag stripped from rules; add and delete rule; Fixtures/tags). The transaction form applies rules and toggles tags. As in Flutter there is no rule edit, enable switch, amount bounds or reorder. |
| Category management (add, rename, archive, reorder) | `categories` | Available: Settings > Categories (add, edit with the rename cascade, archive/restore, move up/down). Launch materialises legacy names (transactions, templates, budget keys) and normalises sort orders exactly like Flutter (Fixtures/categories). Differences are listed under "Deliberate differences". |
| Onboarding tour | `flutter.onboarding_completed` | Flag shared with Flutter (`OnboardingFlag`: a CFBoolean true under the same key; missing or another type shows the tour), read at launch after protected data is available, written when the tour is completed or skipped. Available: the three-page tour shows once, in place of the tabs and inside the lock gate (differences under "Deliberate differences"). |
| Backup export/import (JSON envelope v3) | files chosen by the user | BudgieCore export, decode, restore and pre-restore safety copy are done and match Flutter byte for byte (Fixtures/backup; differences below); the Settings rows still open the "upcoming" page until the UI lands. |
| CSV import | ledger | Not available. |
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
- Tie order of sorts. Dart's `List.sort` is an insertion sort (stable) for
  lists of up to 33 elements and a dual-pivot quicksort (not stable) from
  34 (dart:_internal `sort.dart`, threshold `right - left <= 32`; verified
  on the VM, Fixtures/backup/dart_sort.json). BudgieCore's `DartSort` is a
  faithful port; the rules order (`CategorizationEngine.ordered`: the Tags
  & rules list, suggestions and the backup export) uses it and matches
  Flutter at any size (Fixtures/tags `sort_*`). The sites below still use
  Swift's stable sort, so from 34 elements the order of tied items can
  differ until they switch to `DartSort`:
  - CSV rows with identical timestamps keep input order, so tie order can
    differ from a Flutter export of the same data. Bytes are otherwise
    identical.
  - Spend tab: categories with equal month totals keep first-appearance
    order, so with 34 or more categories in a month the order of tied
    categories (their rows, colours and which of them fall into "Other")
    can differ (Fixtures/spend `forty_ties`).
  - Worth: accounts with the same month value and the same lowercased name
    keep stored order, and snapshots recorded at the same instant keep
    stored order (34 or more items).
  - Goals: goals with the same completion state and target date keep
    stored order (34 or more goals).
  - Category sort-order normalisation with duplicate `sortOrder` values
    (34 or more categories of a type).
- Category renames follow exact (UTF-16) names only. A case variant
  ("gift" when "Gift" is renamed) or the other Unicode normalisation keeps
  the old name, and gets a definition of its own at the next launch if it
  has none. When the new
  name already has a budget limit, that limit stays and the renamed
  category's limit is dropped (Dart `putIfAbsent`). A case-only rename
  cascades; an icon or colour edit, or the same name with padding, does
  not. Transactions renamed get `updatedAt` = now, even when that is
  earlier than the stored value, and one instant for the whole rename
  (Dart calls `DateTime.now()` once per renamed row, so its rows get
  distinct, increasing microseconds; nothing reads that order).
- A category name with leading or trailing spaces (a transaction's,
  template's or budget key's) is materialised again at every launch: the
  launch pass compares the trimmed name with the stored, untrimmed one
  (`_containsName`), so each launch adds another definition with a new id
  (`type-<uuid>`, the slug being taken). Both apps do this; a restore adds
  one as well (Swift runs the launch pass in the restore, Flutter at its
  next launch). Fix in both apps later.
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
- Goals Add money: while the field reads the "Finish goal" text the
  remainder is saved, nudged up by the ulp or two `current + remainder`
  can lose (14133.23 + (60422.9 - 14133.23) is 60422.899999999994), so the
  goal always completes (Flutter fills the remainder rounded to cents and
  can fall short, e.g. 33.334 -> 33.33).
- Goals target date: the shared graphical day picker sheet (the app's
  outlined Cancel and accent-filled OK pills) instead of Material's
  calendar dialog; on iOS 26 the system picker draws the selected day in
  the label colour (its tint reaches only the month header; `.tint`,
  `.accentColor` and `UIDatePicker.appearance().tintColor` were tried),
  where Material fills it with the accent, over Flutter's range (Jan 1 of
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
- Goals actions sheet: the floating card over the dialog scrim at the
  bottom, 20pt from the edges (Flutter's transparent modal bottom sheet),
  sliding up (a fade under Reduce Motion) and dragged down or scrim-tapped
  to close; Edit goal / Delete goal swap it for that dialog in the same
  presentation (Flutter pops the sheet, then opens the dialog). The Add
  money dialog shares the 500pt dialog width
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
- Recurring form "Next 3 Occurrences" while editing starts at the cursor the
  edit will leave (`RecurringTemplate.editedCursor`: what will really be
  generated next). Flutter previews from the start date, because its edit
  resets the cursor there. Adding previews from the start date as Flutter
  does (Fixtures/recurring, five zones).
- Recurring form: no Day of Week wheel for weekly/biweekly; `dayOfWeek`
  stores the start date's weekday (Flutter stores the wheel's value, which
  can contradict the start date). Nothing in either app reads `dayOfWeek`.
- Recurring form: the Day of Month wheel follows the picked start day until
  the wheel is touched (Flutter's defaults to today's day and never
  follows); the preview uses the wheel's value, as Flutter's does.
- Recurring form: "Start date cannot be more than 1 year in the past"
  applies only to a start set in this form (a new template, or an edit that
  picked a different day), never to an untouched stored start (Flutter
  refuses to save any edit of a template that started over a year ago). The
  picker offers only days that pass the rule (`RecurringForm.startDateRange`):
  Flutter also offers the day of `now - 365 days`, whose midnight always
  fails unless it is exactly midnight. Re-picking the stored start's own
  day keeps the stored value and its time, so the schedule and cursor stay
  (Flutter stores that day's midnight).
- Recurring form amount: NaN and Infinity are refused with "Please enter a
  valid number" (Flutter's `double.tryParse` lets NaN through `<= 0` and
  saves it); the locale's decimal separator is accepted.
- Recurring "Generate Due Transactions": one awaited write of rows and
  cursors; "Due transactions generated and next occurrences updated" is
  shown verbatim, also when nothing was due (Flutter), but a failed write
  shows the save-failed toast instead (Flutter ignores the result).
  Deleting a template is awaited too: "Recurring transaction deleted" only
  after a verified write.
- Recurring page look (D1, D15): the system navigation bar with the
  redesign title instead of Flutter's gradient `ModernAppBar`; GlowCards
  with a tinted 44pt category tile (income green, else accent) and the
  amount in income green or primary text (Flutter: solid red/green 48pt
  tile, amount in the type colour); the Edit/Delete buttons are redesign
  pills, with Delete in danger (Flutter: both secondary). A third
  "Pause"/"Resume" pill and a "Paused" chip carry the approved pause
  (the MVP's swipe action; a ScrollView of cards has none). The empty state
  adds an "Add Recurring" pill (Flutter has no add action on this page;
  the "+" in the bar is the approved one).
- Recurring form: a sheet with the redesign fields instead of Flutter's
  centred dialog, with the Expense/Income toggle when adding (Flutter's
  type is fixed by the caller); an edit keeps the type fixed as Flutter.
- Recurrence glyph on every transaction row with a template id (Home
  Recent activity, Flow preview and Flow SEE ALL too; Flutter shows it only
  on the Recurring card, the Home SEE ALL month list and the category
  drill-in), and ", recurring" in those rows' VoiceOver text.
- Onboarding gate order: the flag is read once per launch, synchronously,
  after the protected-data wait and before the data screens appear (no
  loading spinner, and a prewarmed launch cannot read it as missing). A
  quick action, widget or `budgetapp://` link arriving during the tour stays
  queued and opens when the tour is completed or skipped (Flutter opens the
  form over the tour). Completing sets the flag and closes the tour at once
  (`UserDefaults` writes cannot fail; Flutter closes it in a `finally`), so
  the button never shows Flutter's spinner.
- Onboarding page 3 copy (D2, no More tab): "...and Spend, Flow, and
  Settings (behind the gear on Home) help you understand and manage your
  budget." (Flutter: "Spend, Flow, and More"). Page 1 keeps Flutter's
  privacy sentence until voice ships (the OpenAI mention comes with it).
- Onboarding symbols (D3): `wallet.bifold.fill` (`creditcard.fill` before
  iOS 18), `chart.bar.xaxis.ascending` and `chart.xyaxis.line` stand in for
  Material's `account_balance_wallet`, `add_chart` and `insights` (no plus
  on page 2, no sparkles on page 3), drawn at 40pt so the glyphs are the
  size of Flutter's 52pt icon boxes.
- Onboarding accessibility and large text: the page dots are one adjustable
  VoiceOver element ("Tutorial page, 2 of 3"; swipe up or down to change
  page), and Continue announces the new page (Flutter only labels the dots
  and the pages). At large Dynamic Type sizes a page scrolls (Flutter's
  column overflows), and the Skip and Continue buttons grow with their
  text.
- Both store files unreadable: Swift stops with "Your data couldn't be read"
  until the user chooses to start empty (Flutter silently starts empty). The
  set-aside `.corrupt-*` files are kept in both.
- Unreadable rows (malformed JSON rows in a section) are kept verbatim and
  hidden; Flutter drops them on its next save (transactions) or fails to
  load (recurring, net worth, goals). For categories, one malformed row
  makes Flutter replace the whole list with the built-in seeds, and for
  tags and rules it makes Flutter load an empty list, and its next tag or
  rule save destroys the stored rows; Swift keeps using the readable rows
  (the seeds only when none are readable). A rule whose `priority` is a
  number JSON writes as infinite (`1e400`) is one of those rows for Dart
  (`toInt()` throws); Swift reads it with the largest priority.
- At launch Flutter rewrites the whole `categories` list in canonical
  `toJson` form whenever it differs from the stored JSON (a row missing
  `isBuiltIn`, say). Swift writes the list only when a definition was added
  or a sort order changed, and patches just those keys, so unknown keys
  survive.
- Category edits patch the changed keys of the rows they touch (unknown
  keys, number lexemes and unreadable rows survive). Flutter rewrites the
  whole `categories` list, and on a rename the whole `transactions`,
  `recurringTransactions` and `categorizationRules` sections, in canonical
  `toJson` form. On data Flutter wrote itself the bytes are identical
  (Fixtures/categories).
- Renaming a category (D6) renames the rules whose type is that category's
  type or that apply to any type. Flutter also renames rules of the other
  type: renaming the expense "Gift" moved an income-only "Gift" rule to a
  name the income list does not have, so it stopped suggesting anything.
- A category edit and its rename cascade are one commit of every section
  it changed (`categories`, `transactions`, `categoryBudgetLimits`,
  `recurringTransactions`, `categorizationRules`). Flutter makes up to four
  commits with no rollback, so a failed write, or leaving the page while it
  saved, left a half-renamed state (definition renamed, rows not).
- A category save that fails stays in memory behind the unsaved-changes
  banner (Retry, or the next save, writes it) and the caller shows the
  save-failed toast. Flutter's `CategoryProvider` throws: the page shows
  "Could not update this category", skips the rename cascade, and no banner
  covers the lost change.
- Deleting a tag writes `transactionTags` and `categorizationRules` in one
  commit. Flutter makes two (tags, then rules), so a failed second write
  left rules naming a deleted tag, which makes its backup import refuse the
  file. Flutter also rewrites both lists when nothing changed (an unknown
  tag or rule id); Swift writes nothing then (the stored content is the
  same either way).
- Tag and rule edits patch only what changed: a new row has Dart's `toJson`
  shape, and deleting a tag rewrites just the `tagIds` of the rules naming
  it (unknown keys, number lexemes, non-string `tagIds` elements Dart
  ignores, and unreadable rows survive). Flutter rewrites both lists in
  canonical `toJson` form; on data Flutter wrote itself the bytes are
  identical (Fixtures/tags).
- A tag or rule save that fails stays in memory behind the unsaved-changes
  banner (Retry, or the next save, writes it) and the caller shows the
  save-failed toast. Flutter is silent: the change stays in memory with no
  message and is gone after a relaunch.
- BudgieCore refuses a rule whose trimmed merchant text is empty, whose
  amount bound is not finite, or that names a tag id no tag has. Flutter's
  provider accepts all three: its dialog never sends the first (Add does
  nothing), the second cannot be saved, and the third makes its backup
  import refuse the file.
- Tags & rules page (D1 port of the Material page): padded 16 like
  Flutter's ListView; the title is cardTitle in the navigation bar
  (Flutter: M3 titleLarge AppBar); rows use the redesign's 40pt icon tiles
  (`tag` in accent, `sparkles` in info, Settings' Tags & rules tint) and
  rowTitle / rowSubtitle (Flutter: plain 24pt Material icons, M3 ListTile
  bodyLarge / bodyMedium); the delete icon is `trash` at 20 in a 48pt
  button. The "ADD" buttons, copy, order, empty cards and the rule
  subtitle's raw tokens ("contains · Groceries · 1 tags") are Flutter's.
- Deleting a tag asks first ("Delete tag?", Cancel / Delete), because it
  also removes the tag from every merchant rule; Flutter deletes at once.
  Deleting a rule is instant, as in Flutter.
- New tag dialog: the redesign's centred card with a "Tag name" caption
  above the field (Flutter: an AlertDialog with a hint only) and Cancel /
  Add pills. A duplicate name shows "A tag with this name already exists"
  under the field and keeps the dialog open with the typed name (Flutter
  closes it and shows the message in a SnackBar); after the first Add the
  message follows the text. A blank name closes silently, as in Flutter.
- New merchant rule dialog: the redesign's centred card; Type, Match and
  Category are field-style dropdowns with system menus, and Type and Match
  read "Income" / "Expense" and "Contains" / "Starts with" / "Exact match"
  (Flutter's dropdowns show the raw enum names); the tag chips are the
  transaction form's pills, 8 apart, under a "Tags" caption (Flutter:
  Material FilterChips 4 apart with no caption). Add is shown disabled
  while the merchant text is blank (Flutter's Add is enabled and does
  nothing). A type change resets the category to the new type's first
  unless it has the same name, as in Flutter.
- The tag and rule dialogs, and the tag delete, stay open and inert while
  the change is written (Flutter closes first and writes afterwards).
- VoiceOver reads each rule's delete button as "Delete rule {pattern}"
  (Flutter's tooltip is "Delete rule" on every row) and offers Delete as
  an action on each tag and rule row.
- Category Move up / Move down with archived rows hidden moves the row past
  the previous or next shown row. Flutter moves by one in the full list
  (archived rows included), so a move over a hidden archived row seemed to
  do nothing. With "Show archived" on the moves are Flutter's. Moving an
  unknown id does nothing (Flutter throws "No element"; unreachable from
  the page).
- Categories page (D1 port of the Material page): the add action is only
  the bar's "+" (Flutter also shows a FAB running the same action); the
  title is cardTitle in the navigation bar (Flutter's AppBar title is M3
  titleLarge, 22 / w400); the row menu is the system `Menu` (Flutter's
  Material popup menu), with the same items and order.
- Category editor: the redesign's centred card (`budgieDialog`, as the
  Goals form) instead of Material's AlertDialog: the title is centred in
  goalTitle (Flutter: headlineSmall, left), "Name" is a caption above the
  field (Flutter: a floating label), and Cancel / Add | Save are pills
  (Flutter: a text and a filled button). The icon and colour choice
  buttons, their sizes, colours and order are Flutter's, and so is the
  wrap: the grid is capped at five buttons a row (icons 5/5/5/3, colours
  5+3), though the wider card would fit six. The Name field's return key
  is Done and only dismisses the keyboard, as Flutter's.
- Category editor errors show inline under the Name field and keep the
  dialog open with the typed name: "Enter a category name" (Flutter's
  validator) and, before saving, the provider's "A category with this
  name already exists", which Flutter shows in a SnackBar after the dialog
  has closed (the input lost). After the first Save the message follows
  the text as it is edited (Flutter re-validates only on Save). The
  dialog stays open and inert while the edit saves, and closes on a failed
  write with the save-failed toast (the change is kept behind the unsaved
  banner).
- The category editor's colour rows are 8pt apart, like the icon rows
  (Flutter's colour `Wrap` sets no run spacing, so its two rows touch).
- Refused category row actions ("At least one category must remain
  active") show the neutral toast (below), Flutter's default SnackBar
  look; the editor's errors stay inline (above).
- Category icons (D3: SF Symbols tinted with Flutter's colours):
  `car.fill` and `pawprint.fill` stand in for the filled Cupertino
  `car_detailed` and `paw`, the other 16 are the outline SF counterparts
  (`money_dollar` is `dollarsign`, clearly taller than Cupertino's small
  dollar; `person_2` is thinner in Cupertino). The Categories page draws
  them at 17pt (row tiles, the editor grid) and the row menu's bold
  `ellipsis` at 17pt, where they measure within a pixel or two (at 3x) of
  Flutter's 20pt Cupertino glyphs and 24pt `more_horiz` (SF Symbols draw
  about 18% larger at the same size); the editor grid uses the regular
  weight, closer to Cupertino's strokes. The row tiles keep the shared
  `IconTile`'s medium weight, and every other screen's category tile
  (Home, Spend, Flow, the form) still draws the symbol at the shared
  `IconTile` 20pt, about 18% larger than Flutter's.
- Categories page, platform look: "Show archived" is the system switch
  (the iOS 26 track is about 62 x 28 against CupertinoSwitch's 51 x 31;
  its right edge lines up with Flutter's), and the row cards are the
  shared `GlowCard` (continuous corners and a fainter border than
  Flutter's circular radius-26 arcs).
- `Toast.Style.neutral` stands in for Flutter's default SnackBar with the
  primary text colour as the fill and the page background as the text
  (M3 inverseSurface / onInverseSurface from the seed are close but not
  those tokens), floating with radius 12 like the other toasts (Flutter's
  default is fixed, full width, radius 4).
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
  sort); Dart's sort is not stable from 34 options, so their relative order
  can differ (switch to `DartSort`, see the tie-order note above).
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
- Flow SEE ALL: dragging the page down into the keyboard dismisses it
  interactively (the decimal pad has no return key); scrolling up leaves it
  up, and rows scrolled above it still swipe to delete. Flutter keeps it up.
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
- Goals glyphs are sized by the rendered tick / dots, not the point size:
  SF `checkmark` medium at 20 (ring) and 25 (celebration) and `ellipsis`
  medium at 12 match Material's `check_rounded` 28 / 34 and
  `more_horiz_rounded` 18 at w500 (18.5 / 22.5 / 11.5pt wide), in boxes of
  Flutter's icon sizes.
- Toasts: the text and Retry use `onAccent` (#0A0A12 dark, white light)
  for Flutter's M3 `onInverseSurface` snackbar text (a dark neutral in
  dark mode), not white. A toast shown again while it is up restarts its
  4s (Flutter queues it).
- Month chip strip (Worth, Home's SEE ALL): the selected chip is centred
  when the strip appears, as Flutter's `MonthSelector` does after its first
  frame.
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
- Worth editor: the banner and Cancel / Save stay in place and only the
  fields scroll when the keyboard or a large text size leaves too little
  room (Flutter scrolls the whole dialog, buttons included). The account
  name glyph is SF `wallet.bifold` (iOS 18+; `creditcard` on iOS 17) for
  Material's `account_balance_wallet_rounded`.
- Worth growth chart hover card: its text stops growing at the xxxLarge
  Dynamic Type size so the card fits the 180pt chart (Flutter's overflows).
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

- Settings is pushed from the Home gear (D2): the system navigation bar
  (back button and swipe) carries the "Settings" title (26/800) at the
  leading edge; there is no floating-dock bottom padding.
- The `appSettings` section keeps unknown keys and the stored key order
  when Swift rewrites it (Dart's `_persistAtomic` writes only its five keys,
  in its own order, dropping anything else).
- The Home Screen widgets honour Hide balances (D12): the app writes
  `budgieHideBalances` (Bool) to the App Group at launch, with every cash
  flow sync and on every Hide balances change, and the widget shows
  "••••" in a neutral colour instead of the cash flow. Flutter's widget
  never masks; it reads only `cashFlow` / `cashFlowMonth`, which Swift
  still writes, so a downgrade just shows the amount again.
- Settings setters (currency, number format, app lock, lock delay, hide
  balances) change memory, then the preference mirror, then the
  `appSettings` section, awaited, and return the verified result, with
  Flutter's guards (Fixtures/settings/setters.json). The page updates as
  soon as memory changes (Flutter after the write), and every screen
  re-formats at once (Flutter's other tabs only on their next rebuild). A
  failed write keeps the change in memory behind the unsaved banner, with
  no toast (Flutter's setter throws, skips its formatter sync and notify,
  and the change reverts on relaunch because the stale section beats the
  newer preference).
- App lock: turning the switch on asks for Face ID / the passcode first
  ("Turn on App Lock") and keeps the open session unlocked (the switch
  stays on while the prompt is up, and the privacy cover is held back until
  the scene is active again); a device
  without a passcode gets "Set a passcode in the Settings app to use App
  Lock." (Flutter locks the session at once and shows its lock screen).
  The relock clock starts only when the app goes to the background, not on
  `inactive`, so the enable prompt and Control Centre do not relock with a
  0-second delay (Flutter counts any inactive blip).
- Settings choice sheets (Base currency, Number format, Lock delay) use the
  redesign sheet chrome (44x4 handle, card border) instead of the plain
  Material sheet (32x4 handle in a 48pt strip); content-sized up to 75% of
  the screen as in Flutter. Picking a row awaits the setter, then closes
  the sheet (Flutter closes first). The current row has the selected trait.
- Settings switches (App lock, Hide balances) are systemGreen like
  Flutter's Cupertino switch (the app-wide accent tint is overridden);
  VoiceOver reads each switch by its title with the subtitle as the hint.
  Tappable rows read "title, subtitle" once (label and value; Flutter
  merges its button label with the child texts), and the section eyebrows
  are headers.
- Settings rows whose features land in Phase 3 (Import from CSV, Export
  backup, Import backup) keep Flutter's icon and copy but open an
  "upcoming update" page.
- Settings > ABOUT also lists Data diagnostics and Licences (the SIL OFL
  texts the bundled fonts require), and Design gallery in debug builds;
  Flutter has only Version. The version is read from the bundle at once
  (Flutter shows "Budgie 2.0.0" for a frame while PackageInfo loads).
- Export as CSV shows "Transactions exported successfully!" only when the
  share sheet completed (Flutter shows it after any dismissal, a cancel
  included); the spinner shows while the share sheet is open, as in
  Flutter.
- The Theme pills slide one accent capsule between segments (the shared
  `SegmentedPills`); Flutter fades each segment's fill in place.
- Settings SF Symbols stand in for Material Symbols: `square.on.circle`
  (category), `sparkles`, `banknote` (payments), `globe` (language),
  `lock`, `timer`, `eye.slash`, `repeat`, `arrow.down.to.line`
  (file_download), `arrow.up.to.line` (file_upload), `icloud.and.arrow.up`
  (backup), `arrow.counterclockwise.circle` (settings_backup_restore),
  `info.circle`, `moon` (dark_mode), `chevron.right`.

### Backup export and restore (D10)

The file format is Flutter's: a Swift export equals Flutter's export of the
same store byte for byte, and each app restores the other's files
(Fixtures/backup; `verify_swift_output_test.dart` restores Swift exports
through Flutter's own restore chain). Only two backup schemas ever
existed, 1 (six `data` keys, July 2026) and 3; there is no "v2".

- Restore is one store commit of all ten sections (Flutter makes about
  nine, with no rollback). The app swaps memory only after the verified
  commit; on failure nothing changes and nothing is flagged unsaved
  (Flutter can leave a partial restore and still say "Backup restored").
- A safety copy of the store files and preferences is written to
  `Application Support/pre-restore/<stamp>/` first, and the restore does
  not run if it cannot be made. The newest three are kept, pruned only
  after a successful restore. Flutter has none (its `.backup.json` ends up
  holding a mid-restore generation). The copy also keeps any stored rows
  neither app can read, which the restore replaces (as Flutter).
- A `data` key that is absent or null leaves its section or setting
  unchanged: schema-1 files keep categories, tags, rules and the five
  settings (and their preferences). Flutter resets them to the built-ins,
  none, USD, Match device, lock off, 60 s and hide off, and empties any
  list a hand-edited file leaves out. `localeOverride` is the exception:
  present and null means Match device. `{"schemaVersion":3,"data":{}}` is
  accepted as in Flutter, and so changes nothing but the recurring
  generator and legacy categories.
- The confirmation keeps Flutter's copy verbatim (no pluralisation; counts
  are the decoded sizes, budgets <= 0 and duplicate-id rows included, 0 for
  a key the file leaves out) and, when the file leaves something unchanged,
  adds "Your categories, tags, rules and settings are kept." naming what is
  actually kept.
- The recurring generator runs on the restored data before the commit, so
  its rows and cursors are in the same commit (Flutter runs it after the
  restore, one commit per row). The launch pass that materialises legacy
  categories also runs in the restore (Flutter runs it at the next launch).
  The end state equals Flutter's after its next launch.
- Two files Flutter fails on without a `FormatException` are reported as
  "This backup file is corrupt or incomplete.": `autoLockTimeoutSeconds`
  of `1e999` (Flutter: "Unsupported operation: Infinity or NaN toInt") and
  a rule `minimumAmount`/`maximumAmount` of `±1e999` (Flutter shows the
  dialog, then fails its first write with "Converting object to an
  encodable object failed: Infinity"). Nothing changes in either app.
- JSON nested more than 128 levels deep is "not a valid Budgie backup
  file" (the parser's recursion cap); Flutter accepts such a file when the
  deep part is under a key it ignores.
- `appSettings` keeps unknown keys (the section is patched); Flutter
  writes a fresh five-key object.
- Export: `exportedAt` and the file name come from one clock read (Flutter
  reads the clock twice). Rows the Swift store keeps but cannot read are
  left out, as Flutter, which cannot load them either.
- `selectedNetWorthMonth` is neither exported nor restored (as Flutter):
  the current one is kept even if it points outside the restored data.
- A lone UTF-16 surrogate in a category name that the launch pass creates
  (from a transaction, template or budget key) is written as U+FFFD
  (Swift strings cannot hold one); Flutter keeps it. Rows read from a
  store or a backup keep theirs.

Flutter behaviour kept on purpose (D6 candidates; fixing them would change
what Flutter reads or shows):
- The file's `app` and `appVersion` are never checked.
- Duplicate category names, blank names, unknown category `type` strings
  (read as expense) and rules naming a missing category are accepted;
  orphan `tagIds` on transactions are kept.
- `autoLockTimeoutSeconds` has no upper bound (1e30 becomes the largest
  int, which never locks).
- Goals without dates get the restore time (`DateTime.now()` at decode);
  goals and tags without ids get fresh ones.
- Restoring theme `system` over `system` writes no preference.
- A setting equal to its current value is still mirrored to its preference.


- A sheet open when the app goes to the background (e.g. the transaction
  form) is not covered by the App Lock privacy cover.
- No iPad layout (the Flutter app is iPhone-only too).

## Platform

- Minimum iOS 17 (Flutter: iOS 15). Users on iOS 15/16 stay on the last
  Flutter release.
- Quick action icons use SF Symbols (the Flutter build referenced asset
  names that did not exist, so its items had no icon).
