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

`lib/ui/navigation.dart` keeps the app-facing navigator facade. Record and processing screens call focused route functions in `processing_navigation.dart` and `navigation_routes.dart`, respectively, so route construction does not create reverse imports into the facade.

Settings use framework-independent `AppearanceSettings`, `TranscriptionSettings`, and `SummarySettings` values. Flutter theme modes and accent colors are mapped only in `lib/core/theme/`. `TranscriptNote` groups recording metadata, processing origins, and generated content while retaining its flat persisted JSON format.

## Entry Points and Bootstrap

`lib/main.dart` declares three entry points:

- `main` renders the normal application;
- `shareMain` delegates to `lib/share_entrypoint.dart` for the translucent Android share target;
- `keyboardMain` delegates to `lib/keyboard_entrypoint.dart` for the Android input method.

The main and share entry points call `loadAppBootstrap`, which:

1. opens the Drift database;
2. atomically imports legacy SharedPreferences data once;
3. loads settings and provider connection state without historical transcripts;
4. removes stale app-owned temporary audio;
5. injects initialized dependencies into Riverpod.

SharedPreferences remains a read-only legacy source until the migration window is intentionally removed. It is not the active persistence layer.

The native share activity imports shared and opened audio on a process-wide single-worker executor. Audio `VIEW` and share filters enter through that bounded path; explicit media intents addressed to the launcher activity are hidden from Flutter plugins and forwarded there. An early `getInitialSharedPath` call waits for completion instead of reading a premature null path. A 60-second deadline, activity destruction, or explicit finish cancels the import and releases pending channel calls. File descriptors, streams, cancellation signals, and incomplete files have explicit ownership until Dart receives the path. A separate bounded cleanup worker keeps provider cancellation off the main thread. Providers that ignore cancellation can occupy the single import slot, but cannot accumulate import threads.

The keyboard entry point deliberately loads only the database, settings repository, active settings, and secure credential boundary. It does not load notes or run cache cleanup. `TranscriberInputMethodService` owns a dedicated `FlutterEngine` and embeds the keyboard Flutter view in a measured 312 dp input container. Fullscreen extract mode is disabled so Android cannot expand the dictation surface over the application. Native Android code owns editor lifecycle, microphone capture, and `InputConnection`; Flutter owns the live-session controller and keyboard presentation.

Keyboard activation remains optional. The settings card opens a dedicated Flutter onboarding screen that explains the effective live provider and guides users through enabling the input method and selecting it in Android. It reads status from Android after every system action, application resume, and return from onboarding; it does not mark setup complete until Android reports Transcriber as selected. Once complete, settings offer keyboard management and onboarding renders a completed state instead of setup actions.

## Provider Boundaries

Settings use a navigation overview with keyboard, model selection, and general pages. General settings combine language and region, appearance, and privacy. The keyboard page explains dictation beneath its setup card. Model selection shows separate speech-to-text and summary task cards, with purpose, current API model, and provider together; the summary switch belongs to its card. Tapping a model opens a task-specific modal with connected providers and a live catalog. Choosing a model immediately persists its provider and identifier together and closes the modal; browsing providers or dismissing without a choice leaves both tasks unchanged. Pull-to-refresh reloads the catalog; F5 and a screen-reader action provide accessible alternatives. Loading, errors, missing credentials, and unavailable saved models cannot be selected. Its nested provider connections page manages each provider's credentials once, shared across processing stages and keyboard dictation. The overview reads the installed version and build number locally through `AppVersionService`; Riverpod caches the result for the application lifetime.

Settings navigation clears the active input focus before pushing a page or model picker so returning cannot reopen a previously focused search or credential field. The model picker follows the share overlay's surface, 30-pixel top corners, muted drag handle, modal barrier, and phone/tablet width behavior. It fits its content up to 92% of the available screen height, then scrolls longer model lists. It reuses `FadeEdges` with a content-sized viewport and the sheet's surface color; fades appear only toward remaining scrollable content and disappear when refreshed catalogs no longer overflow. Other scroll surfaces and the share overlay retain their existing layout behavior.

Shared pressable controls expose localized semantic names, selected state where applicable, visible keyboard focus, and Enter/Space activation. The settings switch row merges its descriptive text with the native switch semantics.

