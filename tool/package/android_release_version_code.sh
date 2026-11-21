#!/usr/bin/env bash
set -euo pipefail
run_number="${1:?usage: android_release_version_code.sh <release-run-number>}"
if [[ ! "$run_number" =~ ^[1-9][0-9]{0,9}$ ]] || (( run_number > 2099999000 )); then
  echo 'Invalid release run number for the Android version code.' >&2
  exit 1
fi
# Earlier on-demand APKs shared the production app ID and used a separate counter.
printf '%d\n' "$((1000 + run_number))"
