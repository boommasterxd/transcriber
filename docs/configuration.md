# Configuration

## Toolchain

| Concern | Source of truth | Current value |
|---|---|---|
| Flutter SDK | `.fvmrc` | 3.47.1 |
| Dart SDK constraint | `pubspec.yaml` | `>=3.12.0 <4.0.0` |
| Flutter lower bound | `pubspec.yaml` | `>=3.44.0` |
| Java and Kotlin target | `android/app/build.gradle.kts` | JVM 17 |
| Android compile SDK | `android/app/build.gradle.kts` | 37 |
| Android target SDK | `android/app/build.gradle.kts` | 36 |
| Android minimum SDK | `android/app/build.gradle.kts` | 26 |
| Android NDK | `android/app/build.gradle.kts` | 28.2.13676358 |
| Packaged ABI | `android/app/build.gradle.kts` | `arm64-v8a` |
| Gradle wrapper | `android/gradle/wrapper/gradle-wrapper.properties` | 9.7.1 |

Use the Flutter version pinned in `.fvmrc` for reproducible local and CI behavior. `pubspec.lock` is committed and CI resolves it with `--enforce-lockfile`.

Flutter 3.47.1 warns that `ffmpeg_kit_flutter_new` still applies the legacy Kotlin Gradle Plugin. The current Android build succeeds, but a future Flutter upgrade may require an upstream plugin release with Built-in Kotlin support. Verify that compatibility before changing the pinned Flutter SDK.

## Application Defaults

`AppSettings.initial()` currently selects:

- system theme and the default accent;
- German application language;
- automatic transcription language;
- local transcription and local summarization;
- Whisper Base for transcription;
- Qwen3 0.6B for local summarization;
- automatic local summarization backend;
- four Whisper CPU threads;
- OpenAI as the default cloud ASR provider;
- Anthropic as the default cloud summarization provider;
- summary generation enabled;
- source-audio retention enabled;
- onboarding incomplete.

Defaults and migrations belong in `lib/data/models/app_settings.dart`. Supported model and provider choices belong in `lib/data/catalog/`.

## Local Models

The Whisper catalog contains Tiny, Base, Small, and Medium models. Whisper weights are downloaded to application-support storage and download state is determined from expected file presence.

The local summarization catalog currently contains Qwen 2.5, Qwen3, DeepSeek R1, Gemma4, and Phi-4 variants. `GemmaEngine` selects LiteRT-LM or MediaPipe from the configured model artifact type and stores installation markers in application-support storage.

Model downloads may consume several gigabytes and require a physical arm64 Android device for representative execution.

## Cloud Providers

The provider catalog supports Anthropic, OpenAI, Google, and OpenRouter. Transcription support is capability-based: OpenAI and Google provide native ASR in the current implementation; Anthropic and OpenRouter do not.

Cloud requests use bounded timeouts from `lib/services/remote/remote_http.dart`:

- 90 seconds for chat requests;
- 25 seconds for model-list requests;
- 180 seconds for transcription requests.

Provider endpoint URLs and model identifiers are code configuration. Change them only with provider documentation and focused integration verification.

## Persistent Settings and Secrets

`SharedPreferences` stores non-secret application settings and notes. `FlutterSecureStorage` stores:

- provider API keys keyed by provider identifier;
- the Hugging Face token.

Do not add secret values to Dart source, Android resources, `.env` files, tests, documentation, workflow logs, or GitHub Actions expressions. Android release signing reads `android/key.properties`, which CI creates from repository secrets. Local signing files, keystores, and `.env` remain ignored.

Foreground processing serializes the credentials required by the isolated job through `flutter_foreground_task`. Treat this as a sensitive transient data boundary and re-evaluate plugin retention behavior when upgrading the plugin.

## Android Permissions and Components

The main manifest requests Internet, microphone, media-audio, notifications, foreground service, data-sync foreground service, and wake-lock access. The share activity is exported to receive external audio. Any new permission or exported component requires a concrete feature need, least-privilege review, user-facing behavior review, and an update to `docs/security.md`.

## CI Configuration

Quality thresholds are defined in `AGENTS.md`, `analysis_options.yaml`, `config/detekt.yml`, and the focused scripts under `tool/quality/`. Workflow tool versions and third-party actions are pinned. Do not add a quality baseline or suppress current violations. See `docs/code-quality.md` for commands and metric semantics.
