# Architecture

## System Overview

Transcriber is a Flutter Android application with two Flutter entry points and one foreground-service isolate. It accepts recorded, selected, opened, or shared audio and produces a `TranscriptNote`. Transcription is required; summarization is optional. Each stage can use a local model or a cloud provider independently.

The primary dependency direction is:

```text
Flutter UI -> Riverpod controllers -> services and repositories -> models, storage, native plugins, and provider APIs
```

Domain models and catalogs do not depend on UI or controller code. Provider-specific behavior stays behind service interfaces and factories.

## Entry Points

- `lib/main.dart` initializes Flutter bindings, foreground-task communication, download notifications, shared preferences, secure settings, Gemma engines, and Riverpod overrides before rendering `TranscriberApp`.
- `shareMain` in `lib/main.dart` is the named AOT entry point for the translucent Android share activity.
- `android/app/src/main/kotlin/com/transcriber/app/MainActivity.kt` hosts the normal Flutter activity.
- `android/app/src/main/kotlin/com/transcriber/app/ShareActivity.kt` hosts the transparent share entry point and copies incoming content into application cache.
- `processingForegroundCallback` in `lib/services/processing/processing_foreground.dart` initializes the foreground-service isolate handler.

The Android manifest registers launcher, audio `VIEW`, `SEND`, and `SEND_MULTIPLE` intents and the foreground processing service.

## Layers

### Core

`lib/core/` provides localization strings, semantic theme tokens, app-wide presentation helpers, and formatting utilities. These are cross-cutting dependencies and must not own application workflows.

### Data

`lib/data/models/` contains settings, notes, transcription results, model specifications, provider identifiers, and processing modes. `lib/data/catalog/` is the source of truth for supported Whisper, local summarization, and remote-provider options. `lib/data/repositories/` persists settings and notes.

### Services

`lib/services/` owns external and platform boundaries:

- `audio/` records, converts, and probes audio.
- `models/` provides the runtime boundary used by state controllers to install, inspect, and remove local models.
- `processing/` validates configuration and orchestrates transcription, optional summarization, metadata assembly, and audio retention.
- `remote/` implements provider HTTP APIs behind `RemoteApiClient` and `RemoteClientFactory`.
- `transcription/` defines the transcription interface and local/cloud implementations.
- `summarization/` defines the summarization interface, prompt contract, and local/cloud implementations.
- `share/` handles warm and cold Android share intents.
- `storage/` owns application-support paths for models and retained recordings.

`WhisperEngine` owns direct `whisper_kit` operations. `GemmaEngine` owns model installation and inference through `flutter_gemma`; the main and foreground-isolate entry points additionally initialize the package engines before dependency wiring or processing. `LocalModelRuntime` keeps these plugin-specific engines behind an injectable boundary for model-state orchestration.

### State

`lib/state/` wires dependencies and exposes Riverpod controllers for settings, provider connections, notes, model state, processing, recording, and remote model lists. Controllers coordinate application behavior and expose immutable state to widgets.

### UI

`lib/ui/` contains navigation, screens, and shared widgets. Phone and tablet layouts consume the same controllers and persisted notes. The setup gate selects onboarding until required permissions and the persisted onboarding state are satisfied.

## Processing Flow

```text
record, file, open, or share
  -> preflight model and API-key checks
  -> duration probe
  -> foreground-service isolate when either stage is local
     or direct all-cloud processing
  -> audio normalization when local Whisper requires WAV
  -> transcription
  -> optional summarization
  -> TranscriptNote assembly
  -> optional source-audio deletion
  -> persisted history or explicit share-preview save
```

`ProcessingPipeline` resolves ASR and summarization independently from the immutable `ProcessingRequest`. The request groups the audio input, settings snapshot, and stage credentials and owns the foreground-isolate JSON handoff. Observer callbacks remain process-local and are never serialized. A local stage causes the complete pipeline to run inside the Android foreground-service isolate so model execution does not block the main UI isolate and can survive backgrounding. All-cloud processing invokes the core pipeline directly.

The share preview uses `save: false`. It persists the completed note only after the user selects Save.

## Persistence and External Boundaries

- `SettingsRepository` stores non-secret settings in `SharedPreferences` and API keys plus the Hugging Face token in `FlutterSecureStorage`.
- `NotesRepository` stores JSON-encoded transcript notes in `SharedPreferences`.
- `StoragePaths` creates application-support directories for Whisper models, local summarization models, and retained recordings.
- `ShareActivity` copies external content URIs into application cache before Flutter processing.
- Remote clients send requests to Anthropic, OpenAI, Google, or OpenRouter over HTTPS with bounded timeouts.
- Foreground-task job data carries the selected settings and credentials needed by the processing isolate. Its retention and encryption properties depend on the plugin and require explicit review when that integration changes.

## Invariants

- Transcription always runs; summarization may be disabled.
- ASR and summarization modes are independent and may be mixed.
- Local ASR requires a downloaded Whisper model.
- Local summarization requires a downloaded local summarization model.
- Local Whisper input is 16 kHz, mono, 16-bit PCM WAV.
- Auto-delete removes the source audio and stores no playable audio path.
- Native ASR is available only for providers whose catalog capability allows it.
- Summary parsing accepts the documented four-field JSON shape and degrades to plain text when model output is not valid JSON.
- Share previews are not persisted automatically.

## Service Dependency Direction

`TranscriptionResult` is a data model shared by local transcription and remote providers. Remote clients depend only on data models and external HTTP integrations. The cloud transcription adapter depends on `RemoteApiClient`, so the service dependency remains one-way from `transcription/` to `remote/`.
