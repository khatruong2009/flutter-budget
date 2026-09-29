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
| Budgets UI (limits, progress, edit) | `categoryBudgetLimits` | Read (safe-to-spend flexible reserve); no UI. |
| Net worth editing (add account, update balance, carry forward, delete snapshot) | `netWorthEntries`, `selectedNetWorthMonth` | Read-only list, totals and chart. |
| Insights | `local_insights_*` prefs | Not shown; prefs untouched. |
| Categorization rules, tags | `categorizationRules`, `transactionTags`, `Transaction.tagIds` | The transaction form applies rules and toggles tags; no rule or tag management UI yet. |
| Category management (add, rename, archive, reorder) | `categories` | Launch materialises legacy names (transactions, templates, budget keys) and normalises sort orders exactly like Flutter; no editing UI yet. |
| Onboarding tour | `flutter.onboarding_completed` | Never shown; flag untouched. |
| Backup export/import (JSON envelope v3) | files chosen by the user | Not available. CSV export is. |
| CSV import | ledger | Not available. |
| Spend (category donut), Flow (history charts, year-over-year) tabs | derived | Not available; the Transactions page (Home > SEE ALL) lists transactions. |
| Hide balances toggle, locale override picker, auto-lock timeout picker | `appSettings` | Honoured when set by the Flutter app; no toggles in the MVP. |
| Month picker limited to the selected year | UI state | MVP month selector moves across years. |

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

## Deliberate differences (approved)

- Transactions page: when the selected month loses its last transaction,
  the page falls back to the newest month with data (Flutter keeps the
  stale month selected, with no chip highlighted and a "No Transactions"
  list).
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
