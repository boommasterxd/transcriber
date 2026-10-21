#!/usr/bin/env bash
set -euo pipefail

DETEKT_VERSION=1.23.8
DETEKT_CLI_SHA256=3afe89a11120303c73c9bdda3d8fe558dd9070a6937d27819ddc04b275381245
DETEKT_FORMATTING_SHA256=a18a3f680d232ad746ccec3d5a251776ce39131b395c455b92e1bb0a9e8fb6ba
DETEKT_DIR=$(mktemp -d)
trap 'rm -rf -- "$DETEKT_DIR"' EXIT

# Git inventories maintained scripts and every source set without generated output.
git ls-files --cached --others --exclude-standard -z -- '*.kt' '*.kts' > "$DETEKT_DIR/sources"
DETEKT_SOURCES=()
while IFS= read -r -d '' source; do
  [[ -f "$source" ]] || continue
  if [[ "$source" == *,* ]]; then
    printf 'Detekt cannot represent a source path containing a comma: %s\n' "$source" >&2
    exit 1
  fi
  DETEKT_SOURCES+=("$source")
done < "$DETEKT_DIR/sources"
if [[ ${#DETEKT_SOURCES[@]} -eq 0 ]]; then
  printf 'No maintained Kotlin sources were found.\n' >&2
  exit 1
fi
DETEKT_INPUT=$(IFS=,; printf '%s' "${DETEKT_SOURCES[*]}")

DETEKT_BASE_URL="https://repo.maven.apache.org/maven2/io/gitlab/arturbosch/detekt"
DETEKT_CLI="$DETEKT_DIR/detekt-cli.jar"
DETEKT_FORMATTING="$DETEKT_DIR/detekt-formatting.jar"

curl --fail --silent --show-error --location \
  "$DETEKT_BASE_URL/detekt-cli/$DETEKT_VERSION/detekt-cli-$DETEKT_VERSION-all.jar" \
  --output "$DETEKT_CLI"
curl --fail --silent --show-error --location \
  "$DETEKT_BASE_URL/detekt-formatting/$DETEKT_VERSION/detekt-formatting-$DETEKT_VERSION.jar" \
  --output "$DETEKT_FORMATTING"

printf '%s  %s\n' "$DETEKT_CLI_SHA256" "$DETEKT_CLI" | sha256sum --check
printf '%s  %s\n' "$DETEKT_FORMATTING_SHA256" "$DETEKT_FORMATTING" | sha256sum --check

java -jar "$DETEKT_CLI" \
  --input "$DETEKT_INPUT" \
  --config config/detekt.yml \
  --build-upon-default-config \
  --plugins "$DETEKT_FORMATTING"
