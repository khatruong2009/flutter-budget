#!/usr/bin/env bash
# Proves rule 2 (compatibility with the Flutter build): BudgieCore writes
# stores into a scratch directory, then the real Flutter models load every
# one of them (native/ParityHarness verify mode) and fail on any rejected,
# skipped or reset data. Report: $OUT/dart-verification.json
set -euo pipefail
REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
OUT="${1:-$(mktemp -d "${TMPDIR:-/tmp}/budgie-swift-out.XXXXXX")}"
rm -rf "$OUT" && mkdir -p "$OUT"
echo "Swift output: $OUT"
( cd "$REPO_ROOT/native/BudgieCore" && BUDGIE_SWIFT_OUT="$OUT" swift test --filter SwiftOutputForDartTests )
SWIFT_OUT="$OUT" "$REPO_ROOT/native/ParityHarness/run.sh" verify
