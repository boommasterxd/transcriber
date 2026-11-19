#!/usr/bin/env bash
set -euo pipefail
version="${1:?usage: verify_release_assets.sh <release-version> <artifact-directory>}"
directory="${2:?missing artifact directory}"
bash "$(dirname "${BASH_SOURCE[0]}")/validate_version.sh" "$version"
cd "$directory"
apk="transcriber-$version-android.apk"
shopt -s dotglob nullglob
entries=(*)
if [[ ${#entries[@]} -ne 2 || ! -s "$apk" || ! -f "$apk" || -L "$apk" \
    || ! -s SHA256SUMS || ! -f SHA256SUMS || -L SHA256SUMS ]]; then
  echo 'Expected exactly one named release APK and its SHA256SUMS file.' >&2
  exit 1
fi

if ! sha256sum "$apk" | cmp --silent - SHA256SUMS; then
  echo 'Release APK does not match SHA256SUMS.' >&2
  exit 1
fi
