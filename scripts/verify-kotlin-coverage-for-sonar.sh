#!/usr/bin/env bash
# Validate Kotlin JaCoCo reports before SonarCloud upload/import.
set -euo pipefail

ROOT="${1:-kotlin_obdii}"
REQUIRE_ANDROID=true
if [ "${2:-}" = "--unit-only" ]; then
  REQUIRE_ANDROID=false
fi

UNIT_REPORT="$ROOT/app/build/reports/jacoco/test/jacocoTestReport.xml"
ANDROID_CANONICAL="$ROOT/androidApp/build/reports/coverage/androidTest/debug/connected/report.xml"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

assert_jacoco_report() {
  local label="$1"
  local path="$2"
  [ -f "$path" ] || fail "$label coverage report not found at $path"
  [ -s "$path" ] || fail "$label coverage report is empty at $path"
  grep -q '<package name=' "$path" || fail "$label coverage report has no package entries at $path"
}

resolve_android_report() {
  if [ -f "$ANDROID_CANONICAL" ]; then
    echo "$ANDROID_CANONICAL"
    return
  fi

  local discovered
  discovered="$(find "$ROOT/androidApp/build/reports/coverage" -name 'report.xml' -type f 2>/dev/null | head -1 || true)"
  [ -n "$discovered" ] || fail "Android instrumentation coverage report not found under $ROOT/androidApp/build/reports/coverage"
  mkdir -p "$(dirname "$ANDROID_CANONICAL")"
  cp "$discovered" "$ANDROID_CANONICAL"
  echo "$ANDROID_CANONICAL"
}

assert_jacoco_report "Unit test" "$UNIT_REPORT"
echo "Unit coverage report: $UNIT_REPORT ($(wc -c < "$UNIT_REPORT") bytes)"

if [ "$REQUIRE_ANDROID" = false ]; then
  exit 0
fi

ANDROID_REPORT="$(resolve_android_report)"
assert_jacoco_report "Android instrumentation" "$ANDROID_REPORT"

if ! grep -q 'obdii/android' "$ANDROID_REPORT"; then
  fail "Android coverage report does not reference kotlin_obdii/androidApp sources"
fi

echo "Android coverage report: $ANDROID_REPORT ($(wc -c < "$ANDROID_REPORT") bytes)"
echo "Kotlin coverage reports are ready for Sonar."
