#!/usr/bin/env bash
set -euo pipefail
apk="${1:?usage: verify_apk_identity.sh <apk> <app-id> [signer-sha256]}"
app_id="${2:?missing expected Android application ID}"
expected_signer="${3:-}"
: "${ANDROID_BUILD_TOOLS:?set ANDROID_BUILD_TOOLS to the SDK build-tools directory}"

package_info=$("$ANDROID_BUILD_TOOLS/aapt" dump badging "$apk")
if [[ "$package_info" != "package: name='$app_id' "* ]]; then
  echo 'The APK application ID does not match the expected package.' >&2
  exit 1
fi

if [[ -z "$expected_signer" ]]; then
  "$ANDROID_BUILD_TOOLS/apksigner" verify "$apk"
  exit
fi

certificates=$("$ANDROID_BUILD_TOOLS/apksigner" verify --print-certs "$apk")
signer=$(awk '/^Signer #[0-9]+ certificate SHA-256 digest: / {print $NF}' <<< "$certificates")
if [[ ! "$expected_signer" =~ ^[a-f0-9]{64}$ || "$signer" != "$expected_signer" ]]; then
  echo 'The APK signer does not match the established release certificate.' >&2
  exit 1
fi
