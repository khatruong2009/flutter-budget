#!/usr/bin/env bash
# Proves rule 2 (compatibility with the Flutter build): BudgieCore writes
# stores into a scratch directory, then the real Flutter models load every
# one of them (native/ParityHarness verify mode) and fail on any rejected,
# skipped or reset data. Then the Swift side compares the numbers Flutter
# derived from every store (month totals, net worth, safe-to-spend, goals,
# cursors, ...) with its own.
#
# Runs once per zone in ZONES: New York, Santiago and Beirut, so the stores
# hold dates on DST gaps and repeated hours, including the zones whose DST
# change happens at midnight. Per zone $OUT/<zone with _ for />/ holds the
# Swift-written cases and Flutter's report (dart-verification.json).
#
# Usage: verify-swift-output-in-dart.sh [dir]
# Ends with the line "All tests passed" when every zone passed; any failure
# stops the script with a non-zero status (set -e).
set -euo pipefail
REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
OUT="${1:-$(mktemp -d "${TMPDIR:-/tmp}/budgie-swift-out.XXXXXX")}"
ZONES=(America/New_York America/Santiago Asia/Beirut)
rm -rf "$OUT" && mkdir -p "$OUT"
echo "Swift output: $OUT"
for zone in "${ZONES[@]}"; do
  ZONE_OUT="$OUT/${zone//\//_}"
  mkdir -p "$ZONE_OUT"
  echo "=== $zone: Swift writes the stores ==="
  ( cd "$REPO_ROOT/native/BudgieCore" && BUDGIE_SWIFT_ZONE="$zone" BUDGIE_SWIFT_OUT="$ZONE_OUT" swift test --filter SwiftOutputForDartTests )
  echo "=== $zone: Flutter loads them ==="
  VERIFY_TZ="$zone" SWIFT_OUT="$ZONE_OUT" "$REPO_ROOT/native/ParityHarness/run.sh" verify
  echo "=== $zone: Swift compares Flutter's numbers with its own ==="
  ( cd "$REPO_ROOT/native/BudgieCore" && BUDGIE_SWIFT_ZONE="$zone" BUDGIE_DART_VERIFICATION="$ZONE_OUT/dart-verification.json" swift test --filter DartSummaryOfSwiftStores )
done
echo "All tests passed"
