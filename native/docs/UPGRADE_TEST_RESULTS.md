# Upgrade test results

Plan: UPGRADE_TEST_PLAN.md. Every run's raw evidence (report.json,
screenshots, pulled container state) is under `native/docs/rehearsal/<run>/`.
Simulator: dedicated `Budgie-Rehearsal` (iPhone 17 Pro, iOS 27.0).
Synthetic fixture data only.

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

## Run 3: final, on the finished MVP

(filled in below)
