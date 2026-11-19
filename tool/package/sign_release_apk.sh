#!/usr/bin/env bash
set -euo pipefail
version="${1:?usage: sign_release_apk.sh <version> <unsigned-apk> <output-directory> <signer-sha256>}"
input="${2:?missing unsigned APK}"
output="${3:?missing signed artifact directory}"
signer="${4:?missing expected certificate SHA-256}"
: "${ANDROID_BUILD_TOOLS:?set ANDROID_BUILD_TOOLS to the SDK build-tools directory}"
: "${RELEASE_KEYSTORE_BASE64:?missing release-signing environment keystore}"
: "${RELEASE_KEYSTORE_PASSWORD:?missing release-signing environment keystore password}"
: "${RELEASE_KEY_PASSWORD:?missing release-signing environment key password}"
: "${RELEASE_KEY_ALIAS:?missing release-signing environment key alias}"
scripts="$(dirname "${BASH_SOURCE[0]}")"
bash "$scripts/validate_version.sh" "$version"

if [[ ! -s "$input" || ! -f "$input" || -L "$input" ]] \
  || "$ANDROID_BUILD_TOOLS/apksigner" verify "$input" > /dev/null 2>&1; then
  echo 'Expected an unsigned Android APK.' >&2
  exit 1
fi

umask 077
scratch=$(mktemp -d)
trap 'rm -f -- "$scratch/keystore" "$scratch/aligned.apk"; rmdir -- "$scratch"' EXIT
printf '%s' "$RELEASE_KEYSTORE_BASE64" | base64 --decode > "$scratch/keystore"
unset RELEASE_KEYSTORE_BASE64

apk="transcriber-$version-android.apk"
mkdir "$output"
"$ANDROID_BUILD_TOOLS/zipalign" -P 16 -f 4 "$input" "$scratch/aligned.apk"
"$ANDROID_BUILD_TOOLS/apksigner" sign --ks "$scratch/keystore" \
  --ks-key-alias "$RELEASE_KEY_ALIAS" --ks-pass env:RELEASE_KEYSTORE_PASSWORD \
  --key-pass env:RELEASE_KEY_PASSWORD --v4-signing-enabled false \
  --out "$output/$apk" "$scratch/aligned.apk"
unset RELEASE_KEYSTORE_PASSWORD RELEASE_KEY_PASSWORD RELEASE_KEY_ALIAS
bash "$scripts/verify_apk_identity.sh" "$output/$apk" com.transcriber.app "$signer"
(
  cd "$output"
  sha256sum "$apk" > SHA256SUMS
)
