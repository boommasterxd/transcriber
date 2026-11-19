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
4. injects initialized dependencies into Riverpod and starts rendering.

After the first frame, maintenance removes expired temporary audio and any obsolete credentials that still need cleanup. The regular app also enforces the temporary quota and retries the durable retained-audio deletion queue. The share entry point limits maintenance to expiration and obsolete credentials.

SharedPreferences remains a read-only legacy source until the migration window is intentionally removed. It is not the active persistence layer.

The normal entry point opens Android's Storage Access Framework through `AudioImportPickerService` and the native `AudioDocumentPicker`. The picker accepts one openable `audio/*` content URI with a temporary read grant. Android activity state retains only the pending document request code. After system recreation, the normal entry point checks once for the returned document and offers it after onboarding. An explicit confirmation starts cloud processing. A new pick supersedes an unfinished recovery, and dismissing the offer deletes the app-owned copy. The original stays with its document provider.

The document picker and native share activity copy external audio once into app cache through the same process-wide single-worker executor. Dart registers the validated copy in place. The deadline is 60 seconds from the document result or share import start. The share activity imports one file per intent and uses the first URI for `SEND_MULTIPLE`. Audio `VIEW` and share filters enter through that path, including explicit media intents forwarded from the launcher. An early `getInitialSharedPath` call waits for a completed import. Activity destruction, explicit finish, or the deadline cancels pending work. Native code owns descriptors, streams, cancellation signals and incomplete files until handoff. A separate bounded cleanup worker keeps cancellation off the main thread. An uncooperative provider can occupy the single import slot until its I/O returns.

The keyboard entry point deliberately loads only the database, settings repository, active settings, and secure credential boundary. It does not load notes or run cache cleanup. `TranscriberInputMethodService` owns a dedicated `FlutterEngine` and embeds the keyboard Flutter view in a measured 312 dp input container. Fullscreen extract mode is disabled so Android cannot expand the dictation surface over the application. Native Android code owns editor lifecycle, microphone capture, and `InputConnection`; Flutter owns the live-session controller and keyboard presentation.

Keyboard activation remains optional. The settings card opens a dedicated Flutter onboarding screen that explains the effective live provider and guides users through enabling the input method and selecting it in Android. It reads status from Android after every system action, application resume, and return from onboarding; it does not mark setup complete until Android reports Transcriber as selected. Once complete, settings offer keyboard management and onboarding renders a completed state instead of setup actions.

## Provider Boundaries

Settings use a navigation overview with keyboard, model selection, and general pages. General settings combine language and region, appearance, and privacy. The keyboard page explains dictation beneath its setup card. Model selection shows separate speech-to-text and summary task cards, with purpose, current API model, and provider together; the summary switch belongs to its card. Tapping a model opens a task-specific modal with connected providers and a live catalog. Choosing a model immediately persists its provider and identifier together and closes the modal; browsing providers or dismissing without a choice leaves both tasks unchanged. Pull-to-refresh reloads the catalog; F5 and a screen-reader action provide accessible alternatives. Loading, errors, missing credentials, and unavailable saved models cannot be selected. Its nested provider connections page manages each provider's credentials once, shared across processing stages and keyboard dictation. The overview reads the installed version and build number locally through `AppVersionService`; Riverpod caches the result for the application lifetime.

Settings navigation clears the active input focus before opening a page or model picker. The model picker and share preview use `app_bottom_sheet.dart` for route options, width, surface, drag handle, barrier and a maximum height of 92% of the viewport. The model list wraps short content and scrolls longer catalogs. Its edge fades indicate remaining content. The share result fills the available sheet, while confirmation, progress and error states wrap their content up to the same height limit.

Shared pressable controls expose localized semantic names, selected state where applicable, visible keyboard focus, and Enter/Space activation. The settings switch row merges its descriptive text with the native switch semantics. App-controlled onboarding and processing effects honor the system reduced-motion setting.

First-run onboarding separates provider connections and model selection into consecutive wizard screens using the same controls as settings. Compact connection rows reveal one credential form at a time and require at least one verified provider. Expanding a credential editor creates its controller and reads the stored key for its masked field. Collapsing clears that value and removes the field from focus, semantics and hit testing. An explicit replacement draft can be reopened while its provider card remains mounted. The editors expand and collapse over 220 milliseconds with cubic easing and honor disabled system animations. The next screen offers connected providers and replaces disconnected selections with a connected provider. Progress requires a model from the current catalog for transcription and, when enabled, summaries. Disabled summaries require no catalog. Going back preserves credentials and model choices. Settings use the same task cards.

Provider behavior is split into small contracts:

