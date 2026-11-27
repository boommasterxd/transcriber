# Operations

## Interrupted Android Audio Selection

When Android recreates the app while the system document picker is open, the normal entry point offers the recovered audio once onboarding is complete. Confirming starts processing the validated app-owned copy. Cancelling or dismissing the offer removes that copy and leaves the original with its document provider. A new selection supersedes pending recovery. Recovery errors use the generic import error and permit a fresh selection.

For device verification, open the system picker with synthetic audio and simulate OS process recreation while the picker remains in the foreground. Then select the file and verify that the recreated app offers exactly one confirmation. Verify that cancellation sends no provider request and confirmation processes once. Repeat with microphone permission revoked to verify the picker and recovery remain usable. Use OS process recreation because a force-stop can suppress result delivery.

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

On first launch, expand a provider row on **Connect a provider** to connect OpenAI or Google Gemini. Each provider key is shared by both tasks and is saved after its provider accepts an authenticated model-list request. The next screen shows **Speech to text** and optional **Summary** task cards. Open a card's model row and choose a connected provider if needed. Tap a model or focus it and press Enter or Space to save it and close the picker. Moving focus and dismissing the picker preserve the saved model. Use **Refresh models**, pull to refresh, F5, or the TalkBack refresh action to reload the list. Continue after choosing available models and configuring appearance. The recording screen requests microphone access when you choose to record. File import and share remain available with microphone access denied. Later, **Settings > Model selection** offers the same cards without the wizard. Open its **Providers & API keys** entry to manage credentials. **Settings > General** combines language and region, appearance, and privacy. The overview footer shows the installed app version and build number.

To enable keyboard dictation, open **Settings > Transcriber keyboard** and select **Start setup**. The setup screen shows the live provider and guides you through **Enable in Android** and **Select the keyboard**. Android owns the keyboard switcher shown by Samsung Keyboard and Gboard. Once selected, use the microphone permission control in keyboard setup to enable dictation. Return through **Manage keyboard** to review that permission later.

When another app sends audio to Transcriber, check the audio and transcript recipients on the confirmation sheet before starting. If you change processing settings after an error, check the updated recipients and confirm again. Save the finished note when you want to keep it, or dismiss the sheet to discard the result.

## Validation

Run the static and build checks in [code quality](code-quality.md). Run the affected critical tests and exercise each changed app flow on a supported Android device or emulator with `flutter run`. For a complete Dart run after locked dependency resolution:

```bash
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --fatal-infos
dart run tool/ci/run_test_plan.dart
flutter build bundle --debug
```

Use synthetic notes and audio on an isolated test installation. Exercise the relevant phone or tablet layouts, touch or keyboard input, TalkBack, reduced motion, and error recovery for the changed flow. Measure performance when the change can affect it. Record the observed results and any gaps.

