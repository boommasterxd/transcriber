#!/usr/bin/env bash
# Prints the release version (no leading "v", no build "+N" suffix).
# Resolution order: RELEASE_VERSION env -> git tag -> pubspec.yaml.
set -euo pipefail

if [[ -n "${RELEASE_VERSION:-}" ]]; then
  v="${RELEASE_VERSION#v}"; echo "${v// /}"; exit 0
fi
ref="${GITHUB_REF:-}"
if [[ "$ref" == refs/tags/* ]]; then
  tag="${ref#refs/tags/}"; echo "${tag#v}"; exit 0
fi
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
line="$(grep -m1 '^version:' "$root/pubspec.yaml")"
ver="${line#version:}"; ver="${ver// /}"; echo "${ver%%+*}"
