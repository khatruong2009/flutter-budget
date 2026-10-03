# Flutter to Swift migration safety audit — 2026-09-30

Status: automated checks passed; **release sign-off still requires a physical
iPhone upgrade test and verification of the actual distribution archive**.
No test suite can establish a 100% guarantee for every device or recover
data that was already unrecoverably damaged.

Audited source: `claude/swiftui-mvp-migration-71aa05`, base commit
`41139b5ea1720d37fe6799bebc47b4e0162d130f`, plus the local changes from
this audit. The Swift code is in that worktree, not the main Flutter checkout.
All test data was synthetic. No real user data or physical device was altered.

## Three checks

1. **Identity and source review.** Flutter and Swift project configurations
   use `com.khatruong.budgetbuddy`, team `TJ37GFZKW2`, and App Group
   `group.com.khatruong.budgetbuddy`. Both use
   `Library/Application Support/financial_store/financial_store_v2.json`
   and its backup. Preference reads use the Flutter `flutter.` keys in the
   same persistent domain. Module `Runner` and the scene configuration are
   retained. This verifies source configuration, not a signed release IPA.
2. **Automated fault and compatibility tests.** Full Swift suite: 379 tests
   passed, including seven new migration audit tests and the enabled
   Swift-output corpus. Flutter loaded all 67 Swift-written cases with no
   reported problems. Flutter analysis: no issues; full Flutter suite: 390
   tests passed. Flutter commands ran in a git-archive copy with a dummy
   voice key; the copy also included the parent `.gitignore` required by
   its configuration test. Original Flutter source was unchanged.
3. **Installed-app upgrade and rollback.** Fresh Flutter and Swift Debug
   builds were installed over one another without uninstalling on the
   dedicated `Budgie-Migration-Audit` simulator (iOS 27).
   Evidence: `rehearsal/20260930-142713/report.json` and
   `preservation-audit.json`. S1, S3, S4 and S5 passed; every Dart problem
   list and every Swift/Dart comparison was empty. All 52 additional
   preservation checks passed. Every original value in all 10 financial
   sections survived; the only addition was a category definition for an
   existing padded category label. Original Flutter files were preserved
   byte for byte in the pre-native copy, and Flutter rollback retained
   Swift's saved file byte for byte. Every safety-copy manifest hash verified.
   The simulated lock lasted 15 seconds; first observed writes were at
   20.6 seconds, after unlock.

Additional installed-app regression run `rehearsal/20260930-144200`:
S5 with valid GBP currency preferences and S6 with malformed ledger/envelope
preferences both passed. Damaged v2 files remained blocked; malformed legacy
values were retained unchanged both in preferences and in the SHA-256-verified
safety copy. No replacement store or ready-state summary was written for
these failures. The recovered S5 backup still matched the Flutter reader.

## Gaps reproduced and fixed

- With both v2 files damaged, currency settings or stale bare keys could
  bypass the blocking screen and create a replacement empty/older ledger.
  Corrupt files now block before any preference fallback, including after
  a relaunch. The originals remain set aside and in the safety copy.
- Malformed legacy section keys could be deleted after a settings-only or
  partial migration. The app now blocks before committing or deleting
  keys if it cannot recover their sections. An unreadable/unsupported v1
  envelope with no valid envelope backup also blocks, even when unrelated
  bare sections/settings are readable.
- When no primary file existed, an old safety copy could be reused after
  legacy preferences changed. Reuse now checks source files and both
  preference exports. It also detects a changed recovery backup and verifies
  the saved copy's manifest hashes rather than trusting its COMPLETE marker.
- Successful writes checked checksum/revision but not exact intended bytes.
  They now read back and compare the full file; a valid different payload
  with the same revision is a failed save.
- Safety-copy file flush failures were ignored. Copies and metadata now
  verify reads and require successful full-sync or fsync before completion.
- The unreadable-data screen allowed starting without recovery with one tap.
  It now offers Retry and requires a second confirmation to proceed.

The first three new regression tests failed against the original code
(25 recorded issues) and passed after the fixes. Existing parity tests now
explicitly assert the safer blocking behavior for damaged inputs, while
continuing to compare successful migrations against Flutter.

## Additional local audit requested before device testing

Audited base: `f38383f6aa2894854617bb2ca29f7928f9faad6d`, plus the
changes in this audit. This pass used scratch storage and the dedicated
`Budgie-Migration-Audit` simulator only. No physical device or personal
financial data was accessed.

Nine new core tests and two app-bootstrap tests extend the previous audit.
Before the fixes, four core regressions failed with 17 recorded issues;
the app-bootstrap test also failed for all ten known section container types.
The reproduced gaps and fixes are:

