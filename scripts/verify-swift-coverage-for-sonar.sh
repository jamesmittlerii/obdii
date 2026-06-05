#!/usr/bin/env bash
# Validate Swift Sonar generic coverage before upload/import.
set -euo pipefail

REPORT="${1:-coverage-swift/sonarqube-generic-coverage.xml}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[ -f "$REPORT" ] || fail "Swift coverage report not found at $REPORT"
[ -s "$REPORT" ] || fail "Swift coverage report is empty at $REPORT"

grep -q '<coverage version="1">' "$REPORT" || fail "Swift coverage report is missing Sonar generic coverage root"
grep -q '<file path="obdii/' "$REPORT" || fail "Swift coverage report has no obdii/ source entries"

if ! grep -q 'covered="true"' "$REPORT"; then
  fail "Swift coverage report has no covered lines"
fi

echo "Swift coverage report is ready for Sonar: $REPORT ($(wc -c < "$REPORT") bytes)"
