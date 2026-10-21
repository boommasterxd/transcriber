# Configuration

## Toolchain

The supported versions are defined by `.fvmrc`, `pubspec.yaml`, `pubspec.lock`, and the Android Gradle configuration. Use the locked dependency graph and do not edit `pubspec.lock` manually.

The CI duplication check uses the latest Node.js 24.x release with `node-version: "24.x"` and `check-latest: true`. Node.js is tooling only; the application toolchain remains Flutter, Dart, and Android Gradle.

## Provider Defaults

Transcription and summarization are independent settings.

New installations default to Google Gemini for both stages. Existing provider and model choices are preserved.

| Stage | OpenAI default | Google Gemini default |
|---|---|---|
| Transcription | `gpt-transcribe` | `gemini-3.5-transcribe` |
| Summary | `gpt-5.6-luna` | `gemini-3.7-flash` |

Live keyboard dictation has a separate, fixed compatibility mapping:

| Provider | Live model | PCM input |
|---|---|---|
| OpenAI | `gpt-live-transcribe` | mono PCM16, 24 kHz |
| Google Gemini | `gemini-3.5-transcribe-live` | mono PCM16, 16 kHz |

The keyboard inherits the selected transcription provider, language, and that provider's existing API key. It does not reuse the batch model selector because batch and live endpoints have different compatibility requirements. OpenAI receives the application's `de` or `en` hint, while Gemini receives the required BCP-47 `de-DE` or `en-US` hint; automatic detection omits the hint. The settings card displays the effective live model explicitly.

The provider model catalog is loaded after a stored key has been verified. A shared raw listing per provider and connection revision supplies both task filters; one cold OpenAI request or Gemini page traversal serves transcription and summary together. Rebuilds reuse it. Explicit refresh/retry invalidates both views, and credential replacement, disconnect, or reconnect invalidates the affected provider without exposing credentials in cache identities. Only compatible returned models are selectable; configured defaults are not added. A saved model absent from the filtered catalog is shown as unavailable. Transcription includes dedicated transcription models and compatible multimodal models that accept audio and return text.