- Repeated corruption at the same clock time could replace previous
  `.corrupt-*` files through POSIX rename. Unique suffixes now preserve every
  original across repeated incidents, including when the clock repeats.
- A primary with a valid header/checksum but an undecodable payload could
  overwrite a usable backup on the next commit. Backup replacement now
  requires a successfully decoded primary, preserving the usable backup.
- If both files disappeared after a verified native save, settings-only
  fallback could silently create a replacement empty store. The existing
  native save marker now blocks this path. Explicitly choosing to start
  fresh after acknowledged corruption clears the marker while retaining
  the set-aside files; that intentional recovery flow is separately tested.
- Protection availability was checked before staging but not before the
  rename. A new check after staging blocks either backup or primary rename
  if protection becomes unavailable. The typed protected-data error survives
  so startup can wait/retry rather than misreporting a successful save.
- Valid JSON with unsupported known-section container types could load as
  empty and later be overwritten by model defaults or startup migrations.
  App bootstrap now blocks before model loading or automatic writes. The
  original primary and complete migration copy remain byte-identical for
  all ten tested section types. Missing/null sections still receive normal
  Flutter-compatible defaults; individual unreadable array rows stay raw.
- `ENOTDIR` is now a read failure, rather than being reported as absence.
  A real filesystem test verifies the misplaced file is unchanged.

Additional tests cover all six injected initial-migration interruptions and
all six backup-recovery interruptions (crash, partial write and full disk at
staging/rename). Original preferences or recovery backup remain intact,
and a subsequent launch recovers the expected complete snapshot. A real
disk ledger containing 20,000 records preserves every record, numeric
lexeme, Unicode description, unknown record field and unknown section;
the previous primary becomes an exact-byte backup. App-level tests confirm
unreadable rows in all seven list sections survive startup, editing and two
relaunches, while unknown settings/budget/feature values remain unchanged.

Completed suites: **398 core tests in Debug**, **398 in Release**, **124
app-model tests**, **390 Flutter tests**, and clean Flutter analysis.
Release here means optimized core tests, not a signed distribution app.

Local archive inspection found 55 matching Flutter archives. The latest
archive (2026-09-27, 3.4.0 build 1) reports the matching bundle identifier,
team, application identifier and App Group. Its local development signature
trust check returned `CSSMERR_TP_NOT_TRUSTED`; this is not verification of a
distributed Flutter binary or of the final Swift release candidate. Actual
distribution signing and physical-device update behavior remain unverified.

Compatibility rerun: **68 report cases per zone (204 total: 198 stored-data
cases and six insight-view comparisons)** passed through the real Flutter
models in New York, Santiago and Beirut. Each zone's Flutter
report had no problems, and Swift's comparison against that report passed.
Optimized Release output was also generated, loaded by Flutter (66 store
cases plus two insight-view comparisons), and compared successfully with
Release Swift's calculations. `DEEP_MIGRATION_AUDIT_EVIDENCE.json` records
suite results, source hashes, binary identity and the archive check.

Installed-app rerun: `rehearsal/20260930-195723` passed S1 (upgrade, edit,
Flutter rollback), S3 (v1/bare legacy preferences), S4 (simulated locked
startup), S5 (damaged files) and S6 (malformed legacy ledger/envelope).
Every Dart problem list and every Swift/Flutter comparison was empty.
All **66 independent preservation/hash checks passed**. The verifier now
also checks every original value in the chosen v1 envelope, allowing only
new due transactions and advancing recurring cursors. Existing template
fields and every original transaction remain intact. Both malformed
legacy values were retained with no replacement store or ready summary.

These finite checks substantially improve confidence;
they do not establish that every possible storage/device condition has
been covered or that no future code change could introduce a regression.

## Remaining release requirements (after the additional audit)

- Install the current shipping Flutter App Store/TestFlight build on a
  spare iPhone with synthetic data, then install the actual Swift release
  candidate over it. Compare every record and setting, add/edit data,
  terminate/relaunch, and verify persistence and rollback.
- Exercise a real reboot/launch before first unlock and inspect protected
  data behavior; a simulator's injected lock cannot establish this.
- Verify the signed archive's application identifier, team, App Group,
  bundle/version settings and association with the existing App Store
  listing. The source uses provisional version 4.0.0, build 1.
- Repeat against supported iOS versions, including the oldest supported
  Swift iOS version (17), and legacy-only installs from skipped updates.

See `REAL_DEVICE_CHECKLISTS.md` for device steps. Keep the installable Flutter
build and all pre-native copies. An update must be installed over the existing
app; do not instruct users to delete/reinstall to migrate. Apple's
[deployment guidance](https://support.apple.com/guide/deployment/distribute-proprietary-in-house-apps-depce7cefc4d/web)
also describes retaining the same bundle identifier and avoiding deletion
when preserving data across replacement.
