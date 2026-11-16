#!/usr/bin/env bash
set -euo pipefail

SDK_ROOT=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}
if [[ "$SDK_ROOT" != /* || ! -d "$SDK_ROOT" ]]; then
  printf 'An existing absolute Android SDK root is required.\n' >&2
  exit 1
fi

ndk_installed() {
  local version=$1
  local properties="$SDK_ROOT/ndk/$version/source.properties"
  [[ -f "$properties" ]] || return 1
  awk -F= -v revision="$version" '
    $1 ~ /^[[:space:]]*Pkg[.]Revision[[:space:]]*$/ {
      value = $2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      if (value == revision) found = 1
    }
    END { exit !found }
  ' "$properties"
}

find_sdkmanager() {
  if [[ -x "$SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" ]]; then
    printf '%s\n' "$SDK_ROOT/cmdline-tools/latest/bin/sdkmanager"
  elif [[ -d "$SDK_ROOT/cmdline-tools" ]]; then
    find "$SDK_ROOT/cmdline-tools" -type f -name sdkmanager -perm -u+x | sort -V | tail -n 1
  fi
}

install_ndk() {
  local version=$1
  local sdkmanager=$2
  local status=1
  for attempt in 1 2 3 4; do
    rm -rf -- "$SDK_ROOT/ndk/$version"
    if timeout 300 "$sdkmanager" --sdk_root="$SDK_ROOT" "ndk;$version" < <(yes); then
      if ndk_installed "$version"; then
        printf 'NDK %s installed and validated.\n' "$version"
        return 0
      fi
      status=1
    else
      status=$?
    fi
    printf 'NDK %s installation attempt %s failed.\n' "$version" "$attempt" >&2
    if [[ "$attempt" -lt 4 ]]; then sleep "$((attempt * 5))"; fi
  done
  printf 'NDK %s could not be installed and validated.\n' "$version" >&2
  return "$status"
}

SDKMANAGER=
for version in 28.0.13004108 28.2.13676358; do
  if ndk_installed "$version"; then
    printf 'NDK %s already installed and validated.\n' "$version"
    continue
  fi
  if [[ -z "$SDKMANAGER" ]]; then
    SDKMANAGER=$(find_sdkmanager)
    if [[ -z "$SDKMANAGER" ]]; then
      printf 'Android sdkmanager is unavailable.\n' >&2
      exit 1
    fi
  fi
  install_ndk "$version" "$SDKMANAGER"
done