For CI automation changes, run the applicable [CI helper regressions](code-quality.md#ci-helper-regressions) and validate workflows with the pinned actionlint and ShellCheck tools from `.github/workflows/ci.yml`. Required PR checks run before squash merge. See [CI test selection](ci-test-selection.md) for local selection commands, full fallback, and the documentation-only path.

Run Android quality checks separately:

```bash
bash tool/quality/check_kotlin_quality.sh
JAVA_HOME=/path/to/jdk17 android/gradlew -p android \
  :app:verifyAuditedAndroidDependencies :app:testDebugUnitTest \
  :app:compileDebugAndroidTestKotlin
```

For only the manifest-listed pure Kotlin tests, Flutter and an Android SDK are unnecessary:

```bash
JAVA_HOME=/path/to/jdk17 android/gradlew -p tool/ci/jvm test --no-daemon
```

Run instrumented Android tests on an isolated device or emulator with API 29 or later and `arm64-v8a` support. Deny the test installation microphone access and leave another system keyboard selected before starting. The keyboard fixture temporarily selects Transcriber, exercises composing, committing and discarding synthetic text in an external editor, and restores the previous keyboard. It also checks the microphone-denied and protected-editor states. It needs no API keys or provider access.

```bash
JAVA_HOME=/path/to/jdk17 android/gradlew -p android \
  :app:connectedDebugAndroidTest
```

The [CI device runner](../tool/ci/run_android_device_tests.sh) creates a disposable, offline API 35 emulator and runs instrumentation. It then runs the separate picker recovery fixture against the debug APK. That fixture clears its test package data before and after the scenario and requires the designated disposable emulator. For an attached test device, follow the [manual picker recovery procedure](#interrupted-android-audio-selection) separately from the Gradle instrumentation command.

## Android Gradle Migration

The current build uses built-in Kotlin and pins `android.newDsl=false` to match Flutter's compatibility migration. Jetifier is disabled. See [Android Gradle compatibility](configuration.md#android-gradle-compatibility). Before an AGP 10 upgrade:

1. Inspect the exact stable Flutter Gradle plugin and every resolved native plugin for legacy DSL/variant APIs and incompatible Kotlin plugin application. Preserve the current SDK, NDK, Android API, ABI, and signing requirements unless a separate supported change is approved.
2. Resolve any incompatible consumers through supported upstream releases or interfaces. Once the pinned Flutter release and resolved plugins support the public DSL together, verify an ordinary Flutter build with the public DSL before removing the compatibility flag. Leave shared SDK files and compiler warning settings intact.
3. Clean the affected application build output. If the dependency graph changes, regenerate the Gradle locks and verify the locked native test command.
4. Build both debug and release APKs with the pinned Flutter SDK. Verify both resolved runtime dependency graphs use AndroidX and both builds succeed with Jetifier disabled.
5. Verify recording, file import/recovery, and share/open-file flows on a supported Android device or emulator. Hosted JVM tests and instrumented-test compilation do not establish actual OS or Flutter-engine behavior.

Use the existing local native validation commands above. Adopt AGP 10 after the stable release and compatible versions of Flutter and its native plugins are available.

## Keyboard Dictation Verification

Use non-production speech without personal information. Verify the complete matrix on at least one current Samsung device and one current Pixel device:

- enable, select, and switch back from the Transcriber input method through Android;
- render and operate the 312 dp Flutter keyboard with touch and TalkBack, confirming it never enters fullscreen extract mode;
- use Samsung Keyboard and Gboard as the previous keyboard;
- dictate in WhatsApp, a browser text field, and a multiline editor;
- verify partial and finalized segments remain one composing transcript without duplication until stop commits it once;
- discard after multiple finalized segments and confirm the editor clears the confirmed composing region while pre-existing text remains. Check editors that delay or omit composition updates for unexplained changes to surrounding text;
- tap backspace to delete one code point, delete a selected range, and hold it to verify accelerated repeat deletion stops immediately on release;
- pause and resume dictation within one minute, confirming the timer and waveform freeze, no paused audio is sent, and the existing live session continues;
- let a session reach its time limit or remain paused for one minute, and verify that capture stops and available text is committed to the same editor;
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

To verify the SharedPreferences import, start with [Transcriber v1.3.3](https://github.com/boommasterxd/transcriber/releases/tag/v1.3.3) on an isolated Android test installation. Create synthetic settings and notes with points, to-dos, and transcript segments, then upgrade in place to the Drift-backed version under test. Use the same package ID and compatible signing certificates for both builds so Android preserves the app data. Verify:

- all valid legacy records appear once;
- provider selections map to OpenAI or Google;
- historical provider/model labels remain unchanged on notes;
- corrupt legacy values remain available for recovery;
- valid legacy SharedPreferences values are removed only after database commit;
- OpenAI and Google keys remain accessible from secure storage;
- obsolete Hugging Face, Anthropic, and OpenRouter keys are removed.

For subsequent schema upgrades, verify preserved note content after an in-place update. Host SQLite regressions cover failed upgrades, rollback of schema changes and the version marker, reopening the database, and recovery of partially applied older title-search upgrades. They also check foreign-key rejection and cascading deletion. These checks do not replace Android storage and process-lifecycle verification.

On an Android test installation, delete a note with retained audio and terminate the process during the undo window. Reopen the normal app and verify that the queued file is removed. Also verify that successful undo preserves the note and audio and that opening the share activity during undo does not trigger recovery. Startup processes at most 128 candidates; failed attempts move behind other queued files for later starts.

## Provider Smoke Tests

Use non-production audio without personal information. Test all selected combinations:

1. OpenAI transcription and OpenAI summary
2. OpenAI transcription and Gemini summary
3. Gemini transcription and OpenAI summary
4. Gemini transcription and Gemini summary

Also test summary disabled, key replacement failure, provider throttling, network timeout, malformed provider responses, cancellation, and retry.

Force a summary failure after successful transcription and verify that the regular screen saves a transcript-only note with a visible warning and expandable transcript. In the share popup, verify both explicit save and discard. Reopen a saved note and confirm that the warning and sanitized diagnostic remain, summary sections are hidden, and the full transcript is readable. Check phone and tablet layouts, keyboard operation, and TalkBack. With long transcript text and task lists, verify scrolling and full-text copy. For retained audio, verify play, pause and seeking with touch, keyboard and TalkBack. Transcription failures must still show the processing error screen without creating a note.

## Troubleshooting

- Key validation fails: verify the key, project, API billing, quota, and network connection.
- A model is absent from the live list: the provider must return it for the connected key and its name, description, and available API methods must pass purpose filtering. New versions do not require an app update. Confirm provider access and choose an available replacement for an unavailable saved model. Provider metadata cannot prove endpoint compatibility; unusually named specialists may require a filtering-rule correction.
- Import is rejected: verify the supported extension and the [size and duration limits](configuration.md#audio-formats-and-limits) for the selected model.
- A shared file is rejected: confirm the source provides a supported filename and a readable audio stream.
- Processing times out: retry on a stable network and inspect provider status without logging credentials or transcript content.
- Processing is interrupted after leaving the app: keep Transcriber visible and retry. Cloud requests intentionally do not run in an Android foreground service.
- Keyboard recording does not start: confirm microphone permission, a valid key for the selected transcription provider, and a normal non-sensitive text field.
- The keyboard does not appear in the picker: use the Transcriber settings card to open Android's input-method settings and enable it first.
- Live setup is rejected: follow the keyboard's specific authentication, quota, model-access, configuration, or timeout message. Gemini language hints must use supported BCP-47 values such as `de-DE` and `en-US`; OpenAI live transcription may require billing or model access beyond basic key validation.
- Live setup cannot connect on a proxy-only network: the keyboard uses a direct TLS connection to its provider. Try a network that permits that connection.
- Live text stops updating: stop the session and retry on a stable network. Switching fields or hiding the keyboard intentionally terminates the current session.
- Startup or migration fails: retry from the startup error screen. Preserve the original data if the error persists. The share startup screen also offers a way to close the overlay.

## Release

### Signing prerequisites

The [Release workflow](../.github/workflows/release.yml) builds an unsigned APK, signs it in `release-signing`, and publishes it in `release`. Configure both GitHub environments to accept only the `main` branch. Keep repository write access exclusive to the owner so GitHub restricts manual workflow dispatch and direct release creation to that account. With this access policy, configure both environments without required reviewers so signing and publication proceed automatically. Store the established Android signing key only in the `release-signing` environment using these secrets.

| Secret | Value |
|---|---|
| `RELEASE_KEYSTORE_BASE64` | Base64-encoded release keystore. |
| `RELEASE_KEYSTORE_PASSWORD` | Keystore password. |
| `RELEASE_KEY_PASSWORD` | Password for the signing key. |
| `RELEASE_KEY_ALIAS` | Alias of the signing key in the keystore. |

Keep secret values out of source, logs, screenshots, and issue reports. The signing job writes the keystore to a restricted temporary directory, aligns and signs the APK, and removes its temporary files. It checks the `com.transcriber.app` package ID and the exact established certificate's SHA-256 fingerprint. Use the established signing key so the public APK can update existing installations. After completing the protected environment migration, retire the former repository-wide `ANDROID_*` signing secrets.

Android Developer Verification uses the packaged `assets/adi-registration.properties` file as part of the proof of signing-key ownership. When the public package name or signing certificate changes, [check registration for the new package and certificate](https://developer.android.com/developer-verification/guides/check-registration-status) before distribution.

### Version and source selection

Release starts only through manual dispatch from `boommasterxd` on protected `main`. The workflow checks the original account ID and the account requesting any rerun. Open **Actions > Release > Run workflow**, select `main`, and enter a stable `version` such as `1.2.3` or `v1.2.3`. A successful run publishes a regular GitHub release even when the version has a prerelease suffix. Use the [preview APK workflow](#preview-apk) for testing before a public release. The Android version code adds 1,000 to the Release workflow run number, with Android's 2.1-billion limit enforced. This puts public releases above earlier test builds that shared the public package ID. See the [source guard](../tool/package/verify_release_source.sh) and [version code calculator](../tool/package/android_release_version_code.sh).

Publication jobs are serialized by the normalized version without interrupting an active publisher. The job targets the exact checked-out build commit. Existing lightweight or annotated remote tags must resolve to that commit, and a failed remote query prevents publication. The job compares the built workflow files with current `main` because GitHub requires a permission unavailable to the workflow token when they differ. If they differ, recover by starting a new release from current `main` with the same unpublished version. See the [version resolver](../tool/package/version.sh), [release-tag and workflow guard](../tool/package/verify_release_tag.sh), and [GitHub release API](https://docs.github.com/en/rest/releases/releases#create-a-release).

### Artifacts and verification

The unsigned APK passes to the signing job in the `android-unsigned` Actions artifact. The signing job produces exactly `transcriber-<version>-android.apk` and its `SHA256SUMS` in `android-signed`. The publication job verifies the file set and checksum. The GitHub CLI then creates a draft with generated release notes, uploads both files, and publishes GitHub Release `v<version>`. This order also supports [immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases). An already published version is rejected. The workflow attempts to delete the intermediate Actions artifacts after publication. Any remaining artifacts expire after three days.

Download the APK and `SHA256SUMS` from the same release into one directory. From that directory, verify the download before installing:

```bash
sha256sum --check SHA256SUMS
```

The checksum verifies the downloaded file. The protected signing job verifies the APK's package and certificate. Before release acceptance, install or upgrade on an arm64 Android device and complete the device checks above.

Run the isolated package and signing regressions with Node.js 26.x, JDK 17 `keytool`, Android platform 36 and Android build tools 36.0.0. These checks use a synthetic signing key.

```bash
ANDROID_BUILD_TOOLS="$ANDROID_HOME/build-tools/36.0.0" \
  node --test test/tool/ci/release-package.test.cjs test/tool/ci/apk-signing.integration.cjs
```

### Preview APK

The manual [Build APK workflow](../.github/workflows/build-apk.yml) builds an AOT release-mode preview with `TRANSCRIBER_TEST_APK=true`. Like Release, it checks the original `boommasterxd` account ID and the account requesting any rerun. Download `transcriber-preview-android.apk` from the three-day `transcriber-preview-android` Actions artifact. It installs alongside the public app as `Transcriber Test` with the separate package ID `com.transcriber.app.preview` and its own local data. It is signed with the runner's debug key. The workflow checks the package ID and validates the APK signature. If another run uses a different debug key, reinstall the preview to test that build. The public package uses the protected Release workflow.

The Android package remains arm64-only. Preserve release signing, checksum verification, and minimal Android permissions. The main activity is exported for the launcher. The exported share activity imports one URI from audio `VIEW`, `SEND`, and `SEND_MULTIPLE` intents into bounded, sanitized app-private storage. `SEND_MULTIPLE` uses the first URI, so share each file separately to process every file. Explicit media intents to the main activity are forwarded to the share activity. The exported input-method service requires `android.permission.BIND_INPUT_METHOD`.
