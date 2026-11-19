#!/usr/bin/env bash
set -euo pipefail
event="${1:?usage: verify_release_source.sh <event> <ref> <ref-protected>}"
ref="${2:?missing source ref}"
protected="${3:?missing ref protection status}"

if [[ "$event" != workflow_dispatch || "$ref" != refs/heads/main || "$protected" != true ]]; then
  echo 'Releases require a manual dispatch from protected main.' >&2
  exit 1
fi

if ! git merge-base --is-ancestor HEAD refs/remotes/origin/main; then
  echo 'The release source must be reachable from main.' >&2
  exit 1
fi
