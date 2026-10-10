# Budgie — approved Savings Pal logo

Owner approved concept 12 on October 10, 2026 for both Flutter and native apps: a cobalt blue bird with a coral beak and coin, holding a pale-lime savings pocket on lilac.

- `budgie-icon.png`: opaque 1024 × 1024 master, exported from the exact approved concept. Used for app launcher icons and the App Store marketing icon.
- `budgie-mark.png`: transparent master of the same character, prepared using the built-in imagegen tool. Used for headers, app lock/privacy screens, launch marks and widgets.
- Original approved concept: [approved-concept.png](approved-concept.png). Rejected concepts have been removed from the repository.
- Original generation prompt: [approved-concept-prompt.md](approved-concept-prompt.md).

## Exporting

On macOS, from the repository root:

```sh
python3 design/branding/export_assets.py
```

Requires `sips`, Python 3, and the existing Flutter/Dart SDK and pinned `flutter_launcher_icons` dependency. The script exports PNGs into both Apple catalogs, updates launch and widget marks, then generates Android, web, macOS and Windows icons using the project's existing tool. The Android adaptive foreground uses a 12% inset to keep the tuft and wings inside round masks. The Apple app icon slots retain their existing sizes and metadata; App Store PNGs are opaque. Regenerating only with `dart run flutter_launcher_icons` will remove the Android inset, so use this script for the complete export.

The app interface colors and financial behavior are unchanged. Native and Flutter iOS icon and logo images are identical. No new difference from Flutter is introduced.

## Simulator preview

[iOS Home Screen: app icon and Quick Add widget](ios-home-screen.png), captured after the Flutter-to-native upgrade and widget integration test passed.

[Native Home header](native-home.png), captured on the same dedicated test simulator with synthetic test data.

[Flutter Home header](flutter-home.png), captured after installing the updated Flutter simulator build on the dedicated test simulator.

## Verification — October 10, 2026

- Flutter analysis: no issues; all 390 tests passed.
- BudgieCore: all 404 tests passed.
- Native project regenerated; Debug simulator build passed with zero warnings.
- Flutter Debug simulator build passed through the Xcode workspace with `ARCHS=arm64 ONLY_ACTIVE_ARCH=YES`. The SDK's default multi-architecture simulator build failed in its Flutter framework architecture check; no app source change was needed for the arm64 build.
- `verify-swift-output-in-dart.sh`: passed for New York, Santiago and Beirut.
- `ui_flow.sh`: native app and UI tests passed; Flutter verified their written store.
- `system_flow.sh`: Home Screen, widget, deep link and upgrade integration tests passed.
- All 66 Apple icon slots have the expected dimensions and opaque PNGs; both iOS apps' icon and logo exports match byte-for-byte.
- Visually checked the Home Screen icon, widget and both apps' Home headers on a dedicated simulator.
- Native 4.0.0 (4) Release archive built with zero warnings. Archive and App Store IPA signatures verified; Xcode Organizer App Store Connect validation passed. See [release handoff](../../native/docs/appstore/BLUE_BIRD_RELEASE.md).
- Refreshed both App Store artwork sets, creative images, editable layouts and the marketing ZIP. Removed rejected concepts and the identical duplicate marketing folder.

## Transparent mark edit prompt

Use case: background-extraction. Edit target: approved Budgie logo in the provided image. Remove ONLY the lilac background around the blue bird to make a genuinely transparent RGBA cutout suitable for headers, splash screens and widgets. Preserve the exact approved blue bird silhouette, tuft, wings, dark oval eyes, coral beak and coral circular coin, bright pale-lime savings pocket, original colors and proportions. Keep the entire character intact, same position and same square canvas dimensions with all original padding. Transparency only outside the bird; the lime pocket and blue body must remain opaque. Do not redesign, simplify, alter expression, add or remove features, add a shadow or add text. Clean antialiased outer edges, no lilac halo.
