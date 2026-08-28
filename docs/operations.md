# Operations

## Prerequisites

- Flutter from `.fvmrc`
- Android SDK and a supported Java runtime
- an arm64 Android device or emulator
- personal OpenAI and/or Gemini API keys for the selected stages

Device-level verification is required for secure storage, recording, file selection, Android share intents, and release signing.

## Setup

```bash
flutter pub get --enforce-lockfile
flutter run
```

On first launch, select providers and models, add the required keys, review the cloud data notice, and grant microphone access for in-app recording. A key is saved only after its provider accepts an authenticated model-list request.

## Validation

Run the complete commands in [code quality](code-quality.md). The minimum implementation checks are:

```bash
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --fatal-infos
flutter test --coverage --branch-coverage
flutter build bundle --debug
```

Run Android quality checks separately:

```bash
bash tool/quality/check_kotlin_quality.sh
```

## Database Migration Verification

Before releasing the first Drift-backed version, install the previous production version, create settings, notes, points, to-dos, and transcript segments, then upgrade in place. Verify:

- all valid legacy records appear once;
- provider selections map to OpenAI or Google;
- historical provider/model labels remain unchanged on notes;
- corrupt legacy values remain available for recovery;
- valid legacy SharedPreferences values are removed only after database commit;
- OpenAI and Google keys remain accessible from secure storage;
- obsolete Hugging Face, Anthropic, and OpenRouter keys are removed.

## Provider Smoke Tests

Use non-production audio without personal information. Test all selected combinations:

1. OpenAI transcription and OpenAI summary
2. OpenAI transcription and Gemini summary
3. Gemini transcription and OpenAI summary
4. Gemini transcription and Gemini summary

Also test summary disabled, key replacement failure, provider throttling, network timeout, malformed provider responses, cancellation, and retry.

## Troubleshooting

- Key validation fails: verify the key, project, API billing, quota, and network connection.
- A model is absent from the live list: the documented default remains available; confirm provider access before selecting another identifier.
- Import is rejected: verify file size and supported extension.
- A shared file is rejected: confirm the source provides a supported filename and a readable audio stream.
- Processing times out: retry on a stable network and inspect provider status without logging credentials or transcript content.
- Processing is interrupted after leaving the app: keep Transcriber visible and retry. Cloud requests intentionally do not run in an Android foreground service.
- Migration fails: preserve the original SharedPreferences payload and inspect the database transaction error before retrying.

## Release

The Android package remains arm64-only. Preserve release signing, checksum verification, and minimal Android permissions. The main activity is exported for the launcher and audio `VIEW` intents. The exported share activity accepts audio `SEND` intents and copies them through bounded, sanitized app-private storage.
