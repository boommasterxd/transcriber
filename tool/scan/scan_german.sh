#!/usr/bin/env bash
#
# scan_german.sh — Scan every tracked file for LEFTOVER German text.
#
# Policy enforced:
#   * German is ALLOWED only in user-facing UI strings routed through the
#     i18n dictionary (lib/core/l10n/app_strings.dart), in the symmetric
#     German branch of the localized LLM prompt builder, and as language
#     endonyms in the language picker.
#   * German is FORBIDDEN everywhere else: code comments, doc comments,
#     identifiers, config keys/values, build configs, log/debug messages and
#     developer-facing error messages.
#
# Design ("one agent per file, mind the rate limits"):
#   * One model call per file (the file's content is inlined, line-numbered).
#   * Files are processed in batches; the script sleeps between batches so a
#     large repo does not trip API rate limits.
#   * The cheap, fast Haiku model is used by default; override with MODEL=...
#
# Requirements: bash, git, jq, curl, and an ANTHROPIC_API_KEY in the env.
#
# Usage:
#   ANTHROPIC_API_KEY=sk-... tool/scan/scan_german.sh
#   BATCH_SIZE=12 SLEEP_SECONDS=5 MODEL=claude-haiku-4-5-20251001 \
#     tool/scan/scan_german.sh
#
# Exit code: 0 if no leftover German is found, 1 if any file has FINDINGS.

set -euo pipefail

MODEL="${MODEL:-claude-haiku-4-5-20251001}"
BATCH_SIZE="${BATCH_SIZE:-12}"
SLEEP_SECONDS="${SLEEP_SECONDS:-5}"
OUT_DIR="${OUT_DIR:-$(mktemp -d)}"
API_URL="https://api.anthropic.com/v1/messages"

if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "error: ANTHROPIC_API_KEY is not set" >&2
  exit 2
fi
for bin in git jq curl; do
  command -v "$bin" >/dev/null 2>&1 || { echo "error: '$bin' is required" >&2; exit 2; }
done

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"
mkdir -p "$OUT_DIR"

# Tracked, text-only files (skip known binaries / wrappers).
mapfile -t FILES < <(
  git ls-files | grep -ivE \
    '\.(jar|png|jpe?g|ico|webp|ttf|otf|keystore|jks|bin|so|a|zip|gz|woff2?)$|gradlew$|gradlew\.bat$'
)

SYSTEM_PROMPT='You audit ONE source file for LEFTOVER GERMAN text that should be English.
German is ALLOWED ONLY in user-facing UI strings / i18n dictionaries, in the
German branch of a symmetric localized LLM prompt builder, and as language
endonyms (e.g. "Deutsch") in a language picker. German is FORBIDDEN everywhere
else: code comments, doc comments, identifiers, config keys/values, build
configs, log/debug messages, developer-facing error messages.
Do NOT flag English text, technical terms, or proper nouns (Gemma, Whisper,
Anthropic, OpenAI, Flutter). The file content is given with line numbers.
Respond with ONLY a JSON object, no prose, of the form:
{"status":"CLEAN"} or
{"status":"FINDINGS","items":[{"line":<n>,"category":"comment|config|log|identifier|doc|hardcoded-ui|prompt|other","snippet":"<short german>","suggest":"<english>"}]}'

scan_one() {
  local path="$1" idx="$2"
  local numbered content payload body status items
  numbered="$(cat -n -- "$path")"
  content=$(printf 'FILE: %s\n\n%s' "$path" "$numbered")

  payload=$(jq -n \
    --arg model "$MODEL" \
    --arg system "$SYSTEM_PROMPT" \
    --arg content "$content" \
    '{model:$model, max_tokens:1024, system:$system,
      messages:[{role:"user", content:$content}]}')

  body=$(curl -sS "$API_URL" \
    -H "x-api-key: ${ANTHROPIC_API_KEY}" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d "$payload") || { echo "$path ERROR (request failed)"; return; }

  # Extract the model's text, then the JSON object it contains.
  local text json
  text=$(jq -r '.content[0].text // empty' <<<"$body")
  json=$(sed -n 's/.*\({.*}\).*/\1/p' <<<"$(printf '%s' "$text" | tr '\n' ' ')")
  [[ -z "$json" ]] && json="$text"

  status=$(jq -r '.status // "PARSE_ERROR"' <<<"$json" 2>/dev/null || echo PARSE_ERROR)
  {
    printf 'FILE: %s\nSTATUS: %s\n' "$path" "$status"
    if [[ "$status" == "FINDINGS" ]]; then
      jq -r '.items[] | "- line \(.line) [\(.category)]: \"\(.snippet)\" -> suggest: \(.suggest)"' \
        <<<"$json" 2>/dev/null || true
    fi
  } >"$OUT_DIR/$(printf '%04d' "$idx").txt"
  echo "$path $status"
}

echo "Scanning ${#FILES[@]} files with $MODEL (batch=$BATCH_SIZE, sleep=${SLEEP_SECONDS}s)"
echo "Output: $OUT_DIR"
i=0
for f in "${FILES[@]}"; do
  scan_one "$f" "$i" &
  i=$((i + 1))
  if (( i % BATCH_SIZE == 0 )); then
    wait
    sleep "$SLEEP_SECONDS"   # back off between batches to respect rate limits
  fi
done
wait

echo
echo "=== SUMMARY ==="
clean=$(grep -l '^STATUS: CLEAN' "$OUT_DIR"/*.txt 2>/dev/null | wc -l | tr -d ' ')
findings_files=$(grep -l '^STATUS: FINDINGS' "$OUT_DIR"/*.txt 2>/dev/null || true)
echo "CLEAN: $clean / ${#FILES[@]}"
if [[ -n "$findings_files" ]]; then
  echo "FILES WITH LEFTOVER GERMAN:"
  for f in $findings_files; do echo; cat "$f"; done
  exit 1
fi
echo "No leftover German found."
