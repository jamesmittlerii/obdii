#!/usr/bin/env bash
# Rewrite Flutter lcov source paths so SonarCloud can match monorepo sources.
set -euo pipefail

LCOV="${1:-flutter_obdii/coverage/lcov.info}"

[ -f "$LCOV" ] || {
  echo "ERROR: Flutter coverage file not found at $LCOV" >&2
  exit 1
}

tmp="${LCOV}.sonar.tmp"
tr '\\' '/' < "$LCOV" | sed -E 's|^SF:lib/|SF:flutter_obdii/lib/|g' > "$tmp"
mv "$tmp" "$LCOV"
echo "Normalized Flutter lcov paths for Sonar: $LCOV"
