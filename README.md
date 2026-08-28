# Transcriber

A modern Flutter Android app that **transcribes and summarizes voice notes**, locally on device or
via Cloud API, with key points and actionable to-dos. Pill UI, rich animations, light/dark + 5
accent colors, DE/EN.

The UI is a 1:1 implementation of the Claude design mock-up; all actions are fully functional
(real recording, real file import, real Android share intent, real on-device inference and real
Cloud API calls).

## Inputs

1. **Share** – audio from other apps (e.g. WhatsApp) arrives via Android share intent
   (`ACTION_SEND` / `audio/*`) → processing → detail screen.
2. **Pick a file** – audio file from the file system (`file_picker`).
3. **Record** – record directly in the app (`record`, WAV 16 kHz mono).

Every input runs through the same pipeline: *Transcription → Summarization →
Detail screen* with a "Processed with" section showing the models used.

## Processing: On-Device and Cloud

Transcription and summarization are configured independently. Each stage can
run on-device or through a supported cloud provider, so mixed configurations
such as local transcription with cloud summarization are supported.

### On Device (private, offline)
- **Transcription:** [`whisper_kit`](https://pub.dev/packages/whisper_kit) –
  Whisper Tiny / Base / Small / Medium.
- **Summarization:** [`flutter_gemma`](https://pub.dev/packages/flutter_gemma) –
  Qwen 2.5, Qwen3, DeepSeek R1, Gemma4, and Phi-4 variants from the catalog in
  `lib/data/catalog/gemma_catalog.dart`. Models are loaded as LiteRT artifacts
  from configured download sources. Optional Hugging Face token support is
  available in Settings.

The actual model lists come from the library docs and live in `lib/data/catalog/`.

### Cloud API
Real requests to **Anthropic**, **OpenAI**, **Google**, or **OpenRouter**.
- Summarization: respective chat endpoints.
- Transcription: OpenAI (`gpt-4o-transcribe`) or Google Gemini (inline audio).
  Anthropic/OpenRouter have no native ASR, and the UI surfaces this clearly.

Long-lived API keys are stored in `flutter_secure_storage` on device. Processing
hands the selected keys to the foreground worker when a local stage requires
isolated background execution.

## Architecture

```
lib/
  core/         Theme (palette/accent), localization (DE/EN), utils
  data/
    models/     Domain models (Settings, Note, Model specs …)
    catalog/    Real model catalogs (Whisper, Gemma, Cloud providers)
    repositories/  Persistence (Settings, Notes, Downloads)
  services/
    audio/      Recording, conversion (ffmpeg → WAV 16k), player, metadata
    transcription/  Interface + Whisper engine + cloud
    summarization/  Interface + Gemma engine + cloud + prompt
    remote/     Provider clients (Anthropic/OpenAI/Google/OpenRouter)
    processing/ Pipeline (orchestrates transcription → summarization)
    share/      Android share intent
  state/        Riverpod controllers (Settings, Notes, Processing, Recording, …)
  ui/
    screens/    Onboarding, Home, Record, Settings, Processing, Detail
    widgets/    Shared widgets (waveforms, pills, tiles, effects …)
```

Inference and model-install behavior is centralized in `WhisperEngine` and
`GemmaEngine`. Application entry points additionally bootstrap the
`flutter_gemma` engines required in the main and foreground isolates.

## Build

Prerequisites: Flutter 3.47.1 from `.fvmrc`, Android SDK, Java 17, and a device
with `arm64-v8a`.

```bash
flutter pub get --enforce-lockfile
flutter run            # Debug on a connected device
flutter build apk      # Release APK
flutter test           # Unit tests
```

On first `flutter pub get` Flutter generates `android/local.properties`
(with the path to the Flutter SDK). The Gradle wrapper (9.7.1) is checked in.

> On-device inference downloads several GB of model weights and requires a real
> Android device. ML inference cannot run in CI/headless environments.

## Documentation

- [Architecture](docs/architecture.md)
- [Configuration](docs/configuration.md)
- [Operations](docs/operations.md)
- [Code quality](docs/code-quality.md)
- [Security](docs/security.md)
