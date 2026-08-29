# Architecture

## Scope

Transcriber is a Flutter Android application with three Flutter entry points. It accepts recorded, selected, opened, or shared audio and produces a `TranscriptNote`. It can also run as an Android input method that streams microphone audio and inserts live transcription into the active text editor. Batch transcription is required for notes and summarization is optional. Each stage independently selects OpenAI or Google Gemini.

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
- `lib/services/` owns audio, provider REST and WebSocket, processing, share, platform-channel, and storage boundaries.
- `lib/state/` owns Riverpod dependency wiring and application state.
- `lib/ui/` renders state and delegates work.
- `android/` owns Android entry points and bounded share-file copying.

## Entry Points and Bootstrap

`lib/main.dart` declares three entry points:

- `main` renders the normal application;
- `shareMain` delegates to `lib/share_entrypoint.dart` for the translucent Android share target;
- `keyboardMain` delegates to `lib/keyboard_entrypoint.dart` for the Android input method.

The main and share entry points call `loadAppBootstrap`, which:

1. opens the Drift database;
2. atomically imports legacy SharedPreferences data once;
3. loads settings, provider connection state, and notes;
4. removes stale app-owned temporary audio;
5. injects initialized dependencies into Riverpod.

SharedPreferences remains a read-only legacy source until the migration window is intentionally removed. It is not the active persistence layer.

The keyboard entry point deliberately loads only the database, settings repository, active settings, and secure credential boundary. It does not load notes or run cache cleanup. `TranscriberInputMethodService` owns a dedicated `FlutterEngine` and embeds the keyboard Flutter view in a measured 312 dp input container. Fullscreen extract mode is disabled so Android cannot expand the dictation surface over the application. Native Android code owns editor lifecycle, microphone capture, and `InputConnection`; Flutter owns the live-session controller and keyboard presentation.

Keyboard activation remains optional. The settings card opens a dedicated Flutter onboarding screen that explains the effective live provider and guides users through enabling the input method and selecting it in Android. It reads status from Android after every system action, application resume, and return from onboarding; it does not mark setup complete until Android reports Transcriber as selected. Once complete, settings offer keyboard management and onboarding renders a completed state instead of setup actions.

## Provider Boundaries

Provider behavior is split into small contracts:

- `TranscriptionProviderClient` uploads audio and returns a transcription.
- `SummaryProviderClient` turns transcript text into a structured summary response.
- `ModelCatalogClient` lists selectable models.
- `RemoteProviderClient` composes the three contracts for the factory.

`OpenAiClient` and `GoogleClient` implement direct REST requests with the existing `http` stack. Provider model catalogs are loaded dynamically and filtered by `ProviderModelCapabilities` because neither catalog exposes complete audio-input and text-output modality metadata. Dedicated transcription models use provider-native transcription payloads, while compatible multimodal models receive audio plus a plain-text transcription instruction. Provider-specific payloads and errors remain behind those clients. API keys are transmitted in headers and are never placed in URLs, database rows, logs, or user-visible error details.

Keyboard dictation uses the separate `LiveTranscriptionClient` contract. Its fixed compatibility catalog maps OpenAI `gpt-live-transcribe` to 24 kHz PCM and Gemini `gemini-3.5-transcribe-live` to 16 kHz PCM. Language hints are normalized per protocol, including `de-DE` and `en-US` for Gemini. Native `AudioRecord` emits mono PCM16 chunks through an event channel. The selected live client confirms provider setup before recording, streams those chunks over WebSocket, and emits partial and final text events. A single bounded deadline covers DNS, TLS, the WebSocket handshake, and provider setup. Cancellation invalidates late sockets, and socket shutdown is bounded so cleanup cannot leave the UI in a transient state. Sanitized connection failures distinguish authentication, quota, model access, rejected configuration, timeout, and transient disconnects without exposing provider responses or credentials.

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

## Keyboard Dictation Flow

```text
active supported editor
  -> session-scoped AudioRecord PCM chunks
  -> selected live provider over WebSocket
  -> partial and finalized segments remain replaceable via setComposingText
  -> pause releases microphone capture while retaining the live provider session
  -> resume restarts capture for the same editor and provider session
  -> stop commits the complete session transcript
  -> discard clears the complete composing transcript
  -> editor change, keyboard hide, or failure closes all session resources
```

`EditorFieldPolicy` rejects password, PIN, non-text, and no-personalized-learning editors before recording can start. `EditorSessionGate` assigns a new identifier on every editor transition and rejects late platform calls and provider events from stale sessions. No surrounding editor text is requested. Final provider segments remain part of one composing region until the user stops, so discard can clear the entire current dictation without touching text that existed before recording. Editor writes are serialized to prevent a late partial from reappearing after discard. Editor visibility transitions are also serialized so slow hidden-session cleanup cannot overwrite a newer visible editor state. The session-gated backward action deletes an active selection first, otherwise deletes one code point with a delete-key event fallback for incompatible editors. Holding the action repeats and accelerates until release. A bounded in-memory audio queue bridges short reconnects and is cleared when the session ends. Gemini uses its SMART input-transcription mode, while OpenAI partials remain replaceable until the complete session is committed. Recognized text is rendered only by the target editor, not duplicated inside the keyboard surface. The compact keyboard reuses the application's recording controls and animated waveform, with a reduced-motion path and dedicated connecting, recording, paused, reconnecting, and stopping states. Its cardless waveform region uses the same 42-bar history and perceptual dBFS amplitude mapping as the full-screen recorder. The active timer sits in the top bar, and the switch action carries the active provider logo. The initial connecting state shows only progress and cancellation, while provider messages accept both text and binary WebSocket frames.

## Persistence

Drift tables store singleton settings, notes, ordered key points, ordered to-dos, ordered transcript text segments, and migration markers. Timestamps are intentionally not part of the transcript domain or database schema. Repository writes are transactional. API keys remain exclusively in `FlutterSecureStorage`.

The one-time legacy migration parses old settings and notes before entering a database transaction. The marker, settings, notes, points, to-dos, and transcript segments commit atomically. Successfully imported SharedPreferences values are removed only after the commit.

The main application reloads the persisted note snapshot whenever its activity resumes. This synchronizes notes written by the dedicated share entry point while the main Flutter UI was paused.

## Audio Ownership

`ManagedAudioFile` carries explicit `external`, `temporary`, or `retained` ownership. Destructive operations validate that a path belongs to the corresponding app directory. External originals are never deleted. See [cache lifecycle](cache-lifecycle.md).
