# Upgrade test results

Plan: UPGRADE_TEST_PLAN.md. Every run's raw evidence (report.json,
screenshots, pulled container state) is under `native/docs/rehearsal/<run>/`.
Simulator: dedicated `Budgie-Rehearsal` (iPhone 17 Pro, iOS 27.0).
Synthetic fixture data only.

## Migration safety audit — 2026-09-30

See [MIGRATION_SAFETY_AUDIT.md](MIGRATION_SAFETY_AUDIT.md) for the new
regressions, fixes, evidence and remaining release requirements. Fresh run
`20260930-142713` on the separate `Budgie-Migration-Audit` simulator:
S1/S3/S4/S5 passed, no Dart problems or Swift/Dart differences; 52 full-data
and safety-copy hash checks passed. Automated suites: 379 Swift tests,
67 Swift-written Flutter compatibility cases, 390 Flutter tests, clean
Flutter analysis. Physical-device and signed-release verification remain
outstanding.
Follow-up run `20260930-144200`: S5 with real currency preferences and the
new S6 malformed ledger/envelope cases passed inside the installed app;
original legacy values and their safety copies remained intact.

"Numbers" below means: per-month income, expenses and transaction count,
net worth (assets, liabilities) per month, recurring cursors and pause
state, and the five app settings. "Flutter's numbers" are computed by the
real Flutter models over the exact files pulled from the simulator.

## Run 1: 20260928-180731 (shell app, before the MVP screens)

