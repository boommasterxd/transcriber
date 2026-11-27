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

Settings use framework-independent `AppearanceSettings`, `TranscriptionSettings`, and `SummarySettings` values. Flutter theme modes and accent colors are mapped only in `lib/core/theme/`. `TranscriptNote` groups recording metadata, processing origins, and generated content. Drift tables persist notes, and the migration reads the legacy flat JSON format.

## Entry Points and Bootstrap

`lib/main.dart` declares three entry points:

- `main` renders the normal application;
- `shareMain` delegates to `lib/share_entrypoint.dart` for the translucent Android share target;
- `keyboardMain` delegates to `lib/keyboard_entrypoint.dart` for the Android input method.

The main and share entry points mount a startup view before loading dependencies. `loadAppBootstrap`:

1. opens the Drift database;
2. atomically imports legacy SharedPreferences data once;
3. loads settings and provider connection state without historical transcripts;
4. supplies the initialized dependencies to the startup gate, which injects them into Riverpod and mounts the app surface.

A startup failure closes any database opened by that attempt and shows a retry action. The share startup view also supports dismissal. Orderly share shutdown drains current processing, waits for startup maintenance, closes the owned database and then finishes the native activity. Detachment requests cleanup without waiting for another native finish call.

After the app surface mounts, maintenance runs cache cleanup and removes obsolete credentials that still need cleanup. The regular app also retries the durable retained-audio deletion queue. Both entry points use the [shared quota at reservation time](cache-lifecycle.md#limits).

SharedPreferences is used for legacy migration. The migrator reads the old payload, preserves rejected records when needed, and removes eligible source values after the Drift commit. See [persistence](#persistence) for the cleanup and retry behavior.

The normal entry point opens Android's Storage Access Framework through `AudioImportPickerService` and the native `AudioDocumentPicker`. The picker accepts one openable `audio/*` content URI with a temporary read grant. Android activity state retains only the pending document request code. After system recreation, the normal entry point checks once for the returned document and offers it after onboarding. An explicit confirmation starts cloud processing. A new pick supersedes an unfinished recovery, and dismissing the offer deletes the app-owned copy. The original stays with its document provider.

The document picker and native share activity copy external audio once into app cache through the same process-wide single-worker executor. Dart registers the validated copy in place. The deadline is 60 seconds from the document result or share import start. The native share activity is the media-sharing entry point and uses the first URI for `SEND_MULTIPLE`. Audio `VIEW` and share filters enter through that path, including explicit media intents forwarded from the launcher. An early `getInitialSharedPath` call waits for a completed import. Activity destruction, explicit finish, or the deadline cancels pending work. Native code owns descriptors, streams, cancellation signals and incomplete files until handoff. Late handoffs after dismissal are discarded on a best-effort basis. A separate bounded cleanup worker keeps cancellation off the main thread. An uncooperative provider can occupy the single import slot until its I/O returns.

The keyboard entry point deliberately loads only the database, settings repository, active settings, and secure credential boundary. It does not load notes or run cache cleanup. `TranscriberInputMethodService` owns a dedicated `FlutterEngine` and embeds the keyboard Flutter view in a measured 312 dp input container. Fullscreen extract mode is disabled so Android cannot expand the dictation surface over the application. Native Android code owns editor lifecycle, microphone capture, and `InputConnection`; Flutter owns the live-session controller and keyboard presentation.

Keyboard activation remains optional. The settings card opens a dedicated Flutter onboarding screen that explains the effective live provider and guides users through enabling the input method and selecting it in Android. It reads status from Android after every system action, application resume, and return from onboarding; it does not mark setup complete until Android reports Transcriber as selected. Once complete, settings offer keyboard management and onboarding renders a completed state instead of setup actions.

## Provider Boundaries

Settings use a navigation overview with keyboard, model selection, and general pages. General settings combine language and region, appearance, and privacy. The keyboard page explains dictation beneath its setup card. Model selection shows separate speech-to-text and summary task cards with purpose, current API model, and provider. The summary switch belongs to its card. Opening the model row shows a task-specific picker with connected providers and a live catalog. Keyboard navigation moves focus. Activating a model by touch, Enter or Space persists its provider and identifier together and closes the picker. Browsing providers or dismissing the picker preserves the saved choice. The refresh button, pull-to-refresh, F5, and a screen-reader action reload the catalog. Loading, errors, missing credentials, and unavailable saved models cannot be selected. The provider connections page manages the credentials shared across processing stages and keyboard dictation. The overview reads the installed version and build number through `AppVersionService` and caches the result for the application lifetime.

Opening the settings overview clears focus from an active text editor. The model picker and share preview use `app_bottom_sheet.dart` for route options, width, surface, drag handle, barrier and a maximum height of 92% of the viewport. The model list builds rows lazily and scrolls longer catalogs. The share result fills the available sheet, while confirmation, progress and error states wrap their content up to the same height limit.

Shared pressable controls expose localized semantic names, selected state where applicable, visible keyboard focus, and Enter/Space activation. The settings switch row merges its descriptive text with the native switch semantics. App-controlled onboarding and processing effects honor the system reduced-motion setting.

First-run onboarding separates provider connections and model selection into consecutive wizard screens using the same controls as settings. Compact connection rows reveal one credential form at a time and require at least one verified provider. Expanding a credential editor creates its controller and reads the stored key for its masked field. Collapsing clears that value and removes the field from focus, semantics and hit testing. An explicit replacement draft can be reopened while its provider card remains mounted. The editors expand and collapse over 220 milliseconds with cubic easing and honor disabled system animations. The next screen offers connected providers and replaces disconnected selections with a connected provider. Progress requires a model from the current catalog for transcription and, when enabled, summaries. Disabled summaries require no catalog. Going back preserves credentials and model choices. Settings use the same task cards.

Provider behavior is split into small contracts:

- `TranscriptionProviderClient` uploads audio and returns a transcription.
- `SummaryProviderClient` turns transcript text into a structured summary response.
- `ModelCatalogClient` lists selectable models.
- `RemoteProviderClient` composes the three contracts for the factory.

`OpenAiClient` and `GoogleClient` implement direct REST requests with the existing `http` stack. Provider model catalogs are loaded dynamically and filtered by `ProviderModelCapabilities` because neither catalog exposes complete audio-input and text-output modality metadata. Dedicated transcription models use provider-native transcription payloads, while compatible multimodal models receive audio plus a plain-text transcription instruction. Provider-specific payloads and errors remain behind those clients. API keys are transmitted in headers and are never placed in URLs, database rows, logs, or user-visible error details.

OpenAI inline audio requests encode file chunks as Base64 into the JSON body with a known content length. Gemini uploads stream audio through the Files API. Gemini transcription Interactions omit continuation IDs, and transcription and summary requests send `store: false`. Uploaded files are separate resources. A bounded best-effort deletion attempt for a known file runs independently of reporting the processing result.

Each REST request owns an abort trigger, deadline, and bounded response subscription. A processing run shares its cancellation signal across upload, transcription, optional summary and file polling. Supported transports abort I/O, including stalled uploads and late headers. The SDK stream closes on cancellation, and subscription cleanup waits at most one second. Processing stages, catalog loading and credential checks close the clients they own in `finally`. Injected clients remain caller-owned and must support abortable requests to terminate their own I/O.

Keyboard dictation uses the separate `LiveTranscriptionClient` contract. Its fixed compatibility catalog maps OpenAI `gpt-live-transcribe` to 24 kHz PCM and Gemini `gemini-3.5-transcribe-live` to 16 kHz PCM. Language hints are normalized per protocol, including `de-DE` and `en-US` for Gemini. A single start operation resolves settings and credentials for the current editor before provider setup and microphone capture. Native `AudioRecord` emits mono PCM16 through an event channel. The native handoff queue holds at most 12 chunks of 4,800 bytes and stops capture on overflow. Capture and editor transitions discard queued audio from the previous session.

The live connector uses a direct TCP/TLS connection with certificate and hostname validation. A single application deadline covers DNS, TLS, WebSocket upgrade and provider setup. Cancellation closes available HTTP and socket handles and rejects late results. The connection gate holds an unfinished native TLS handshake until it settles, so another attempt cannot stack behind it. Sanitized failures distinguish authentication, quota, model access, configuration, timeout and transient disconnects.

Connected live uploads use a FIFO capped at 256 KiB of UTF-8 messages, including the in-flight write. `WebSocket.addStream` propagates transport backpressure instead of accumulating unchecked `add` calls. Each write has a five-second deadline; overflow or a stalled/failed write ends the session with a sanitized connection failure and drops queued audio. Setup, audio, and finalization use the same ordered sender. Transport completion is not provider acknowledgement.

OpenAI live transcription opens a dedicated Realtime session with `intent=transcription`. It disables server-side turn detection and commits the audio turn explicitly on stop, following the [Realtime transcription protocol](https://developers.openai.com/api/docs/guides/realtime-transcription). Live deltas remain replaceable while recording. Finalization waits up to four seconds for the manual commit acknowledgement and the final transcript for its confirmed item ID. An older or duplicate final cannot finish a newer turn.

## Processing Flow

```text
record, import, or share
  -> app-owned temporary audio or validated external reference
  -> selected transcription provider and model
  -> optional selected summary provider and model
  -> Drift note transaction and optional staged audio promotion
  -> app-owned working-copy cleanup
```

`ProcessingPipeline` receives an immutable settings snapshot and separate credentials for the active stages. Transcription and summary providers are independent. New notes record provider and model origins, and legacy origin fields remain readable. The controller uses the request's settings snapshot to select upload targets and decide whether to retain audio when saving the note.

Leaving a running processing view cancels the run's local provider request or poll and prevents subsequent processing stages. Abortable transports stop local I/O and response consumption. A provider can still process a request it already accepted. The controller cleans up its owned staging and temporary files on cancellation and preserves the original external source.

Processing routes carry distinct ownership tokens. A pop requests cancellation immediately, and a result from an exiting route cannot replace the current page. The controller allows one pending replacement while the cancelled operation drains; dismissing that replacement discards its owned input. An already accepted note save completes before the replacement starts and keeps its persisted audio.

Recordings, ordinary and recovered file selections, and Android shares show the audio recipient and the transcript recipient when summaries are enabled. Confirmation binds processing to the displayed provider choices. The main app reads settings from storage before presenting the confirmation. On a cloud retry, it asks again when the recipients change or the user returns from settings. The share sheet rechecks the displayed processing and retention choices before submitting and asks again if they have changed. Local save retries reuse the completed result. Import and navigation failures show a localized error, and cancellation discards the app-owned working copy.

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
  -> discard clears the confirmed composing region
  -> editor change, keyboard hide, or failure closes all session resources
```

`EditorFieldPolicy` rejects password, PIN, non-text, and no-personalized-learning editors before recording can start. `EditorSessionGate` assigns a new identifier on every editor transition and rejects late platform calls and provider events from stale sessions. The service writes all finalized segments into one composing region until the user stops. Discard and editor changes clear that region when Android confirms its position. Editors that omit or delay confirmation may leave draft text in place. The service never reads surrounding text. Editor writes and visibility transitions are serialized, preventing late partials and cleanup from overwriting newer state. The session-gated backward action deletes an active selection or one code point, with a delete-key fallback for incompatible editors. Holding it repeats and accelerates until release.

A bounded in-memory audio queue bridges short reconnects and is cleared when the session ends. Gemini uses SMART input transcription. The target editor renders recognized text. The keyboard reuses recording controls and the 42-bar perceptual dBFS waveform with reduced-motion support. The top bar shows the active timer and the switch action shows the provider mark. Connecting shows progress and cancellation. Both text and binary WebSocket messages are supported.

Both live providers share an eight-minute session limit and a PCM byte budget that also applies across reconnects. The session ends after one minute paused or one minute of capture without PCM. At a limit, the controller stops capture and attempts normal finalization for the active editor. A transport interruption at that point can still allow already received text to be committed.

Live WebSocket compression is disabled. The transport reads at most 5 MiB plus 64 KiB of protocol overhead between completed messages and feeds the parser in slices of at most 16 KiB. Message payloads have a separate 5 MiB limit before JSON decoding and schema validation. The controller caps the complete session transcript at 250,000 characters and coalesces waiting composition writes while preserving serialized final commits.

## Persistence

Drift tables store singleton settings, notes, ordered key points, ordered to-dos, ordered transcript text segments, and migration markers. Transcript segments store text and order. Settings updates apply the user's change to the current row in a write transaction. The main app refreshes persisted settings on resume, and the controllers read current settings at processing boundaries. API keys remain exclusively in `FlutterSecureStorage`.

Ordinary note operations insert, restore, delete, or toggle one persisted item. Reads and targeted mutation results are transactional, and each controller serializes state publication after successful commits. Whole-snapshot replacement is reserved for explicit import or test setup. Failed saves retain the finished note and audio for idempotent persistence retry without another provider call. Share commit and discard coordinate ownership so dismissing a saving preview preserves committed audio. An undoable deletion captures the current note and its children in the delete transaction. Undo restores that snapshot, and a failed restore offers a retry before retained audio is finalized.

Schema version 3 adds the nullable `notes.summary_error` column. Existing notes and legacy JSON default to no summary failure. The diagnostic survives note reloads and JSON round trips.

Legacy note decoding, validation, and sorting run in a worker isolate. The decoder still reads the whole legacy JSON list. The import rechecks its markers in the database transaction and writes note and child rows in batches of up to 128, committing the settings, notes and import marker together. Separate cleanup markers track legacy preferences. For a mixed note list, the migration preserves rejected records in `legacy_unimported_notes_v1` before marking the source list removable. Unreadable values and wholly rejected lists stay under their original key. Failed recovery writes or source removals can retry without reimporting notes. Obsolete credential cleanup runs after startup with a separate completion marker.

History loads metadata-only pages of at most 50 entries using a cursor based on creation date and ID. The controller publishes the page before loading an uncached exact total. It reuses the total for the same normalized filter and database revision, ignores stale results, and keeps navigation usable if counting fails. A changed search starts at page one. A changed history revision reloads the current cursor and falls back to page one if that page is empty. Resume checks the revision before reloading. The share entry point loads no history.

Selected details load by primary key with ordered, note-scoped child queries. Active detail providers dispose their data with their consumers. The mutation controller retains at most eight recently changed notes. Resume checks for peer-engine edits before invalidating detail consumers. The database interceptor exposes a generic typed error and keeps driver messages and SQL arguments out of UI errors.

Phone and tablet details and the share result render key points, tasks and transcript text through lazy slivers. The tablet uses a responsive two-column layout. Long single-block transcripts can wrap across grapheme-aligned display segments. Copy and share use the original transcript text. The audio player checks source availability asynchronously and initializes the decoder on the first play or seek action. It offers localized play and pause actions and an adjustable playback position through focus, keyboard and accessibility controls.

The interface labels known generated titles, summaries, key points and action items. Older summaries without established provenance display an unknown-origin label. Plain-text note sharing includes the title, any usable summary, and the transcript. When the title or summary has known generated provenance, sharing adds a `Transcriber-Provenance` JSON line with version 2 and separate IPTC `digitalSourceType` entries for the known fields. The marker is informational and receiving apps may omit it.

Schema version 4 adds the `(created_at DESC, id DESC)` history index and a `title_search` value normalized with Dart lowercase for consistent Unicode search. Upgrade normalizes existing titles in batches of 128 rows without reading transcripts. Literal `%`, `_`, and backslash search characters are escaped as data.

Schema creation, upgrades, and their version marker commit in one SQLite transaction. The version 4 step also recognizes a `title_search` column or history index left by the older non-atomic migration and finishes the backfill safely. Foreign-key enforcement is disabled before schema upgrades and enabled before normal queries on every connection, preserving child references and cascading deletion. Schema version 5 adds a durable queue for retained audio pending deletion; a deleted note's audio path enters that queue in the same transaction as the note removal.

Schema version 6 adds a history revision and an optional FTS5 trigram index over normalized titles. Triggers update the revision and index on note insertion, deletion, and title updates. When the index is available and the bounded probe finds at most 512 candidates, title search narrows the candidate set and applies the exact literal substring match. Short or common queries use the existing history order and literal filter. FTS5 secure deletion removes obsolete index entries.

Schema version 7 adds a nullable title provenance flag. Existing notes keep an unknown title source unless that information was already recorded in the imported legacy note.

## Audio Ownership

`ManagedAudioFile` carries explicit `external`, `temporary`, or `retained` ownership. Destructive operations validate that a path belongs to the corresponding app directory. External originals are never deleted. See [cache lifecycle](cache-lifecycle.md).
