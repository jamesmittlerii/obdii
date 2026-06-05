#!/usr/bin/env bash
# Run Android instrumented tests with coverage on CI. Retries once if adb loses the emulator.
set -euo pipefail

cd kotlin_obdii
chmod +x gradlew

max_attempts=2
attempt=1
while [ "$attempt" -le "$max_attempts" ]; do
  echo "createDebugCoverageReport attempt ${attempt}/${max_attempts}"
  if ./gradlew :androidApp:createDebugCoverageReport --no-daemon; then
    bash ../scripts/verify-kotlin-coverage-for-sonar.sh .
    exit 0
  fi
  if [ "$attempt" -eq "$max_attempts" ]; then
    exit 1
  fi
  echo "Instrumented run failed; restarting adb before retry..."
  adb kill-server || true
  adb start-server || true
  sleep 15
  attempt=$((attempt + 1))
done