The [OpenAI model-list API](https://developers.openai.com/api/reference/resources/models/methods/list) exposes identifiers but no task, modality, or endpoint capabilities. Purpose filtering therefore uses token-based naming rules rather than fixed model versions. Dedicated transcription models use the Audio Transcriptions API. General audio models use Chat Completions with inline WAV or MP3 audio, which is limited to 20 MiB to bound Base64 memory overhead. Summary selection excludes audio, image, live, embedding, moderation, and other specialized or incompatible roles.

The [Gemini model-list API](https://ai.google.dev/api/models?hl=en) supplies names, descriptions, and supported generation methods, but no complete modality or purpose classification. Its catalog is loaded across all pages. Dedicated Transcribe models use `smart` transcription mode through the Files and Interactions APIs. This produces readable text without requesting timestamps or speaker diarization. General models must advertise `generateContent`; their identifiers, display names, and descriptions are checked for specialist roles. Image generation, TTS, embeddings, live audio, robotics, and other recognized incompatible roles are excluded from both selectors. Native transcription models are excluded from summary selection, and text-only models are excluded from transcription selection.

Gemini also excludes managed-agent and harness roles, Deep Research, and computer/browser-use specialists from both tasks. [Antigravity](https://ai.google.dev/gemini-api/docs/antigravity-agent) and [Deep Research](https://ai.google.dev/gemini-api/docs/deep-research) use agent workflows, while [Computer Use](https://ai.google.dev/gemini-api/docs/computer-use) requires an execution loop that the application does not implement. Role checks use identifiers, display names, and explicit purpose descriptions; general models mentioning research or agentic capabilities remain eligible. Recognizable saved specialist IDs are rejected before any provider request.

The purpose heuristics live in `ProviderModelCapabilities`. There are no positive lists of model versions: new versions returned by the API are considered automatically. Names and descriptions are hints, not capability guarantees. An unusually named new specialist may be misclassified, and filtering does not prove endpoint compatibility, quota, billing, or successful inference access. No inference probes or external capability catalogs run during model selection. Clients reject unsafe identifiers and recognizable incompatible saved model roles before provider requests. OpenAI diarization transcription requests include `chunking_strategy=auto` to support audio longer than 30 seconds without requesting speaker metadata.

When updating these rules, check the official [Gemini model catalog](https://ai.google.dev/gemini-api/docs/models), [Gemini audio guide](https://ai.google.dev/gemini-api/docs/audio), [OpenAI endpoint support](https://developers.openai.com/api/docs/guides/your-data), [OpenAI audio chat guide](https://developers.openai.com/api/docs/guides/audio-chat-completions), and [OpenAI transcription reference](https://developers.openai.com/api/reference/resources/audio/subresources/transcriptions/methods/create). Match the application's request format as well as the model's input and output modalities.

Fine-tuned OpenAI summary models use the documented `ft:<base-model>:<organization>:<suffix>:<identifier>` form, including an empty optional suffix. The full ID is validated and passed unchanged to Chat Completions; purpose filtering examines only the base model, so user-assigned names do not accidentally trigger specialist exclusions. See the [supervised fine-tuning guide](https://developers.openai.com/api/docs/guides/supervised-fine-tuning#try-using-your-fine-tuned-model).

## Personal API Keys

OpenAI and Gemini keys are independent. Open **Settings > Model selection > Providers & API keys**, then expand a provider row to add, validate, replace, retest, or remove its key. Each provider has one credential editor shared by transcription, summary, and keyboard dictation. Validation occurs before a replacement is persisted, so a failed replacement does not destroy a working key.

Keys use `FlutterSecureStorage` names `api_key_openai` and `api_key_google`. They must never be placed in source files, environment files committed to Git, Drift, SharedPreferences, screenshots, logs, tests, or issue reports.

Live WebSocket authentication also uses request headers. Long-lived keys are not included in WebSocket URLs. The live client keeps the selected key only for the active session and releases its configuration when the session closes.

See [provider key setup](provider-setup.md) for provider-specific instructions.

## Provider Brand Assets

Provider marks are bundled locally and are never loaded from a remote host at runtime. The OpenAI mark comes from the verified [OpenAI GitHub organization](https://github.com/openai) and follows the [OpenAI brand guidelines](https://openai.com/brand/). The Gemini app mark comes from the official [Google Gemini Play listing](https://play.google.com/store/apps/details?id=com.google.android.apps.bard) and is used in line with the [Google Brand Resource Center](https://about.google/brand-resource-center/). Keep proportions, clear space, and colors unchanged when updating these assets.

## Persistence

Drift with SQLite is the active persistence layer. SharedPreferences is retained only to import the legacy `app_settings` and `notes` payloads once. The `shared_preferences_v1` migration marker prevents repeated imports.

The database file contains transcript content and may contain personal information. API keys are explicitly excluded.

Transcript segments preserve text and ordering only. Provider timestamps are neither requested nor persisted, and legacy timestamp values are discarded during database migration without changing the transcript text.

## Audio Formats and Limits

In-app recording uses mono 16 kHz PCM16 WAV. Native capture checks the selected batch model's configured upload budget before each write, independent of Flutter timers. It reserves the 44-byte WAV header and stops on complete-second boundaries: at most 3,276 seconds for the 100 MiB client cap, or 655 seconds for OpenAI's 20 MiB inline-audio cap. The UI shows the limit and retains the finished file for explicit processing or discard. Paused time adds no audio. These are application-side bounds, not guarantees of provider access or acceptance.

Imported and shared files accept FLAC, MP3, MP4, MPEG, MPGA, M4A, OGG/Opus, WAV, and WebM. WhatsApp Opus files keep their original bytes and extension. Gemini receives `audio/opus`; OpenAI's transcription endpoint receives the same bytes with the supported OGG filename and MIME metadata. No FFmpeg conversion is performed.

The application applies separate import and transcription limits. One MiB is 1,048,576 bytes; empty audio files are rejected.

| Boundary | Maximum audio file size | Applies to |
|---|---:|---|
| Import and Android share/open-file input | 250 MiB (262,144,000 bytes) | The app-owned working copy, before provider-specific validation. |
| Batch transcription | 100 MiB (104,857,600 bytes) | Gemini Files uploads and OpenAI Audio Transcriptions requests. |
| OpenAI inline audio | 20 MiB (20,971,520 bytes) | Chat Completions audio input; the smaller cap bounds Base64 memory overhead. |

A file can pass import validation and still exceed the selected transcription endpoint's limit. These are application-side caps, not provider guarantees; the provider may reject a smaller file because of its own limits, format support, model access, or quota. Upload caps are shared by [recording and provider validation](../lib/services/remote/remote_audio_limits.dart); import validation belongs to [AudioCacheManager](../lib/services/storage/audio_cache_manager.dart).

Temporary audio has a 24-hour TTL and a 512 MiB quota. These values are centralized in `AudioCacheManager`.

Keyboard dictation does not create an audio file. Native capture is streamed in memory, its reconnect queue is bounded, and all queued chunks are discarded when recording stops or the editor session becomes invalid.