First-run onboarding separates provider connections and model selection into consecutive wizard screens using the same credential and task controls as settings. Compact connection rows reveal one credential form at a time; at least one verified provider is required. Provider editors expand and collapse over 220 milliseconds with cubic easing, or immediately when system animations are disabled. Collapsed fields leave focus, semantics, and hit testing immediately while their draft controller remains available for reopening. The next screen only offers connected providers; entering it retains connected stage choices and replaces disconnected selections with a connected provider. Progress requires a selected model from the current purpose-specific API catalog for transcription and, when enabled, summaries. Loading, failed, or empty catalogs do not satisfy this requirement. Going back preserves credentials and model choices. Disabled summaries do not fetch a catalog or block progress. Settings use the same task cards without wizard navigation.

Provider behavior is split into small contracts:

- `TranscriptionProviderClient` uploads audio and returns a transcription.
- `SummaryProviderClient` turns transcript text into a structured summary response.
- `ModelCatalogClient` lists selectable models.
- `RemoteProviderClient` composes the three contracts for the factory.

`OpenAiClient` and `GoogleClient` implement direct REST requests with the existing `http` stack. Provider model catalogs are loaded dynamically and filtered by `ProviderModelCapabilities` because neither catalog exposes complete audio-input and text-output modality metadata. Dedicated transcription models use provider-native transcription payloads, while compatible multimodal models receive audio plus a plain-text transcription instruction. Provider-specific payloads and errors remain behind those clients. API keys are transmitted in headers and are never placed in URLs, database rows, logs, or user-visible error details.

Gemini transcription Interactions are stateless (`store: false`); the app does not use continuation IDs. Files API uploads are separate resources whose deletion is attempted after processing.

Each REST request owns an abort trigger, deadline, and bounded response subscription. Deadlines cancel transport and response consumption, including stalled uploads and late headers. Processing stages, model catalogs, and credential checks close their internally created clients in `finally`; injected HTTP clients remain caller-owned. Cancellation cleanup waits at most one second. Injected transports must implement the HTTP package's abortable-request contract to terminate their own underlying I/O.

Keyboard dictation uses the separate `LiveTranscriptionClient` contract. Its fixed compatibility catalog maps OpenAI `gpt-live-transcribe` to 24 kHz PCM and Gemini `gemini-3.5-transcribe-live` to 16 kHz PCM. Language hints are normalized per protocol, including `de-DE` and `en-US` for Gemini. Native `AudioRecord` emits mono PCM16 chunks through an event channel. The selected live client confirms provider setup before recording, streams those chunks over WebSocket, and emits partial and final text events. A single bounded deadline covers DNS, TLS, the WebSocket handshake, and provider setup. Cancellation invalidates late sockets, and socket shutdown is bounded so cleanup cannot leave the UI in a transient state. Sanitized connection failures distinguish authentication, quota, model access, rejected configuration, timeout, and transient disconnects without exposing provider responses or credentials.

Connected live uploads use a FIFO capped at 256 KiB of UTF-8 messages, including the in-flight write. `WebSocket.addStream` propagates transport backpressure instead of accumulating unchecked `add` calls. Each write has a five-second deadline; overflow or a stalled/failed write ends the session with a sanitized connection failure and drops queued audio. Setup, audio, and finalization use the same ordered sender. Transport completion is not provider acknowledgement.

