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
| `logic_fixtures_test.dart` | `Fixtures/logic/`: dates, generator, safe-to-spend per time zone (`tz/<zone>/`); CSV bytes, money formatting, number/string encoding, ordering |
| `format_fixtures_test.dart` | `Fixtures/logic/date_formats.json` (every en_US intl pattern the app uses) and `strings.json` (Dart `trim`, `toLowerCase`, `==`, `contains`, `startsWith`, `compareTo`); `lower.json` (`toLowerCase` of every scalar that changes: the VM's Unicode 5.1 tables) |
| `worth_fixtures_test.dart` | `Fixtures/worth/tz/<zone>/mutations.json`: net worth mutations through a real store (New York, Santiago); `formatting.json`: Worth display strings, amount field, chart scales |
| `goals_fixtures_test.dart` | `Fixtures/goals/tz/<zone>/mutations.json`: savings goal mutations (edits through the page's edit path) through a real store (New York, Santiago); `derived.json`: progress, status, pace copy, sort and summary over a table of goals and pinned clocks |
| `settings_fixtures_test.dart` | `Fixtures/settings/`: `labels.json` (the real Settings page's Currency, Number format, App lock and Lock delay subtitles for stored values in and outside its lists), `sheets.json` (the three choice sheets' rows, tick and stored value per row), `setters.json` (`AppSettingsProvider` setter calls through a real store and SharedPreferences) |
| `categories_fixtures_test.dart` | `Fixtures/categories/mutations.json`: `CategoryProvider` add/archive/move and the Categories page's save path (update + rename cascade through `TransactionModel`, `RecurringTransactionModel`, `CategorizationProvider`; the page's private orchestration is copied verbatim and a canary drives the real page to catch drift) through a real store: errors, written sections, section bytes, memory; D6 rule steps record Dart's real rules and realign to Swift's. `catalog.json`: icon registry order, colour tokens |
| `tags_fixtures_test.dart` | `Fixtures/tags/mutations.json`: `CategorizationProvider` addTag/deleteTag/addRule/deleteRule through a real store with seeded UUIDs (canonical shapes and lexemes, Unicode duplicate names, the typical store's rows, 33/34/40/70 tied rules for Dart's sort, foreign rows, Dart's all-or-nothing load of a malformed row): errors, commit counts, changed section bytes, memory in the `rules` getter's order, `suggest` probes; a canary drives the real page's rule dialog and duplicate-tag snackbar |
| `verify_swift_output_test.dart` | `$SWIFT_OUT/dart-verification.json`; fails on any rejected, skipped or reset data, or on budget limits, net worth, goals, settings, theme mode, categories (and what the launch pass adds) or the category names of transactions, templates and rules that differ from what Swift wrote |

`expected.json` records, for the untouched input: the Dart store load
(revision, canonical sections checksum/length, and the JSON itself when under
200 kB), files and preferences after load, the effect of one more commit, and
a full app launch (`_initializeApp` order) before and after recurring
generation, summarised by `model_summary.dart`. The launch clock is
`2026-09-28T09:15:30.250125` local; store fixtures are generated with
`TZ=America/New_York`.

"Canonical sections" = Dart `jsonEncode(jsonDecode(payload))`. The Swift side
reproduces it with its canonical encoder (MIGRATION_SPEC section 5).