- `TranscriptionProviderClient` uploads audio and returns a transcription.
- `SummaryProviderClient` turns transcript text into a structured summary response.
- `ModelCatalogClient` lists selectable models.
- `RemoteProviderClient` composes the three contracts for the factory.

`OpenAiClient` and `GoogleClient` implement direct REST requests with the existing `http` stack. Provider model catalogs are loaded dynamically and filtered by `ProviderModelCapabilities` because neither catalog exposes complete audio-input and text-output modality metadata. Dedicated transcription models use provider-native transcription payloads, while compatible multimodal models receive audio plus a plain-text transcription instruction. Provider-specific payloads and errors remain behind those clients. API keys are transmitted in headers and are never placed in URLs, database rows, logs, or user-visible error details.

Gemini transcription Interactions are stateless (`store: false`); the app does not use continuation IDs. Files API uploads are separate resources whose deletion is attempted after processing.

Each REST request owns an abort trigger, deadline, and bounded response subscription. A processing run shares its cancellation signal across upload, transcription, optional summary and file polling. Supported transports abort I/O, including stalled uploads and late headers. The SDK stream closes on cancellation, and subscription cleanup waits at most one second. Processing stages, catalog loading and credential checks close the clients they own in `finally`. Injected clients remain caller-owned and must support abortable requests to terminate their own I/O.

Keyboard dictation uses the separate `LiveTranscriptionClient` contract. Its fixed compatibility catalog maps OpenAI `gpt-live-transcribe` to 24 kHz PCM and Gemini `gemini-3.5-transcribe-live` to 16 kHz PCM. Language hints are normalized per protocol, including `de-DE` and `en-US` for Gemini. A single start operation resolves settings and credentials for the current editor before provider setup and microphone capture. Native `AudioRecord` emits mono PCM16 through an event channel. The native handoff queue holds at most 12 chunks of 4,800 bytes and stops capture on overflow. Capture and editor transitions discard queued audio from the previous session.

The live connector uses a direct TCP/TLS connection with certificate and hostname validation. A single application deadline covers DNS, TLS, WebSocket upgrade and provider setup. Cancellation closes available HTTP and socket handles and rejects late results. The connection gate holds an unfinished native TLS handshake until it settles, so another attempt cannot stack behind it. Sanitized failures distinguish authentication, quota, model access, configuration, timeout and transient disconnects.

Connected live uploads use a FIFO capped at 256 KiB of UTF-8 messages, including the in-flight write. `WebSocket.addStream` propagates transport backpressure instead of accumulating unchecked `add` calls. Each write has a five-second deadline; overflow or a stalled/failed write ends the session with a sanitized connection failure and drops queued audio. Setup, audio, and finalization use the same ordered sender. Transport completion is not provider acknowledgement.

