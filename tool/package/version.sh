#!/usr/bin/env bash
# Prints the release version (no leading "v", no build "+N" suffix).
# Resolution order: RELEASE_VERSION env -> git tag -> pubspec.yaml.
set -euo pipefail

if [[ -n "${RELEASE_VERSION:-}" ]]; then
  ver="${RELEASE_VERSION#v}"
elif [[ "${GITHUB_REF:-}" == refs/tags/* ]]; then
  tag="${GITHUB_REF#refs/tags/}"
  ver="${tag#v}"
else
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  line="$(grep -m1 '^version:' "$root/pubspec.yaml")"
  ver="${line#version:}"; ver="${ver// /}"; ver="${ver%%+*}"
fi
bash "$(dirname "${BASH_SOURCE[0]}")/validate_version.sh" "$ver"
printf '%s\n' "$ver"
