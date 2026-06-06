#!/usr/bin/env bash
# Build Sonar scanner -D overrides so only coverage from this CI run is imported.
# Usage: prepare-sonar-scanner-args.sh [--kotlin] [--flutter] [--swift]
set -euo pipefail

enable_kotlin=false
enable_flutter=false
enable_swift=false

while [ $# -gt 0 ]; do
  case "$1" in
    --kotlin) enable_kotlin=true ;;
    --flutter) enable_flutter=true ;;
    --swift) enable_swift=true ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 2
      ;;
  esac
  shift
done

args=()

SWIFT_REPORT="coverage-swift/sonarqube-generic-coverage.xml"
UNIT_JACOCO="kotlin_obdii/app/build/reports/jacoco/test/jacocoTestReport.xml"
ANDROID_JACOCO="kotlin_obdii/androidApp/build/reports/coverage/androidTest/debug/connected/report.xml"
FLUTTER_LCOV="flutter_obdii/coverage/lcov.info"

if $enable_swift; then
  [ -f "$SWIFT_REPORT" ] || {
    echo "ERROR: Swift coverage expected but missing at $SWIFT_REPORT" >&2
    exit 1
  }
  bash scripts/verify-swift-coverage-for-sonar.sh "$SWIFT_REPORT"
  args+=("-Dsonar.coverageReportPaths=$SWIFT_REPORT")
else
  rm -f "$SWIFT_REPORT"
  rmdir coverage-swift 2>/dev/null || true
  args+=("-Dsonar.coverageReportPaths=")
fi

if $enable_kotlin; then
  bash scripts/verify-kotlin-coverage-for-sonar.sh
  jacoco_paths=()
  [ -f "$UNIT_JACOCO" ] && jacoco_paths+=("$UNIT_JACOCO")
  [ -f "$ANDROID_JACOCO" ] && jacoco_paths+=("$ANDROID_JACOCO")
  [ "${#jacoco_paths[@]}" -gt 0 ] || {
    echo "ERROR: Kotlin coverage expected but JaCoCo reports are missing" >&2
    exit 1
  }
  args+=("-Dsonar.coverage.jacoco.xmlReportPaths=$(IFS=,; echo "${jacoco_paths[*]}")")
else
  args+=("-Dsonar.coverage.jacoco.xmlReportPaths=")
fi

if $enable_flutter; then
  bash scripts/verify-flutter-coverage-for-sonar.sh
  [ -f "$FLUTTER_LCOV" ] || {
    echo "ERROR: Flutter coverage expected but missing at $FLUTTER_LCOV" >&2
    exit 1
  }
  args+=("-Dsonar.dart.lcov.reportPaths=$FLUTTER_LCOV")
else
  args+=("-Dsonar.dart.lcov.reportPaths=")
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "args<<EOF"
    printf '%s\n' "${args[@]}"
    echo "EOF"
  } >> "$GITHUB_OUTPUT"
else
  printf '%s\n' "${args[@]}"
fi