OpenAI live transcription disables server-side turn detection and commits the audio turn explicitly on stop, following the [Realtime transcription protocol](https://developers.openai.com/api/docs/guides/realtime-transcription). Live deltas remain replaceable while recording. Finalization waits for the manual commit acknowledgement and the final transcript for its confirmed item ID; an older or duplicate final cannot finish a newer turn. Missing final responses fail within four seconds rather than silently accepting an incomplete finalization.

## Processing Flow

```text
record, import, or share
  -> app-owned temporary audio or validated external reference
  -> selected transcription provider and model
  -> optional selected summary provider and model
  -> Drift note transaction and optional staged audio promotion
  -> app-owned working-copy cleanup
```

`ProcessingPipeline` receives an immutable settings snapshot and separate credentials for both stages. This supports all four OpenAI/Gemini combinations without coupling the stages. New notes record both provider and model origins. Legacy local-origin fields remain readable so historical notes retain accurate provenance.

Leaving a running processing view cancels the run's local provider request or poll and prevents subsequent processing stages. Abortable transports stop local I/O and response consumption. A provider can still process a request it already accepted. The controller cleans up its owned staging and temporary files on cancellation and preserves the original external source.

Processing routes carry distinct ownership tokens. A pop requests cancellation immediately, and a result from an exiting route cannot replace the current page. The controller allows one pending replacement while the cancelled operation drains; dismissing that replacement discards its owned input. An already accepted note save completes before the replacement starts and keeps its persisted audio.

File selection, import validation, and navigation failures show a localized error without exposing filesystem paths. A rejected import can be selected again, and navigation failures discard only the newly imported working copy. The share sheet shows which providers will receive audio and, when enabled, transcript text. Processing starts after confirmation with the displayed provider settings. From an error, retry uses the approved settings. Returning from the local Settings page shows the updated recipients for a fresh confirmation. The native share activity finishes on dismissal or save.

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

Live WebSocket compression is disabled. The transport reads at most 5 MiB plus 64 KiB of protocol overhead between completed messages and feeds the parser in slices of at most 16 KiB. Message payloads have a separate 5 MiB limit before JSON decoding and schema validation. The controller caps the complete session transcript at 250,000 characters and coalesces waiting composition writes while preserving serialized final commits.

## Persistence

Drift tables store singleton settings, notes, ordered key points, ordered to-dos, ordered transcript text segments, and migration markers. Timestamps are intentionally not part of the transcript domain or database schema. Repository writes are transactional. API keys remain exclusively in `FlutterSecureStorage`.

Ordinary note operations insert/restore, delete, or toggle one persisted item; they never replace another engine's complete note snapshot. Reads and targeted mutation results are transactional, and each controller serializes state publication after successful commits. Whole-snapshot replacement is reserved for explicit import/test setup. Failed saves retain the finished note and audio for idempotent persistence retry without another provider call. Share commit/discard operations coordinate their ownership decision so dismissing a saving preview cannot remove committed audio; save failures leave the action retryable. Undo retains the application controller independently of the removed detail route.

Schema version 3 adds the nullable `notes.summary_error` column. Existing notes and legacy JSON default to no summary failure. The diagnostic survives note reloads and JSON round trips.

The legacy migration commits settings, notes and their children with the import marker. Separate cleanup markers track legacy settings and notes, including leftovers from earlier successful imports. For a mixed note list, the migration merges only rejected records into `legacy_unimported_notes_v1` and requires that write to succeed before queuing removal of the source list. Unreadable note values and lists with only rejected entries stay under their original key. A failed recovery write or source removal is retried on a later startup without reimporting notes. Obsolete provider key cleanup runs after startup and records completion separately.

History loads after the main UI starts, using metadata-only keyset pages of at most 50 entries ordered by creation date and ID. Phone and tablet build visible rows lazily. The shared search field batches typing for 180 milliseconds and submits immediately on the keyboard search action. Filter changes, page navigation, note insertion or removal, and activity resume update the current page. A to-do status change refreshes its detail without resetting history. The exact filtered total is reused while the normalized filter and persisted history revision match. Queries use note metadata, and the share entry point loads no history.

Selected details load by primary key with ordered, note-scoped child queries. Active detail providers dispose their data with their consumers. The mutation controller retains at most eight recently changed notes. Successful relevant writes and resume invalidate consumers, preserving visibility of the separate share engine without loading the entire history. Deletion retrieves only the target audio metadata before its targeted writes. A database interceptor returns a generic typed error to callers and keeps SQL arguments out of UI errors.

Phone and tablet details and the share result render key points, tasks and transcript text through lazy slivers. The tablet uses a responsive two-column layout. Long single-block transcripts can wrap across grapheme-aligned display segments. Copy and share use the original transcript text. The retained-audio player offers localized play and pause actions and an adjustable playback position through focus, keyboard and accessibility controls.

Known AI-generated summaries carry a localized label. For older summaries without established provenance, the interface identifies the origin as unknown. Sharing a note with a known AI-generated summary includes a plain-text `Transcriber-Provenance` JSON line with a version and the summary's IPTC `digitalSourceType`. The metadata describes the summary only. Receiving apps may omit the text marker, and it provides no cryptographic authentication.

Schema version 4 adds the `(created_at DESC, id DESC)` history index and a `title_search` value normalized with Dart lowercase for consistent Unicode search. Upgrade normalizes existing titles in batches of 128 rows without reading transcripts. Literal `%`, `_`, and backslash search characters are escaped as data.

Schema creation, upgrades, and their version marker commit in one SQLite transaction. The version 4 step also recognizes a `title_search` column or history index left by the older non-atomic migration and finishes the backfill safely. Foreign-key enforcement is disabled before schema upgrades and enabled before normal queries on every connection, preserving child references and cascading deletion. Schema version 5 adds a durable queue for retained audio pending deletion; a deleted note's audio path enters that queue in the same transaction as the note removal.

Schema version 6 adds a history revision and an optional FTS5 trigram index over normalized titles. Triggers update the revision and index on note insertion, deletion, and title updates. When the index is available and the bounded probe finds at most 512 candidates, title search narrows the candidate set and applies the exact literal substring match. Short or common queries use the existing history order and literal filter. FTS5 secure deletion removes obsolete index entries.

## Audio Ownership

`ManagedAudioFile` carries explicit `external`, `temporary`, or `retained` ownership. Destructive operations validate that a path belongs to the corresponding app directory. External originals are never deleted. See [cache lifecycle](cache-lifecycle.md).
