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
| `format_fixtures_test.dart` | `Fixtures/logic/date_formats.json` (every en_US intl pattern the app uses) and `strings.json` (Dart `trim`, `toLowerCase`, `==`, `contains`, `startsWith`, `compareTo`) |
| `verify_swift_output_test.dart` | `$SWIFT_OUT/dart-verification.json`; fails on any rejected, skipped or reset data |

`expected.json` records, for the untouched input: the Dart store load
(revision, canonical sections checksum/length, and the JSON itself when under
200 kB), files and preferences after load, the effect of one more commit, and
a full app launch (`_initializeApp` order) before and after recurring
generation, summarised by `model_summary.dart`. The launch clock is
`2026-09-28T09:15:30.250125` local; store fixtures are generated with
`TZ=America/New_York`.

"Canonical sections" = Dart `jsonEncode(jsonDecode(payload))`. The Swift side
reproduces it with its canonical encoder (MIGRATION_SPEC section 5).
