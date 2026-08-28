# Architecture

## Scope

Transcriber is a Flutter Android application with two Flutter entry points. It accepts recorded, selected, opened, or shared audio and produces a `TranscriptNote`. Transcription is required and summarization is optional. Each stage independently selects OpenAI or Google Gemini.

There is no local inference, model download, FFmpeg conversion, or foreground processing isolate.

## Dependency Direction

The dependency direction is:

```text
UI -> Riverpod state -> services and repositories -> models and integrations
```

- `lib/core/` owns localization, theme, and presentation utilities.
- `lib/data/models/` owns framework-independent application values.
- `lib/data/catalog/` owns the two providers and their defaults.
- `lib/data/database/` owns Drift tables, migrations, and the generated schema adapter.
- `lib/data/repositories/` owns typed settings and note persistence.
- `lib/services/` owns audio, provider REST, processing, share, and storage boundaries.
- `lib/state/` owns Riverpod dependency wiring and application state.
- `lib/ui/` renders state and delegates work.
- `android/` owns Android entry points and bounded share-file copying.

## Entry Points and Bootstrap

`lib/main.dart` renders the normal application. `shareMain` delegates to `lib/share_entrypoint.dart` for the translucent Android share target. Both call `loadAppBootstrap`, which:

1. opens the Drift database;
2. atomically imports legacy SharedPreferences data once;
3. loads settings, provider connection state, and notes;
4. removes stale app-owned temporary audio;
5. injects initialized dependencies into Riverpod.

SharedPreferences remains a read-only legacy source until the migration window is intentionally removed. It is not the active persistence layer.

## Provider Boundaries

Provider behavior is split into small contracts:

- `TranscriptionProviderClient` uploads audio and returns a transcription.
- `SummaryProviderClient` turns transcript text into a structured summary response.
- `ModelCatalogClient` lists selectable models.
- `RemoteProviderClient` composes the three contracts for the factory.

`OpenAiClient` and `GoogleClient` implement direct REST requests with the existing `http` stack. Provider model catalogs are loaded dynamically and filtered by `ProviderModelCapabilities` because neither catalog exposes complete audio-input and text-output modality metadata. Dedicated transcription models use provider-native transcription payloads, while compatible multimodal models receive audio plus a plain-text transcription instruction. Provider-specific payloads and errors remain behind those clients. API keys are transmitted in headers and are never placed in URLs, database rows, logs, or user-visible error details.

## Processing Flow

```text
record, import, or share
  -> app-owned temporary audio or validated external reference
  -> selected transcription provider and model
  -> optional selected summary provider and model
  -> retained app-owned audio or immediate working-copy deletion
  -> Drift note transaction
```

`ProcessingPipeline` receives an immutable settings snapshot and separate credentials for both stages. This supports all four OpenAI/Gemini combinations without coupling the stages. New notes record both provider and model origins. Legacy local-origin fields remain readable so historical notes retain accurate provenance.

## Persistence

Drift tables store singleton settings, notes, ordered key points, ordered to-dos, transcript segments, and migration markers. Repository writes are transactional. API keys remain exclusively in `FlutterSecureStorage`.

The one-time legacy migration parses old settings and notes before entering a database transaction. The marker, settings, notes, points, to-dos, and transcript segments commit atomically. Successfully imported SharedPreferences values are removed only after the commit.

## Audio Ownership

`ManagedAudioFile` carries explicit `external`, `temporary`, or `retained` ownership. Destructive operations validate that a path belongs to the corresponding app directory. External originals are never deleted. See [cache lifecycle](cache-lifecycle.md).
