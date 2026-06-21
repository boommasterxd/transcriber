# German leftover-language scan — report

**Date:** 2026-06-21
**Scope:** all 134 tracked text files (binaries / gradle wrappers excluded)
**Method:** one Haiku agent per file, run in batches to respect rate limits
(see `tool/scan/scan_german.sh`).

## Result: no genuine leftover German

132 / 134 files came back **CLEAN**. The two files with hits were reviewed
by hand and are **not** policy violations:

### `lib/services/summarization/summary_prompt.dart` — intentional, not a leftover
The German strings form the `german` branch of a symmetric, language-selected
prompt builder (`system(bool german)` / `user(..., german)`) with a fully
parallel English branch. This is effectively i18n of the LLM prompt: the
German text is used only when the user selected German. Allowed.

### `lib/ui/screens/settings/widgets/language_section.dart` — endonyms, not a leftover
`'Deutsch'` / `'English'` / `'Auto'` are hardcoded labels in the language
pickers. Showing a language in its own name (endonym) is the standard
convention and is intentionally not translated. Allowed.

Everywhere else — comments, doc comments, identifiers, configs, build files,
logs and developer-facing error messages — is English. User-facing German
copy lives in the i18n dictionary `lib/core/l10n/app_strings.dart`, exactly as
required.

## Re-running

```bash
ANTHROPIC_API_KEY=sk-... tool/scan/scan_german.sh
```

The scan also runs in CI via `.github/workflows/german-scan.yml` when the
`ANTHROPIC_API_KEY` secret is configured, and fails the job if any leftover
German is found.
