#!/usr/bin/env bash
# Accept a SemVer release name without build metadata (the run supplies it).
set -euo pipefail
version="${1:?usage: validate_version.sh <version>}"
number='(0|[1-9][0-9]*)'
identifier="($number|[0-9]*[A-Za-z-][0-9A-Za-z-]*)"
pattern="^$number\.$number\.$number(-$identifier(\.$identifier)*)?$"
if [[ ! "$version" =~ $pattern ]]; then
  echo 'Invalid release version: expected SemVer without build metadata.' >&2
  exit 1
fi
