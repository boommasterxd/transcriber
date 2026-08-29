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

On first launch, select providers and models, add the required keys, review the cloud data notice, and grant microphone access for recording. A key is saved only after its provider accepts an authenticated model-list request.

To enable keyboard dictation, open Settings in Transcriber and select **Start setup** in the Transcriber keyboard card. The dedicated setup screen shows the effective live provider and guides the user through **Enable in Android** and **Select the keyboard**. It finishes only after Android reports Transcriber as the selected input method. Completed setup is shown as **Manage keyboard** instead of another setup prompt. Android controls the system keyboard switcher shown by Samsung Keyboard and Gboard.

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
JAVA_HOME=/path/to/jdk17 android/gradlew -p android \
  :app:testDebugUnitTest :app:compileDebugAndroidTestKotlin
```

Run instrumented Android tests on an attached device or emulator:

```bash
JAVA_HOME=/path/to/jdk17 android/gradlew -p android \
  :app:connectedDebugAndroidTest
```

## Keyboard Dictation Verification

Use non-production speech without personal information. Verify the complete matrix on at least one current Samsung device and one current Pixel device:

- enable, select, and switch back from the Transcriber input method through Android;
- render and operate the 280 dp Flutter keyboard with touch and TalkBack, confirming it never enters fullscreen extract mode;
- use Samsung Keyboard and Gboard as the previous keyboard;
- dictate in WhatsApp, a browser text field, and a multiline editor;
- verify partial composing text is replaced without duplication and final text is committed once;
- pause and resume dictation, confirming the timer and waveform freeze, no paused audio is sent, and the existing live session continues;
- stop while a partial segment exists and verify the last segment is finalized;
- change fields, switch applications, hide or replace the keyboard, and confirm recording stops immediately;
- interrupt and restore the network, then confirm bounded reconnect behavior and no duplicated text;
- terminate the app and keyboard process, then verify that microphone and socket resources are released;
- confirm password fields, PIN fields, and other sensitive editors cannot start dictation;
- inspect light and dark themes, large system text, landscape constraints, visible focus, and TalkBack labels.

Provider smoke tests must cover both `gpt-live-transcribe` and `gemini-3.5-transcribe-live`, including denied microphone permission, missing or invalid keys, provider rejection, network timeout, explicit cancel, and normal stop.

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
- Keyboard recording does not start: confirm microphone permission, a valid key for the selected transcription provider, and a normal non-sensitive text field.
- The keyboard does not appear in the picker: use the Transcriber settings card to open Android's input-method settings and enable it first.
- Live setup is rejected: follow the keyboard's specific authentication, quota, model-access, configuration, or timeout message. Gemini language hints must use supported BCP-47 values such as `de-DE` and `en-US`; OpenAI live transcription may require billing or model access beyond basic key validation.
- Live text stops updating: stop the session and retry on a stable network. Switching fields or hiding the keyboard intentionally terminates the current session.
- Migration fails: preserve the original SharedPreferences payload and inspect the database transaction error before retrying.

## Release

The Android package remains arm64-only. Preserve release signing, checksum verification, and minimal Android permissions. The main activity is exported for the launcher and audio `VIEW` intents. The exported share activity accepts audio `SEND` intents and copies them through bounded, sanitized app-private storage. The exported input-method service must remain protected by `android.permission.BIND_INPUT_METHOD`.
