#!/usr/bin/env bash
# Print the release tag only if it is absent or resolves to the built commit.
set -euo pipefail
version="${1:?usage: verify_release_tag.sh <version> <built-commit>}"
commit="${2:?usage: verify_release_tag.sh <version> <built-commit>}"
bash "$(dirname "${BASH_SOURCE[0]}")/validate_version.sh" "$version"
if [[ ! "$commit" =~ ^[0-9a-f]{40}$ ]]; then
  echo 'Invalid built commit SHA.' >&2
  exit 1
fi
tag="v$version"
# Query the authoritative remote immediately before publishing. The peeled ref
# makes annotated tags comparable to lightweight tags without fetching history.
refs="$(timeout 30s git ls-remote origin "refs/tags/$tag" "refs/tags/$tag^{}")"
target=''
while read -r sha ref; do
  if [[ "$ref" == "refs/tags/$tag^{}" ]]; then
    target="$sha"
    break
  elif [[ "$ref" == "refs/tags/$tag" ]]; then
    target="$sha"
  fi
done <<< "$refs"
if [[ -n "$target" && "$target" != "$commit" ]]; then
  echo 'Release tag does not match the built commit; publication refused.' >&2
  exit 1
fi
printf '%s\n' "$tag"
