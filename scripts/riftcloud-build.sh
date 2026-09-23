#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="${1:-source}"
LOG_DIR="${RUNNER_TEMP:-/tmp}/riftcloud-private-logs"
OUTPUT_DIR="${RUNNER_TEMP:-/tmp}/riftcloud-output"
mkdir -p "$LOG_DIR" "$OUTPUT_DIR"

fail() {
  printf '%s\n' "$1" >&2
  printf '%s\n' "$1" > "$LOG_DIR/failure-summary.txt"
  exit 1
}

test -d "$SOURCE_DIR/app" || fail "RiftCloud Android source was not found."

GRADLE_LOG="$LOG_DIR/gradle-debug.log"
if ! gradle -p "$SOURCE_DIR" :app:assembleDebug --stacktrace >"$GRADLE_LOG" 2>&1; then
  {
    echo "RiftCloud Gradle debug build failed."
    echo
    tail -n 400 "$GRADLE_LOG" || true
  } > "$LOG_DIR/failure-summary.txt"
  echo "RiftCloud Gradle debug build failed. Detailed diagnostics were retained outside the public log." >&2
  exit 1
fi

BUILT_APK="$SOURCE_DIR/app/build/outputs/apk/debug/app-debug.apk"
test -f "$BUILT_APK" || fail "Expected debug APK was not produced."

APK="$OUTPUT_DIR/RiftCloud-debug.apk"
cp "$BUILT_APK" "$APK"

bash "$(dirname "$0")/verify-riftcloud-apk.sh" "$APK"

sha256sum "$APK" > "$OUTPUT_DIR/RiftCloud-debug.apk.sha256"
apksigner verify --print-certs "$APK" > "$OUTPUT_DIR/RiftCloud-debug-signing-certificate.txt" 2>&1

VERSION_NAME="$(grep -E 'versionName[[:space:]]*=' "$SOURCE_DIR/app/build.gradle.kts" | head -n1 | sed -E 's/.*versionName[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/')"
VERSION_CODE="$(grep -E 'versionCode[[:space:]]*=' "$SOURCE_DIR/app/build.gradle.kts" | head -n1 | sed -E 's/.*versionCode[[:space:]]*=[[:space:]]*([0-9]+).*/\1/')"

{
  printf 'source_sha=%s\n' "${SOURCE_SHA:-unknown}"
  printf 'builder_sha=%s\n' "${GITHUB_SHA:-unknown}"
  printf 'builder_run_id=%s\n' "${GITHUB_RUN_ID:-unknown}"
  printf 'version_name=%s\n' "${VERSION_NAME:-unknown}"
  printf 'version_code=%s\n' "${VERSION_CODE:-unknown}"
  printf 'package=com.riftcloud.app\n'
  printf 'min_sdk=26\n'
  printf 'target_sdk=36\n'
  printf 'abi_policy=neutral-no-native-libraries\n'
  printf 'signing=android-debug\n'
  printf 'update_lineage=not-guaranteed-across-builder-runs\n'
} > "$OUTPUT_DIR/RiftCloud-build-info.txt"

echo "RiftCloud debug APK built and verified."
