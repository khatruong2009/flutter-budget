#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
PUBSPEC="$APP_ROOT/pubspec.yaml"

CURRENT_VERSION=$(grep '^version:' "$PUBSPEC" | sed 's/^version:[[:space:]]*//')
VERSION_NAME=${CURRENT_VERSION%%+*}
BUILD_NUMBER=

case "$CURRENT_VERSION" in
  *+*) BUILD_NUMBER=${CURRENT_VERSION##*+} ;;
esac

if [ "${1:-}" = "--increment-build" ]; then
  case "$BUILD_NUMBER" in
    ''|*[!0-9]*) NEXT_BUILD_NUMBER=1 ;;
    *) NEXT_BUILD_NUMBER=$((BUILD_NUMBER + 1)) ;;
  esac

  TEMP_PUBSPEC=$(mktemp "$PUBSPEC.XXXXXX")
  sed "s/^version:[[:space:]].*/version: ${VERSION_NAME}+${NEXT_BUILD_NUMBER}/" "$PUBSPEC" > "$TEMP_PUBSPEC"
  mv "$TEMP_PUBSPEC" "$PUBSPEC"
fi

if command -v flutter >/dev/null 2>&1; then
  FLUTTER_BIN=$(command -v flutter)
elif [ -n "${FLUTTER_ROOT:-}" ] && [ -x "$FLUTTER_ROOT/bin/flutter" ]; then
  FLUTTER_BIN="$FLUTTER_ROOT/bin/flutter"
else
  echo "Could not find flutter. Add Flutter to PATH or set FLUTTER_ROOT." >&2
  exit 1
fi

cd "$APP_ROOT"
"$FLUTTER_BIN" build ios --config-only
