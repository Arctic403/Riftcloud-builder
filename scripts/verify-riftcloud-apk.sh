#!/usr/bin/env bash
set -euo pipefail

APK="${1:?APK path required}"

test -f "$APK" || { echo "APK missing: $APK" >&2; exit 1; }

zipalign -c -p 4 "$APK" >/dev/null
apksigner verify --verbose --print-certs "$APK" >/dev/null

if unzip -Z1 "$APK" | grep -Eq '^lib/[^/]+/[^/]+\.so$'; then
  echo "RiftCloud must remain ABI-neutral, but native .so libraries were packaged." >&2
  exit 1
fi

BADGING="$(aapt dump badging "$APK")"
printf '%s\n' "$BADGING" | grep -q "package: name='com.riftcloud.app'" || {
  echo "Unexpected RiftCloud applicationId." >&2
  exit 1
}
printf '%s\n' "$BADGING" | grep -q "sdkVersion:'26'" || {
  echo "Unexpected RiftCloud minSdk." >&2
  exit 1
}
printf '%s\n' "$BADGING" | grep -q "targetSdkVersion:'36'" || {
  echo "Unexpected RiftCloud targetSdk." >&2
  exit 1
}

test "$(stat -c '%s' "$APK")" -gt 32768 || {
  echo "APK is unexpectedly small." >&2
  exit 1
}

echo "RiftCloud debug APK verification passed."
