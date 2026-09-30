# Parity harness

Dart tests that run the **real** Flutter code (`budget_app/`) to produce the
fixture corpus in `native/Fixtures/`, and to verify that files written by the
Swift app load in the Flutter app.

Nothing in `budget_app/` is touched. `run.sh` exports `budget_app` at `HEAD`
with `git archive` into a scratch directory, adds a stub `.env` (dummy key;
the app bundles `.env` as an asset), rewrites `DateTime.now()` to an
injectable `parityNow()` so fixtures are deterministic, copies `parity/*.dart`
to `test/parity/`, and runs `flutter test` there.

```bash
native/ParityHarness/run.sh generate            # rewrite native/Fixtures/
PARITY_ONLY=format_fixtures_test.dart native/ParityHarness/run.sh generate  # one generator only
SWIFT_OUT=/path native/ParityHarness/run.sh verify
```

| File | Produces |
|---|---|
| `store_fixtures_test.dart` | `Fixtures/store/<scenario>/{input/, prefs.json, expected.json}`: typical, 10k, old schema, unknown data, 20 damaged-file states |
| `legacy_fixtures_test.dart` | `Fixtures/legacy/<scenario>/...`: v1 envelope, v1 backup, bare keys, mixed, settings-only, starting balances |
| `logic_fixtures_test.dart` | `Fixtures/logic/`: per time zone (`tz/<zone>/`; New York, UTC, Lord Howe, Kolkata, Santiago, Beirut) `dates.json`, `generator.json`, `safe_to_spend.json`, `safe_to_spend_random.json`, plus the midnight-DST files `generator_dst.json` (weekly, biweekly and monthly templates stepping across Santiago's 2026-09-06 gap and 2026-04-04 fold and Beirut's 2026-03-29 gap and 2026-10-24 fold, clocks on both sides, dates as epoch microseconds too) and `safe_to_spend_dst.json` (rows, templates, goals and as-of clocks on, before and after each gap/fold, at both instants of a fold wall time, plus 120 seeded cases on the transition days); CSV bytes, money formatting, number/string encoding, ordering |
| `format_fixtures_test.dart` | `Fixtures/logic/date_formats.json` (every en_US intl pattern the app uses) and `strings.json` (Dart `trim`, `toLowerCase`, `==`, `contains`, `startsWith`, `compareTo`); `lower.json` (`toLowerCase` of every scalar that changes: the VM's Unicode 5.1 tables) |
| `worth_fixtures_test.dart` | `Fixtures/worth/tz/<zone>/mutations.json`: net worth mutations through a real store (New York, Santiago, Lord Howe, Kolkata, UTC; the `dst` scenario has New York, Santiago and Lord Howe gap and fold dates); `formatting.json`: Worth display strings, amount field, chart scales |
| `goals_fixtures_test.dart` | `Fixtures/goals/tz/<zone>/mutations.json`: savings goal mutations (edits through the page's edit path) through a real store (New York, Santiago, Lord Howe, Kolkata, UTC; the `dst` scenario and the derived table include New York, Santiago and Lord Howe gap and fold dates); `derived.json`: progress, status, pace copy, sort and summary over a table of goals and pinned clocks |
| `settings_fixtures_test.dart` | `Fixtures/settings/`: `labels.json` (the real Settings page's Currency, Number format, App lock and Lock delay subtitles for stored values in and outside its lists), `sheets.json` (the three choice sheets' rows, tick and stored value per row), `setters.json` (`AppSettingsProvider` setter calls through a real store and SharedPreferences) |
| `categories_fixtures_test.dart` | `Fixtures/categories/mutations.json`: `CategoryProvider` add/archive/move and the Categories page's save path (update + rename cascade through `TransactionModel`, `RecurringTransactionModel`, `CategorizationProvider`; the page's private orchestration is copied verbatim and a canary drives the real page to catch drift) through a real store: errors, written sections, section bytes, memory; D6 rule steps record Dart's real rules and realign to Swift's. `catalog.json`: icon registry order, colour tokens |
| `tags_fixtures_test.dart` | `Fixtures/tags/mutations.json`: `CategorizationProvider` addTag/deleteTag/addRule/deleteRule through a real store with seeded UUIDs (canonical shapes and lexemes, Unicode duplicate names, the typical store's rows, 33/34/40/70 tied rules for Dart's sort, foreign rows, Dart's all-or-nothing load of a malformed row): errors, commit counts, changed section bytes, memory in the `rules` getter's order, `suggest` probes; a canary drives the real page's rule dialog and duplicate-tag snackbar |
| `verify_swift_output_test.dart` | `$SWIFT_OUT/dart-verification.json`; fails on any rejected, skipped or reset data, or on budget limits, net worth, goals, settings, theme mode, categories (and what the launch pass adds), transactions (every field, after the edits and a CSV import) or the category names of transactions, templates and rules that differ from what Swift wrote, and insight preferences and cards (the real `LocalInsightsSection` is pumped) |
| `backup_fixtures_test.dart` | `Fixtures/backup/`: `dart_sort.json` (Dart `List.sort` permutations on random lists with ties, for `DartSort`), `indent_vectors.json` (`JsonEncoder.withIndent('  ')`); per zone (New York, Lord Howe, UTC, Santiago) `tz/<zone>/`: `encode.json` (`encodeBackup` of store fixtures and hand-made stores), `export_flow.json` (the real Settings page export through fake share/path providers), `decode.json` (`decodeBackup` over a 150-file corpus: message, or the decoded rows and settings), `restore.json` (the real Settings page import through a fake file picker: dialog, snackbar, the store after a relaunch, preferences, theme; for files that leave keys out, also the same file with those keys filled from the current store, which is what Swift's D10 restore must equal) |
| `home_fixtures_test.dart` | `Fixtures/home/` (New York; everything except `home/tz/`, which belongs to `home_page_fixtures_test.dart`): budget mutations and rows, `percentDelta` table, rule matching, `tryParse` |
| `spend_fixtures_test.dart` | `Fixtures/spend/` (New York): the real Spend page's breakdowns, donut and strings over the datasets |
| `flow_fixtures_test.dart` | `Fixtures/flow/tz/<zone>/` (New York, UTC, Lord Howe, Kolkata, Santiago): per dataset the real Cash Flow page's series, windows, metrics, bars, year over year, trend curve and SEE ALL filter results; `filter_specs.json` (filter matrix, including date ranges that start or end on Santiago's and Beirut's gap and fold days); the `typical` dataset has rows on the Santiago gap (2026-09-06 00:00-01:00) and fold (2026-04-04 23:00-24:00) |
| `csv_import_fixtures_test.dart` | `Fixtures/csvimport/`: `parser.json` (csv 6.0.0 `CsvToListConverter` with the app's settings on a corpus and 3000 seeded random strings, and `utf8.decode(allowMalformed: true)` on 2000 random byte strings), `page.json` (the real Settings page "Import from CSV" through a fake file picker: picker arguments, dialog, SnackBar text and colour, store written; it also checks the page shows the copy the generator's verbatim `messages()` computes); per zone (New York, UTC, Lord Howe, Kolkata, Santiago) `tz/<zone>/import.json`: a 47-file adversarial corpus through a real store (launch, `utf8.decode`, `parseTransactionsCsv`, `importTransactions`, relaunch: the error or summary, the copy, the new transaction rows with ids as `<new:N>`, the categories the relaunch materialises) and 600 seeded random files parsed against random existing rows |
| `insight_fixtures_test.dart` | `Fixtures/insights/tz/<zone>/` (New York, UTC, Lord Howe, Kolkata, Santiago): `cases.json` (named scenarios at each rule's thresholds) and `random.json` (seeded differential) from the real `InsightEngine`; `prefs.json` (the real `LocalInsightsSection` pumped with stored preferences, driven through Snooze/Dismiss and reloaded at later clocks: cards and preferences after each step); `Fixtures/insights/slugs.json` (`_slug`, read back from goal ids) |
| `launch_fixtures_test.dart` | (chunk B) `Fixtures/launch/tz/<zone>/<scenario>.json` (New York, UTC, Lord Howe, Kolkata, Santiago, Beirut): a full launch (`_initializeApp` order, generator included) of the store fixtures, summarised |
| `transactions_fixtures_test.dart` | (chunk C) `Fixtures/transactions/tz/<zone>/`: `addTransaction`/`updateTransaction`/`deleteTransaction` and recurring template add/update/delete through a real store (New York, Santiago, Lord Howe) |
| `recurring_form_fixtures_test.dart` | (chunk C) `Fixtures/recurring_form/tz/<zone>/validation.json`: the recurring form's validation copy and start-date rule (New York, Santiago, Lord Howe) |
| `home_page_fixtures_test.dart` | (chunk C) `Fixtures/home/tz/<zone>/page.json`: the real Spending page's hero, gauge, chips, safe-to-spend card and budget rows (New York, Santiago); `home_fixtures_test.dart` leaves `home/tz/` alone |
| `month_list_fixtures_test.dart` | (chunk C) `Fixtures/monthlist/tz/<zone>/{page,drillin}.json`: the SEE ALL month list and the Spend category drill-in page (New York, Santiago) |
| `voice_request_fixtures_test.dart` | (chunk C) `Fixtures/voicerequest/tz/<zone>/request.json`: the voice system prompt, chat body and transcription request (New York, Santiago) |
| `voice_fixtures_test.dart` | `Fixtures/voice/tz/<zone>/parse.json` (New York, UTC, Lord Howe, Kolkata, Santiago, Beirut): the real `VoiceExpenseService.parseVoiceJson` over raw model replies (fences, non-objects, error key, type and category variants, amounts as numbers and strings, descriptions with Dart's trim set, dates at the 90-day boundary, `Z` and offsets, DST gaps and overlaps), one case per line: outcome as microseconds, IEEE amount bits, or the error kind with its transcript |

`expected.json` records, for the untouched input: the Dart store load
(revision, canonical sections checksum/length, and the JSON itself when under
200 kB), files and preferences after load, the effect of one more commit, and
a full app launch (`_initializeApp` order) before and after recurring
generation, summarised by `model_summary.dart`. The launch clock is
`2026-09-28T09:15:30.250125` local; store fixtures are generated with
`TZ=America/New_York`.

"Canonical sections" = Dart `jsonEncode(jsonDecode(payload))`. The Swift side
reproduces it with its canonical encoder (MIGRATION_SPEC section 5).
