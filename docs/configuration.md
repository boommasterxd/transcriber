# Configuration

## Toolchain

The supported versions are defined by `.fvmrc`, `pubspec.yaml`, `pubspec.lock`, and the Android Gradle configuration. Use the locked dependency graph and do not edit `pubspec.lock` manually.

## Provider Defaults

Transcription and summarization are independent settings.

| Stage | OpenAI default | Google Gemini default |
|---|---|---|
| Transcription | `gpt-transcribe` | `gemini-3.5-transcribe` |
| Summary | `gpt-5.6-luna` | `gemini-3.7-flash` |

The provider model catalog is loaded after a stored key has been verified. The configured default remains selectable if a provider does not expose it in the catalog response. Transcription selection includes dedicated transcription models and compatible multimodal models that accept audio and return text.

OpenAI's model catalog exposes identifiers but no modality metadata. The application therefore recognizes the officially documented transcription and audio model families returned for the user's key. Dedicated transcription models use the Audio Transcriptions API. General audio models use Chat Completions with inline WAV or MP3 audio, which is limited to 20 MiB to bound Base64 memory overhead.

Gemini's catalog is loaded across all pages. Dedicated Transcribe models use transcription configuration through the Files and Interactions APIs. General Gemini models that support `generateContent` use the same uploaded audio plus a text transcription instruction. Image, TTS, embedding, live, and other incompatible specialized families are excluded from the transcription selector.

## Personal API Keys

OpenAI and Gemini keys are independent. The application supports adding, validating, replacing, retesting, and removing each key. Validation occurs before a replacement is persisted, so a failed replacement does not destroy a working key.

Keys use `FlutterSecureStorage` names `api_key_openai` and `api_key_google`. They must never be placed in source files, environment files committed to Git, Drift, SharedPreferences, screenshots, logs, tests, or issue reports.

See [provider key setup](provider-setup.md) for provider-specific instructions.

## Provider Brand Assets

Provider marks are bundled locally and are never loaded from a remote host at runtime. The OpenAI mark comes from the verified [OpenAI GitHub organization](https://github.com/openai) and follows the [OpenAI brand guidelines](https://openai.com/brand/). The Gemini app mark comes from the official [Google Gemini Play listing](https://play.google.com/store/apps/details?id=com.google.android.apps.bard) and is used in line with the [Google Brand Resource Center](https://about.google/brand-resource-center/). Keep proportions, clear space, and colors unchanged when updating these assets.

## Persistence

Drift with SQLite is the active persistence layer. SharedPreferences is retained only to import the legacy `app_settings` and `notes` payloads once. The `shared_preferences_v1` migration marker prevents repeated imports.

The database file contains transcript content and may contain personal information. API keys are explicitly excluded.

## Audio Formats and Limits

In-app recording uses mono 16 kHz WAV. Imported and shared files accept FLAC, MP3, MP4, MPEG, MPGA, M4A, OGG/Opus, WAV, and WebM. WhatsApp Opus files keep their original bytes and extension. Gemini receives `audio/opus`; OpenAI's transcription endpoint receives the same bytes with the supported OGG filename and MIME metadata. No FFmpeg conversion is performed.

Application boundaries reject empty files and files larger than 250 MiB. Provider clients apply their own stricter request limits before network access where required.

Temporary audio has a 24-hour TTL and a 512 MiB quota. These values are centralized in `AudioCacheManager`.
