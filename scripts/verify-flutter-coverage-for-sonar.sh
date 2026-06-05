#!/usr/bin/env bash
# Validate Flutter lcov before SonarCloud upload/import.
set -euo pipefail

LCOV="${1:-flutter_obdii/coverage/lcov.info}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[ -f "$LCOV" ] || fail "Flutter coverage file not found at $LCOV"
[ -s "$LCOV" ] || fail "Flutter coverage file is empty at $LCOV"

bash "$(dirname "$0")/normalize-flutter-lcov-for-sonar.sh" "$LCOV"

grep -q '^SF:flutter_obdii/lib/' "$LCOV" || fail "Flutter lcov is missing flutter_obdii/lib source paths"
grep -q '^SF:flutter_obdii/lib/views/' "$LCOV" || fail "Flutter lcov is missing view source entries"

if ! awk '/^SF:flutter_obdii\/lib\/views\// { in_view=1 } in_view && /^DA:/ { split($0, parts, ","); if (parts[2] > 0) { hit=1; exit } } END { exit hit ? 0 : 1 }' "$LCOV"; then
  fail "Flutter lcov has no executed lines for lib/views sources"
fi

echo "Flutter coverage report is ready for Sonar: $LCOV ($(wc -c < "$LCOV") bytes)"
