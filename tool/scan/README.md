# German leftover-language scan

`scan_german.sh` audits **every tracked text file** in the repository for
leftover German that should be English. It runs **one model call per file**
(the file is inlined with line numbers), in batches with a sleep between them
so large repos don't trip API rate limits. It uses the fast/cheap **Haiku**
model by default.

## Policy

German is **allowed only** in:

- the i18n dictionary `lib/core/l10n/app_strings.dart` (UI copy);
- the German branch of the symmetric localized LLM prompt builder
  (`lib/services/summarization/summary_prompt.dart`), which has a parallel
  English branch selected by language;
- language **endonyms** in the language picker (e.g. `'Deutsch'`).

German is **forbidden** everywhere else: code comments, doc comments,
identifiers, config keys/values, build configs, log/debug messages and
developer-facing error messages.

## Usage

```bash
ANTHROPIC_API_KEY=sk-... tool/scan/scan_german.sh
```

Environment overrides:

| Variable        | Default                        | Meaning                                |
|-----------------|--------------------------------|----------------------------------------|
| `MODEL`         | `claude-haiku-4-5-20251001`    | Model id (use a Sonnet id for depth)   |
| `BATCH_SIZE`    | `12`                           | Files scanned concurrently per batch   |
| `SLEEP_SECONDS` | `5`                            | Pause between batches (rate limiting)   |
| `OUT_DIR`       | a `mktemp -d`                  | Where per-file results are written     |

The script exits `0` when nothing is found and `1` when any file has
findings, so it can gate CI. A ready-made GitHub Actions job lives at
`.github/workflows/german-scan.yml` (runs only when the `ANTHROPIC_API_KEY`
secret is configured).

Requirements: `bash`, `git`, `jq`, `curl`.
