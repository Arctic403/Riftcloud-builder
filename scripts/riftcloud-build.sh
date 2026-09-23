#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="${1:-source}"
LOG_DIR="${RUNNER_TEMP:-/tmp}/riftcloud-private-logs"
OUTPUT_DIR="${RUNNER_TEMP:-/tmp}/riftcloud-output"
VERIFY_DIR="${RUNNER_TEMP:-/tmp}/riftcloud-verification"
mkdir -p "$LOG_DIR" "$OUTPUT_DIR" "$VERIFY_DIR"

fail() {
  printf '%s\n' "$1" >&2
  printf '%s\n' "$1" > "$LOG_DIR/failure-summary.txt"
  exit 1
}

test -d "$SOURCE_DIR/app" || fail "Private RiftCloud Android source was not found."
for name in RIFTCLOUD_SIGN_STORE RIFTCLOUD_SIGN_STORE_PASS RIFTCLOUD_SIGN_ALIAS RIFTCLOUD_SIGN_KEY_PASS; do
  test -n "${!name:-}" || fail "$name is required."
done
test -f "$RIFTCLOUD_SIGN_STORE" || fail "RiftCloud signing keystore is missing."

GRADLE_LOG="$LOG_DIR/gradle-release.log"
if ! gradle -p "$SOURCE_DIR" :app:assembleRelease --stacktrace >"$GRADLE_LOG" 2>&1; then
  {
    echo "RiftCloud Gradle release build failed."
    echo
    tail -n 400 "$GRADLE_LOG" || true
  } > "$LOG_DIR/failure-summary.txt"
  echo "RiftCloud Gradle release build failed. Detailed diagnostics were retained for the private failure artifact." >&2
  exit 1
fi

UNSIGNED="$SOURCE_DIR/app/build/outputs/apk/release/app-release-unsigned.apk"
if [ ! -f "$UNSIGNED" ]; then
  mapfile -t release_apks < <(find "$SOURCE_DIR/app/build/outputs/apk/release" -maxdepth 1 -type f -name '*.apk' -print 2>/dev/null | sort)
  [ "${#release_apks[@]}" -eq 1 ] || fail "Expected exactly one release APK before signing."
  UNSIGNED="${release_apks[0]}"
fi

ZIPALIGNED="$VERIFY_DIR/RiftCloud-release-aligned.apk"
SIGNED="$OUTPUT_DIR/RiftCloud-release.apk"
zipalign -f -p 4 "$UNSIGNED" "$ZIPALIGNED" >"$LOG_DIR/zipalign.log" 2>&1 || fail "zipalign failed."

apksigner sign --ks "$RIFTCLOUD_SIGN_STORE" --ks-pass "pass:$RIFTCLOUD_SIGN_STORE_PASS" --ks-key-alias "$RIFTCLOUD_SIGN_ALIAS" --key-pass "pass:$RIFTCLOUD_SIGN_KEY_PASS" --out "$SIGNED" "$ZIPALIGNED" >"$LOG_DIR/apksigner-sign.log" 2>&1 || fail "APK signing failed."

bash "$(dirname "$0")/verify-riftcloud-apk.sh" "$SIGNED" "$SOURCE_DIR"

sha256sum "$SIGNED" > "$OUTPUT_DIR/RiftCloud-release.apk.sha256"
apksigner verify --print-certs "$SIGNED" > "$OUTPUT_DIR/RiftCloud-signing-certificate.txt" 2>&1

VERSION_NAME="$(grep -E 'versionName[[:space:]]*=' "$SOURCE_DIR/app/build.gradle.kts" | head -n1 | sed -E 's/.*versionName[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/')"
VERSION_CODE="$(grep -E 'versionCode[[:space:]]*=' "$SOURCE_DIR/app/build.gradle.kts" | head -n1 | sed -E 's/.*versionCode[[:space:]]*=[[:space:]]*([0-9]+).*/\1/')"

{
  printf 'source_sha=%s\n' "${SOURCE_SHA:-unknown}"
  printf 'builder_sha=%s\n' "${GITHUB_SHA:-unknown}"
  printf 'version_name=%s\n' "${VERSION_NAME:-unknown}"
  printf 'version_code=%s\n' "${VERSION_CODE:-unknown}"
  printf 'package=com.riftcloud.app\n'
  printf 'min_sdk=26\n'
  printf 'target_sdk=36\n'
  printf 'abi_policy=neutral-no-native-libraries\n'
  printf 'signing=persistent-private-identity\n'
} > "$OUTPUT_DIR/RiftCloud-build-info.txt"

echo "RiftCloud release APK built, persistently signed and verified."