OpenAI live transcription disables server-side turn detection and commits the audio turn explicitly on stop, following the [Realtime transcription protocol](https://developers.openai.com/api/docs/guides/realtime-transcription). Live deltas remain replaceable while recording. Finalization waits for the manual commit acknowledgement and the final transcript for its confirmed item ID; an older or duplicate final cannot finish a newer turn. Missing final responses fail within four seconds rather than silently accepting an incomplete finalization.

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

Leaving a running processing view requests cooperative cancellation. The pipeline checks that request before starting provider stages and audio retention, and after asynchronous work returns. An in-flight provider request may finish, but subsequent summary/retention stages are skipped. If retention has already started, the controller removes its resulting owned copy. External source files are never removed; this does not promise server-side cancellation of an accepted provider request.

Processing routes carry distinct ownership tokens. A pop requests cancellation immediately, and a result from an exiting route cannot replace the current page. The controller allows one pending replacement while the cancelled operation drains; dismissing that replacement discards its owned input. An already accepted note save completes before the replacement starts and keeps its persisted audio.

File selection, import validation, and navigation failures show a localized error without exposing filesystem paths. A rejected import can be selected again, and navigation failures discard only the newly imported working copy. In the share entry point, settings open on the local navigator while the sheet and its input remain available. Returning retries processing; the native share activity finishes only when the sheet is dismissed or saved.

After successful transcription, a summary failure produces a transcript-only note with empty summary fields and a nullable `summaryError` diagnostic. Transcription failures still abort processing. Empty summary responses and Gemini token-limit truncation count as summary failures. Detail views and the share preview display a localized warning and the stored diagnostic while preserving the expandable transcript. The regular flow saves the note; the share preview retains its existing explicit save/discard boundary. Audio retention and cleanup follow the same transaction rules as fully summarized notes.

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

Incoming live messages are size-checked before decoding and schema-checked before they become events. The controller caps the complete session transcript at 250,000 characters and coalesces waiting composition writes while preserving serialized final commits.

## Persistence

Drift tables store singleton settings, notes, ordered key points, ordered to-dos, ordered transcript text segments, and migration markers. Timestamps are intentionally not part of the transcript domain or database schema. Repository writes are transactional. API keys remain exclusively in `FlutterSecureStorage`.

Ordinary note operations insert/restore, delete, or toggle one persisted item; they never replace another engine's complete note snapshot. Reads and targeted mutation results are transactional, and each controller serializes state publication after successful commits. Whole-snapshot replacement is reserved for explicit import/test setup. Failed saves retain the finished note and audio for idempotent persistence retry without another provider call. Share commit/discard operations coordinate their ownership decision so dismissing a saving preview cannot remove committed audio; save failures leave the action retryable. Undo retains the application controller independently of the removed detail route.

Schema version 3 adds the nullable `notes.summary_error` column. Existing notes and legacy JSON default to no summary failure. The diagnostic survives note reloads and JSON round trips.

The one-time legacy migration checks its marker inside a database transaction before reading or parsing old settings and notes. The marker, settings, notes, points, to-dos, and transcript segments commit atomically. Successfully imported SharedPreferences values are removed only after the commit. Completed migrations leave any remaining recovery payload untouched and do not deserialize it again; obsolete credential cleanup still runs.

History loads after the main UI starts, using metadata-only keyset pages of at most 50 entries, ordered by creation date and ID. Phone and tablet build individual visible rows lazily. Search, page changes, mutation invalidation, and activity resume replace the current page rather than accumulating an unbounded list. Filtered totals and substring searches inspect note metadata; transcript and summary payloads are excluded. Shared audio startup never loads history.

Selected details load by primary key with ordered, note-scoped child queries. Active detail providers dispose their data with their consumers; the mutation controller retains at most eight recently changed notes. Successful writes and resume invalidate consumers, preserving visibility of the separate share engine without loading the entire history. Deletion retrieves only the target audio metadata before its targeted writes.

Schema version 4 adds the `(created_at DESC, id DESC)` history index and a `title_search` value normalized with Dart lowercase for consistent Unicode search. Upgrade normalizes existing titles in batches of 128 rows without reading transcripts. Literal `%`, `_`, and backslash search characters are escaped as data.

Schema creation, upgrades, and their version marker commit in one SQLite transaction. The version 4 step also recognizes a `title_search` column or history index left by the older non-atomic migration and finishes the backfill safely. Foreign-key enforcement is disabled before schema upgrades and enabled before normal queries on every connection, preserving child references and cascading deletion. Schema version 5 adds a durable queue for retained audio pending deletion; a deleted note's audio path enters that queue in the same transaction as the note removal.

## Audio Ownership

`ManagedAudioFile` carries explicit `external`, `temporary`, or `retained` ownership. Destructive operations validate that a path belongs to the corresponding app directory. External originals are never deleted. See [cache lifecycle](cache-lifecycle.md).
