# Upgrade test plan

Proves on a simulator that installing the Swift app over the Flutter app
(same bundle ID, no uninstall) loses nothing, and that the Flutter build can
be installed back over the Swift app. Synthetic data only; never a physical
device.

## How to run

```bash
native/scripts/upgrade_rehearsal.py            # builds both apps, runs s1 s3 s4 s5
native/scripts/upgrade_rehearsal.py --skip-build s1
```

Output: `native/docs/rehearsal/<timestamp>/` with `report.json`, screenshots
and the pulled app state of every step. Results are written up in
`UPGRADE_TEST_RESULTS.md`.

The script only touches the simulator named `Budgie-Rehearsal` (created if
missing, erased between scenarios). The Flutter app is built from a
`git archive` copy of `budget_app` with a stub `.env`; `budget_app/` itself
is never modified. The Swift app is the Debug build, whose rehearsal hooks
(environment variables, Debug only) are:

| Variable | Effect |
|---|---|
| `BUDGIE_REHEARSAL_SUMMARY=1` | writes what the app shows to `Library/Caches/budgie-rehearsal.json` |
| `BUDGIE_REHEARSAL_EDIT=1` | makes one of each MVP edit through the app model after launch |
| `BUDGIE_SIMULATE_LOCKED_SECONDS=N` | reports protected data unavailable for N seconds |

"What the Flutter app shows" is computed by the real Flutter models
(`native/ParityHarness` verify mode) over the exact files pulled from the
simulator, so the comparison is number-for-number, not by eye. Screenshots
of both apps are kept for a visual check.

Data is seeded from `native/Fixtures`, which the real Flutter code produced.
Preferences are injected by editing the app's defaults plist while the
simulator is shut down (`simctl spawn defaults write` cannot reach an app's
container).

## Scenarios and checklist

### S1: typical store, upgrade and downgrade

1. Erase; install the Flutter build; inject `store/typical` files and
   `flutter.themeMode = dark`, `flutter.onboarding_completed = true`.
2. Launch Flutter (it generates due recurring rows); screenshot; pull state.
3. Install the Swift build over it; launch; screenshot; pull state.
   - [ ] Every month's income, expenses and transaction count, net worth
     per month, recurring cursors and settings equal the Flutter models'
     values on the step 2 files.
   - [ ] `pre-native-migration/<stamp>/` exists, is complete, and its store
     files are byte-identical to the step 2 files.
   - [ ] Theme is dark; onboarding flag unchanged.
   - [ ] App Group `cashFlow`/`cashFlowMonth` written (widget value).
4. Launch Swift with scripted edits (add, edit, delete, add template,
   pause, currency, theme); pull state.
5. Install the Flutter build over it; launch; screenshot; pull state.
   - [ ] No `.corrupt-*` files: Flutter accepted the Swift-written store.
   - [ ] The Flutter models load every row (no skipped, reset or unsaved
     data) and show the same numbers as Swift did in step 4.

### S3: legacy-only SharedPreferences (a user who skipped updates)

1. Erase; install the Flutter build without launching it; inject every
   bare legacy key, both v1 envelopes, settings, starting balances, theme,
   onboarding and insight keys.
2. Install the Swift build; launch; pull state.
   - [ ] A verified `financial_store_v2.json` exists; the 11 migrated keys
     are removed; settings, theme, onboarding, starting-balance and insight
     keys remain.
   - [ ] The pre-native snapshot's `preferences.plist` still holds every
     legacy key.
   - [ ] Numbers equal the Flutter models' on the same files.
3. Install the Flutter build over it; launch; pull state.
   - [ ] Flutter loads the Swift-migrated store without errors.

### S4: locked / prewarmed launch

1. Erase; install Flutter; inject `store/typical` and
   `flutter.onboarding_completed = true` (so the data, not the tour, shows);
   install Swift.
2. Launch Swift with `BUDGIE_SIMULATE_LOCKED_SECONDS=12`; after 4 s:
   - [ ] Store files unchanged (mtimes), no `pre-native-migration/`, no
     summary written, "Unlock your iPhone" on screen.
3. After the simulated unlock:
   - [ ] Data loads normally.

The simulator cannot produce a real prewarm or a real locked container
(research I section 4); this checks the app's gate logic. A real-device
test is on the pre-ship list.

### S5: damaged files

1. `store/primary_truncated` (onboarding flag preset as in S4): Swift
   restores the primary from the backup
   (same revision Dart restores), shows the data.
2. `store/both_corrupt`: Swift sets both files aside as `.corrupt-<ms>`,
   shows "Your data couldn't be read", writes nothing else (approved
   divergence Q3).

## Re-run at the end

The same script runs again on the finished MVP (Phase 4). Results of both
runs go in `UPGRADE_TEST_RESULTS.md`.
