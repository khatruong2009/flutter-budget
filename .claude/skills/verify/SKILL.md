---
name: verify
description: Build, launch, and drive budget_app on the iOS Simulator to verify UI changes at runtime.
---

# Verifying budget_app on the iOS Simulator

## Launch

```bash
cd budget_app
xcrun simctl list devices booted        # iPhone 17 Pro sim is the usual target (has seeded demo data)
flutter run -d <device-udid>            # background it; ready when "A Dart VM Service ... is available" appears
```

The app stays installed on the sim after the run; killing `flutter run` is fine.

## Drive

- Deep links skip UI navigation: `xcrun simctl openurl <udid> "budgetapp://add-expense"`
  (also `add-income`, `voice-add`). iOS shows an "Open in Budgie?" confirmation
  dialog — tap **Open** via computer-use (request access to "Simulator", full tier).
- Screenshots without computer-use: `xcrun simctl io <udid> screenshot out.png`.

## Simulator gotchas

- **Software keyboard**: hidden by default when the hardware keyboard is connected.
  Toggle with **Cmd+K** while the Simulator window is frontmost. Keyboard-up layout
  is the state that matters for form/dialog changes.
- **Do not type text via synthetic keystrokes** — press-and-hold triggers the macOS
  accent picker inside the sim and garbles input. Click the on-screen keypad/keyboard
  buttons instead.
- **Mouse-wheel scroll does not move Flutter scroll views** in the sim; use
  `left_click_drag` (touch-style swipe). Start drags on non-interactive text
  (e.g. a section label), not on text fields or the CupertinoPicker.

## Data

The iPhone 17 Pro sim carries fake seeded demo data (safe to add/delete
transactions). Real data lives only on the physical iPhone.
