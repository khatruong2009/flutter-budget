#!/usr/bin/env bash
# Runs the Dart parity harness against an exported copy of budget_app.
#
# Nothing inside budget_app/ is created or modified. The copy is taken from
# the committed tree (git archive HEAD), so fixtures are tied to a commit.
#
# In the copy, and only there:
#   - a stub .env is added (budget_app bundles .env as an asset; its tests
#     cannot build without one). It holds a dummy key.
#   - every `DateTime.now()` in lib/ becomes `parityNow()` (lib/parity_clock.dart),
#     which returns DateTime.now() unless a test pins the clock. This is the
#     only change to app code and it is mechanical.
#   - the harness tests are copied to test/parity/.
#
# Usage: native/ParityHarness/run.sh <mode> [flutter test args...]
#   mode = generate  -> writes native/Fixtures/
#   mode = verify    -> loads Swift-written files from $SWIFT_OUT (default
#                       native/Fixtures/swift-written) through the Dart store
set -euo pipefail

MODE="${1:?usage: run.sh generate|verify [args]}"
shift || true

REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
HARNESS="$REPO_ROOT/native/ParityHarness"
FIXTURES="$REPO_ROOT/native/Fixtures"
WORK="${PARITY_WORK_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/budgie-parity.XXXXXX")}"
COPY="$WORK/budget_app"
COMMIT="$(git -C "$REPO_ROOT" rev-parse HEAD)"

rm -rf "$COPY"
mkdir -p "$WORK"
git -C "$REPO_ROOT" archive --format=tar HEAD budget_app | tar -x -C "$WORK"

printf 'OPENAI_API_KEY=parity-harness-dummy-key\n' > "$COPY/.env"

cp "$HARNESS/parity_clock.dart" "$COPY/lib/parity_clock.dart"
count=0
while IFS= read -r file; do
  n=$(grep -c 'DateTime\.now()' "$file" || true)
  count=$((count + n))
  perl -0pi -e 's/DateTime\.now\(\)/parityNow()/g' "$file"
  perl -0pi -e "s/\A/import 'package:budget_app\/parity_clock.dart';\n/" "$file"
done < <(grep -rl 'DateTime\.now()' "$COPY/lib" | grep -v parity_clock.dart)
if grep -rq 'DateTime\.now()' "$COPY/lib" --exclude=parity_clock.dart; then
  echo "clock rewrite incomplete" >&2; exit 1
fi
echo "clock seam: rewrote $count DateTime.now() call sites"

mkdir -p "$COPY/test/parity"
cp "$HARNESS"/parity/*.dart "$COPY/test/parity/"

cd "$COPY"
flutter pub get --offline >/dev/null 2>&1 || flutter pub get >/dev/null 2>&1

export PARITY_FIXTURES="$FIXTURES"
export PARITY_COMMIT="$COMMIT"
case "$MODE" in
  generate)
    mkdir -p "$FIXTURES"
    # Each generator runs under the zones it needs; see the test files.
    for tz in America/New_York UTC Australia/Lord_Howe Asia/Kolkata; do
      TZ="$tz" PARITY_TZ="$tz" flutter test test/parity/logic_fixtures_test.dart "$@"
    done
    TZ=America/New_York PARITY_TZ=America/New_York flutter test test/parity/store_fixtures_test.dart "$@"
    TZ=America/New_York PARITY_TZ=America/New_York flutter test test/parity/legacy_fixtures_test.dart "$@"
    ;;
  verify)
    export SWIFT_OUT="${SWIFT_OUT:-$FIXTURES/swift-written}"
    TZ=America/New_York PARITY_TZ=America/New_York flutter test test/parity/verify_swift_output_test.dart "$@"
    ;;
  *) echo "unknown mode $MODE" >&2; exit 2 ;;
esac