| Scenario | Result |
|---|---|
| Build | First attempt failed: `flutter build ios --simulator` requires an x86_64 slice this Flutter engine no longer ships. Fixed by building arm64 only (`--config-only` + `xcodebuild ARCHS=arm64`). Not a data issue. |
| S1 upgrade | PASS. Swift shows exactly Flutter's numbers (0 differences). `pre-native-migration/<stamp>/` complete; its store files are byte-identical to Flutter's. Theme dark and onboarding flag carried over. App Group `cashFlow`/`cashFlowMonth` written. |
| S1 downgrade | PASS on data: the Flutter build loaded the Swift-written store (its backup = Swift's revision 200 byte for byte; it wrote revision 201 adding one category definition, its normal launch behaviour). Flutter models: no problems; numbers equal Swift's. The downgrade screenshot was a black frame; reproduced with longer waits and console capture, it is Flutter's slower first launch after a reinstall (the app then renders normally). Waits were lengthened. |
| S3 legacy-only | PASS. Swift migrated the bare keys + v1 envelopes into a verified v2 store; the 11 migrated keys were removed; settings, theme, onboarding, starting-balance and insight keys kept; the pre-native snapshot's `preferences.plist` holds every legacy key. Numbers equal Flutter's on the same files; the Flutter build then loaded the Swift-migrated store without problems. |
| S4 locked launch | NOT RUN: script error (a cached container path; reinstalling moves the data container). Fixed. |
| S5 damage | PASS. Truncated primary: restored from the backup (145 transactions, same revision Dart restores). Both damaged: set aside as `.corrupt-<ms>`, "Your data couldn't be read" shown, nothing else written. |

Screens: the Flutter screenshots show Flutter's App Lock screen because the
fixture enables App Lock and the simulator had no enrolled biometrics;
later runs enroll simulated Face ID.

## Run 2: 20260928-181915 (same binaries, script fixes)

| Scenario | Result |
|---|---|
| S1 | PASS (0 differences both directions). Note: the pulled `3-swift-edited` preferences did not yet show `flutter.base_currency_code` although the app had set it; the plist on disk is written asynchronously by cfprefsd. The store's `appSettings` (authoritative) had GBP, and the key was present in the later pull. Not a data issue. |
| S3, S5 | PASS, as run 1. |
| S4 | Reported FAIL ("store changed / pre-native folder exists while locked"). Investigated before accepting: timestamps showed the writes at 18:26:49, i.e. when the simulated 15 s lock ended, while the "during lock" check had run after a `simctl io screenshot` call that wrote its file at 18:26:43 but returned late. A standalone 0.5 s poll confirmed no read or write until 16.8 s after launch (15 s lock + startup). Root cause: the measurement, not the app. S4 now polls the whole window and takes its screenshot without blocking. |

## Run 3: 20260928-183853 (finished MVP, fresh builds of both apps)

| Scenario | Result |
|---|---|
| S1 | Data PASS (0 differences both directions, Flutter models no problems). **UI FAIL on downgrade:** the Flutter build showed a black screen after the Swift app had run, although it loaded and saved the data. |
| S3, S5 | PASS. |
| S4 | PASS: first write 18.8 s after launch with a 15 s simulated lock; nothing read or written while locked. |

Investigation of the S1 black screen (not accepted as a timing artefact the
second time): reproduced deterministically only when the Swift app had run
before the Flutter install. The app's `KnownSceneSessions` held a scene
session whose delegate class was `SwiftUI.AppSceneDelegate` (the SwiftUI
`App` lifecycle); iOS restores a saved session with its stored class
without consulting the app, and the Flutter binary has no such class.
Deleting the saved session made Flutter render immediately: cause
confirmed. Fix (commit 81fc729): the Swift app uses the UIKit lifecycle with
module `Runner`, a `SceneDelegate` and the `Default Configuration` scene
manifest, exactly as the Flutter app declares (MIGRATION_SPEC 11.5, R23).
The same rehearsal also showed that the earlier run-1 black frame was this
bug, not only a slow launch.

## Run 4: 20260928-185629 (after the scene fix, fresh builds)

| Scenario | Result |
|---|---|
| S1 upgrade | PASS: 0 differences; pre-native copy byte-identical; theme and onboarding carried; widget App Group value written. |
| S1 downgrade | PASS: Flutter renders (its App Lock prompt), loads the Swift-written store (backup = Swift's last revision byte for byte), Flutter models report no problems, numbers equal Swift's. |
| S3 legacy-only | PASS: migrated, 11 legacy keys removed and preserved in the pre-native snapshot, numbers equal Flutter's; Flutter then loads the Swift-migrated store. |
| S4 locked launch | PASS: first write 18.1 s after launch with a 15 s simulated lock. |
| S5 damage | PASS: truncated primary restored from backup (145 transactions); both damaged set aside and blocked without writing. |

The report's `sceneDelegateClasses` field was empty in this run because the
extractor looked only for class names; with the Info.plist manifest iOS
stores the configuration by name. Fixed and re-run in run 5.

## Run 5: 20260928-190549 (S1 only, extractor fixed)

PASS. The persisted scene configuration is `Default Configuration` after
every step, whichever app wrote it last (Flutter, Swift, Swift after edits,
Flutter after downgrade). 0 differences; no Dart-side problems; both apps
render after each switch.

## UI flow (XCUITest, `native/scripts/ui_flow.sh`)

PASS on a fresh install (`Budgie-UITest` simulator, 66 s): add expense,
edit its amount from History, add a monthly recurring template (today's
occurrence generated immediately, as Flutter does), pause it, Net Worth
empty state, switch theme to Dark, add and delete an income. The store it
wrote was loaded by the real Flutter models with no problems: amounts are
Dart doubles (`20.0`, `900.0`), the template is `isActive: false`, the
deleted row is gone, `flutter.themeMode` is `dark`.

The script now also runs `CategoriesUITests` before the MVP flow (add,
move up / down, archive / restore, rename cascade, the last active
category refusing Archive; its tearDown deletes the added expense and
archives the added category). 2026-09-29: all PASS, and the Dart
verification loaded the store (the archived "UI Brew" category, the
restored built-in income categories) with no problems.

It now also runs `InsightsUITests` (after Categories, before the MVP flow
leaves its rows): six rows give three duplicate cards, one is snoozed and
one dismissed, both stay hidden after a relaunch, and the rows are deleted.
Its descriptions carry a per-run suffix, so a second run on the same
simulator the same day passes (the first run's snooze and dismissal stay in
preferences; the app has no way to undo them). 2026-09-30, on an erased
simulator: all PASS, Insights passed again on a second run without an
erase, and the Dart verification loaded the pulled store with no problems.

## Home screen integration (`native/scripts/system_flow.sh`, SpringBoard via XCUITest)

Run on a fresh `Budgie-System` simulator: the Flutter build installed and
launched once, then the Swift build installed over it (not launched).
All four tests PASS:

| Test | Result |
|---|---|
| Leftover Flutter quick action | Before the Swift app's first launch, SpringBoard still offers the Flutter build's three items (Add Expense, Add Income, Add by Voice); "Add by Voice" opens Swift's Add Expense form. |
| Swift quick actions | After a launch, exactly "Add Expense" and "Add Income"; both open the right form. |
| `budgetapp://` links | `add-income`, `add-expense`, `voice-add`, `add_income` through the system "Open in Budgie?" prompt open the right form. |
| Widget | The Swift extension appears in the widget gallery as "Budget Quick Add" with the Flutter description; placed on the home screen it shows the App Group value the app wrote (`cashFlow -12`, `cashFlowMonth 2026-09`); its Income and Expense links open the matching forms. |

Widget survival across app replacement (SpringBoard probe, a UI test with
no app under test, so it does not reinstall anything). With the widget
placed: installing the Flutter build over Swift keeps the widget on the
home screen, still showing -$12, and its Expense link opens Flutter's Add
Expense dialog; reinstalling Swift keeps it again and the link opens
Swift's form. Screenshots: `rehearsal/system-20260928/`.

## Safe-to-spend differential corpus

1600 random scenarios (400 per time zone) generated by the real Dart
calculator: Swift matches every field of every case (`SafeToSpendRandomTests`).
A one-line change to the same-day rule produces 210 mismatches.

## Not verified on the simulator

- Real prewarm / locked-container behaviour: the simulator cannot prewarm or
  lock the container; the gate logic is covered by S4 and unit tests. Needs
  a spare physical device (pre-ship item, not done without approval).
- App Lock re-lock after the auto-lock timeout and a failed Face ID match:
  not driven (simulated biometrics cannot be scripted from inside XCUITest).
- Face ID prompts in screenshots: simulated matches were not always
  delivered in time, so several screenshots show the passcode fallback.
