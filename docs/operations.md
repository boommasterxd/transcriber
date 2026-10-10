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

On first launch, expand a provider row on **Connect a provider** to connect OpenAI and/or Google Gemini. Each provider key is shared by both tasks and is saved only after its provider accepts an authenticated model-list request. The next screen shows **Speech to text** and optional **Summary** task cards. Tap a card's model row to open its available API models, choose a connected provider when needed, then tap a model to save it immediately and close the picker. Back, backdrop dismissal, or dragging the handle down without choosing a model preserves the saved selection. Pull the model list down to refresh it without changing settings; F5 or the screen-reader refresh action offers the same operation. Continue after choosing available models, then configure appearance and microphone access for recording. Later, **Settings > Model selection** offers the same cards without the wizard. Open its **Providers & API keys** entry to manage credentials. **Settings > General** combines language and region, appearance, and privacy. The overview footer shows the installed app version and build number.

To enable keyboard dictation, open **Settings > Transcriber keyboard** and select **Start setup** in the keyboard card. The dedicated setup screen shows the effective live provider and guides the user through **Enable in Android** and **Select the keyboard**. It finishes only after Android reports Transcriber as the selected input method. Completed setup is shown as **Manage keyboard** instead of another setup prompt. Android controls the system keyboard switcher shown by Samsung Keyboard and Gboard.

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
- render and operate the 312 dp Flutter keyboard with touch and TalkBack, confirming it never enters fullscreen extract mode;
- use Samsung Keyboard and Gboard as the previous keyboard;
- dictate in WhatsApp, a browser text field, and a multiline editor;
- verify partial and finalized segments remain one composing transcript without duplication until stop commits it once;
- discard after multiple finalized segments and confirm the complete current dictation disappears while pre-existing editor text remains;
- tap backspace to delete one code point, delete a selected range, and hold it to verify accelerated repeat deletion stops immediately on release;
- pause and resume dictation, confirming the timer and waveform freeze, no paused audio is sent, and the existing live session continues;
- block network access before starting and confirm the keyboard leaves the connecting state with a timeout message within the bounded connection deadline;
- stop while a partial segment exists and verify the last segment is finalized;
- change fields, switch applications, hide or replace the keyboard, and confirm recording stops immediately;
- press Home, lock and unlock the display, and immediately reopen the previous editor, confirming the keyboard returns ready instead of showing a stale unavailable surface;
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

Force a summary failure after successful transcription and verify that the regular screen saves a transcript-only note with a visible warning and expandable transcript. In the share popup, verify both explicit save and discard. Reopen a saved note and confirm that the warning and sanitized diagnostic remain, summary sections are hidden, and the full transcript is readable. Check phone and tablet layouts, keyboard operation, and TalkBack. Transcription failures must still show the processing error screen without creating a note.

## Troubleshooting

- Key validation fails: verify the key, project, API billing, quota, and network connection.
- A model is absent from the live list: the provider must return it for the connected key and its name, description, and available API methods must pass purpose filtering. New versions do not require an app update. Confirm provider access and choose an available replacement for an unavailable saved model. Provider metadata cannot prove endpoint compatibility; unusually named specialists may require a filtering-rule correction.
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
