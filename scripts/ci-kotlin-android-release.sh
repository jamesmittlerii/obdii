#!/usr/bin/env bash
# Signed Kotlin Android release build for CI (and local parity).
# Used by main_pipeline kotlin_deploy and android_private_release build_kotlin.
#
# Required env:
#   KOTLIN_ANDROID_KEYSTORE_BASE64
#   SP  (store password)
#   KP  (key password)
#   KA  (key alias)
# Optional:
#   KOTLINOBD2_DIR
#
# Usage:
#   bash scripts/ci-kotlin-android-release.sh [gradle tasks...]
# Default task: bundleRelease

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/kotlin_obdii"

if [ -n "${GITHUB_ACTIONS:-}" ]; then
  # gradle-daemon-jvm.properties pins JetBrains + foojay URLs for local dev.
  # setup-java provides Temurin 21 in Actions; avoid foojay download on cold cache.
  printf 'toolchainVersion=21\n' > gradle/gradle-daemon-jvm.properties
fi

: "${KOTLIN_ANDROID_KEYSTORE_BASE64:?KOTLIN_ANDROID_KEYSTORE_BASE64 is required}"
: "${SP:?SP (store password) is required}"
: "${KP:?KP (key password) is required}"
: "${KA:?KA (key alias) is required}"

echo "$KOTLIN_ANDROID_KEYSTORE_BASE64" | base64 -d > androidApp/upload-keystore.jks
printf "storePassword=%s\nkeyPassword=%s\nkeyAlias=%s\nstoreFile=upload-keystore.jks\n" \
  "$SP" "$KP" "$KA" > androidApp/key.properties
chmod +x gradlew

if [ "$#" -eq 0 ]; then
  set -- bundleRelease
fi

./gradlew "$@"
