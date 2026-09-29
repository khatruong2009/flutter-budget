#!/usr/bin/env bash
# Home screen integration check on a dedicated "Budgie-System" simulator
# (created fresh; no other simulator is touched):
#   1. the Flutter build is installed and launched once (it registers its
#      three dynamic quick actions, including "Add by Voice");
#   2. SystemIntegrationUITests installs the Swift build over it and drives
#      SpringBoard: leftover Flutter quick action, Swift quick actions,
#      budgetapp:// links through the system prompt, and the Quick Add widget.
# Usage: system_flow.sh <path/to/flutter/Runner.app>
set -euo pipefail
FLUTTER_APP="${1:?path to the Flutter Runner.app}"
NATIVE="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)/native"
WORK="${TMPDIR:-/tmp}/budgie-system-flow"
for old in $(xcrun simctl list devices | grep "    Budgie-System (" | grep -oE '[0-9A-F-]{36}'); do
  xcrun simctl shutdown "$old" 2>/dev/null || true; xcrun simctl delete "$old"
done
RUNTIME=$(xcrun simctl list runtimes | grep -E '^iOS' | tail -1 | grep -oE 'com\.apple\.CoreSimulator\.SimRuntime\.[A-Za-z0-9-]+')
UDID=$(xcrun simctl create Budgie-System "iPhone 17 Pro" "$RUNTIME")
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl install "$UDID" "$FLUTTER_APP"
xcrun simctl launch "$UDID" com.khatruong.budgetbuddy >/dev/null
sleep 15
xcrun simctl terminate "$UDID" com.khatruong.budgetbuddy || true
cd "$NATIVE" && xcodegen generate >/dev/null
rm -rf "$WORK/result.xcresult"
xcodebuild build-for-testing -project Budgie.xcodeproj -scheme Budgie -destination "id=$UDID" \
  -derivedDataPath "$WORK/derived" CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual | grep -E "error:|\*\* TEST BUILD" || true
# Install the Swift build over the Flutter one ourselves, so the first test
# sees exactly "Swift installed, not yet launched" (xcodebuild's own install
# of the app under test can land after the first test has started).
xcrun simctl install "$UDID" "$WORK/derived/Build/Products/Debug-iphonesimulator/Budgie.app"
set +e
xcodebuild test-without-building -project Budgie.xcodeproj -scheme Budgie -destination "id=$UDID" \
  -only-testing:BudgieUITests/SystemIntegrationUITests -resultBundlePath "$WORK/result.xcresult" \
  -derivedDataPath "$WORK/derived" 2>&1 | grep -E "Test Case|XCTAssert|error:|\*\* TEST"
STATUS=${PIPESTATUS[0]}
set -e
GROUP=$(xcrun simctl get_app_container "$UDID" com.khatruong.budgetbuddy groups | grep group.com.khatruong.budgetbuddy | awk '{print $2}')
echo "App Group widget data:"; plutil -p "$GROUP/Library/Preferences/group.com.khatruong.budgetbuddy.plist" || true
xcrun simctl io "$UDID" screenshot "$WORK/home-screen.png" >/dev/null 2>&1 || true
echo "UDID=$UDID result=$WORK/result.xcresult status=$STATUS home=$WORK/home-screen.png"
exit $STATUS
