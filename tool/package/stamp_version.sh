#!/usr/bin/env bash
# Stamps "<version>+<build>" into pubspec.yaml's `version:` line.
# Usage: stamp_version.sh <version> <build-number>
set -euo pipefail
version="${1:?usage: stamp_version.sh <version> <build-number>}"
build="${2:?usage: stamp_version.sh <version> <build-number>}"
bash "$(dirname "${BASH_SOURCE[0]}")/validate_version.sh" "$version"
if [[ ! "$build" =~ ^[1-9][0-9]*$ ]]; then
  echo 'Invalid build number: expected a positive integer.' >&2
  exit 1
fi
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
sed -i.bak -E "s/^version:.*/version: ${version}+${build}/" "$root/pubspec.yaml"
rm -f "$root/pubspec.yaml.bak"
grep '^version:' "$root/pubspec.yaml"
