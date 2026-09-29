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
| Savings goals UI | `savingsGoals` | Read (safe-to-spend reserves goal contributions exactly like Flutter); no UI to view/edit. |
| Net worth editing (add account, update balance, carry forward, delete snapshot) | `netWorthEntries`, `selectedNetWorthMonth` | Read-only list, totals and chart. |
| Insights | `local_insights_*` prefs | Not shown; prefs untouched. |
| Categorization rules, tags | `categorizationRules`, `transactionTags`, `Transaction.tagIds` | The transaction form applies rules and toggles tags; no rule or tag management UI yet. |
| Category management (add, rename, archive, reorder) | `categories` | Launch materialises legacy names (transactions, templates, budget keys) and normalises sort orders exactly like Flutter; no editing UI yet. |
| Onboarding tour | `flutter.onboarding_completed` | Never shown; flag untouched. |
| Backup export/import (JSON envelope v3) | files chosen by the user | Not available. CSV export is. |
| CSV import | ledger | Not available. |
| Spend (category donut), Flow (history charts, year-over-year) tabs | derived | Not available; the Transactions page (Home > SEE ALL) lists transactions. |
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

## Deliberate differences (approved)

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
- Budget limit sheet (D6): the limit parses with the number format's
  separators ("1.500,00" is 1500 under de_DE; Flutter strips `[^0-9.]` and
  reads 1.5). A lone grouping separator not followed by three digits is
  read as the decimal key of a keyboard in another locale ("12,5" is 12.5
  under en_US; Flutter reads 125). Only digits and separators are accepted:
  Flutter saved "-5" as 5 and "1e3" as 13; Swift rejects both.
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
- Flow SEE ALL amount filters: "NaN", "Infinity", "-Infinity" and overflowing
  input ("1e400") leave the bound unset (`TransactionFilter.parseAmount`);
  Flutter keeps them (NaN marks the filter active but excludes nothing, an
  infinite minimum hides every row).
- Flow SEE ALL category options: names whose lower-case forms are equal
  ("Groceries" / "groceries") keep first-appearance order (Swift stable
  sort); Dart's sort is not stable above 32 options, so their relative order
  can differ.
- Safe-to-spend breakdown sheet: redesign sheet chrome (card colour, 44x4
  grab handle, 28 radius) instead of Material's default sheet and 32x4
  handle; the divider uses the border token.
- Quick-expense sheet: a native sheet at 66% or 90% height; Flutter's
  draggable sheet also shrinks to 36% and closes there.

## Known MVP limitations

- A sheet open when the app goes to the background (e.g. the transaction
  form) is not covered by the App Lock privacy cover.
- Net Worth is read-only; the selected net worth month is not persisted.
- No iPad layout (the Flutter app is iPhone-only too).

## Platform

- Minimum iOS 17 (Flutter: iOS 15). Users on iOS 15/16 stay on the last
  Flutter release.
- Quick action icons use SF Symbols (the Flutter build referenced asset
  names that did not exist, so its items had no icon).
