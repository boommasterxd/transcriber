# Transcriber

A modern Flutter Android app that **transcribes and summarizes voice notes** — locally on device or
via Cloud API — with key points and actionable to-dos. Pill UI, rich animations, light/dark + 5
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

## Processing: On-Device vs. Cloud (one or the other, never mixed)

The master switch in Settings decides between:

### On Device (private, offline)
- **Transcription:** [`whisper_kit`](https://pub.dev/packages/whisper_kit) –
  Whisper Tiny / Base / Small / Medium.
- **Summarization:** [`flutter_gemma`](https://pub.dev/packages/flutter_gemma) –
  Gemma 3 270M/1B, Qwen 2.5 0.5B/1.5B, and the multimodal Gemma 3n E2B/E4B
  (audio-capable). Models are loaded as LiteRT artifacts from Hugging Face
  (gated models require an HF token, configurable in Settings).

The actual model lists come from the library docs and live in `lib/data/catalog/`.

### Cloud API
Real requests to **Anthropic**, **OpenAI**, **Google**, or **OpenRouter**.
- Summarization: respective chat endpoints.
- Transcription: OpenAI (`gpt-4o-transcribe`) or Google Gemini (inline audio).
  Anthropic/OpenRouter have no native ASR — the UI surfaces this clearly.

API keys are stored exclusively in `flutter_secure_storage` on device.

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

Each ML library is encapsulated behind exactly **one** engine file
(`WhisperEngine`, `GemmaEngine`) so version updates stay local.

## Build

Prerequisites: Flutter ≥ 3.44, Android SDK, a device with `arm64-v8a`.

```bash
flutter pub get
flutter run            # Debug on a connected device
flutter build apk      # Release APK
flutter test           # Unit tests
```

On first `flutter pub get` Flutter generates `android/local.properties`
(with the path to the Flutter SDK). The Gradle wrapper (9.7.1) is checked in.

> On-device inference downloads several GB of model weights and requires a real
> Android device — ML inference cannot run in CI/headless environments.
