#!/usr/bin/env bash
set -euo pipefail

APK="${1:?APK path required}"
SOURCE_DIR="${2:?source directory required}"

test -f "$APK" || { echo "APK missing: $APK" >&2; exit 1; }
test -f "$SOURCE_DIR/app/build.gradle.kts" || { echo "RiftCloud Gradle metadata missing." >&2; exit 1; }

zipalign -c -p 4 "$APK" >/dev/null
apksigner verify --verbose --print-certs "$APK" >/dev/null

if unzip -Z1 "$APK" | grep -Eq '^lib/[^/]+/[^/]+\.so$'; then
  echo "RiftCloud must remain ABI-neutral, but native .so libraries were packaged." >&2
  exit 1
fi

grep -q 'applicationId = "com.riftcloud.app"' "$SOURCE_DIR/app/build.gradle.kts" || {
  echo "Unexpected RiftCloud applicationId." >&2
  exit 1
}
grep -q 'minSdk = 26' "$SOURCE_DIR/app/build.gradle.kts" || {
  echo "Unexpected RiftCloud minSdk." >&2
  exit 1
}
grep -q 'targetSdk = 36' "$SOURCE_DIR/app/build.gradle.kts" || {
  echo "Unexpected RiftCloud targetSdk." >&2
  exit 1
}

test "$(stat -c '%s' "$APK")" -gt 32768 || {
  echo "APK is unexpectedly small." >&2
  exit 1
}

echo "RiftCloud APK verification passed."
