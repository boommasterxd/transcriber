# Performance Report

## Assessment

Updated on 2026-10-19 after implementing PERF-01, PERF-02 and PERF-03. All three findings are addressed in source and deterministic regression tests. The supported application remains Flutter Android, arm64-only, with independent cloud transcription and summary providers.

History now uses bounded metadata pages and lazy individual rows; selected transcripts load on demand. Native capture enforces the selected recording budget independently of Dart scheduling. Both model selectors share one credential-scoped provider catalog. Existing transaction, audio-ownership, HTTP cancellation and retry safeguards remain in place.

The evidence below is local source review, isolated host tests and debug microbenchmarks. No physical-device frame, microphone, battery or field-performance claim is made.

## Scope and Verification

The working tree includes coordinated quality fixes as well as these performance changes; no commit, push, PR, deployment or provider inference request was performed. Verification used Flutter 3.47.7, Dart 3.13.5, Drift 2.35.2, SQLite 3.53.4 in the database probe, Node.js 24.22.0 and JDK 17.

| Check | Actual result |
|---|---|
| Locked dependency resolution | `flutter pub get --enforce-lockfile` passed; no `pubspec.lock` change or new dependency. |
| Formatting and analyzer | All 365 Dart files formatted without changes; `flutter analyze --fatal-infos --no-pub` passed. |
| Complete Dart/Flutter suite | `flutter test --no-pub --coverage --branch-coverage`: 1,235 passed. |
| Complete Dart coverage | 168/168 executable sources, 175 maintained; lines 94.85%, statement proxy 94.85%, function proxy 92.82%, branches 88.26%. Existing 85/85/85/80 thresholds passed. |
| Metrics and parameter enforcement | DCL plus analyzer-based quality gate passed. |
| Unused code/files and duplication | Both unused-code/file checks passed; jscpd with 50 tokens and zero accepted duplication passed without clones. |
| Native Android | 73 tests passed; all 19 maintained sources verified. JaCoCo LINE 848/859, INSTRUCTION 4,634/4,748, METHOD 169/176, BRANCH 492/568, all above required thresholds. |
| Instrumented Android sources | `:app:compileDebugAndroidTestKotlin` passed; compilation does not establish device execution. |
| Current Android-targeted asset bundle | `flutter build bundle --debug --no-pub --target-platform android-arm64` passed; nonempty kernel (89,025,592 bytes) and asset manifest (261 bytes) verified. Debug kernel size is not APK size or a production payload measurement. |
| Independent pure Kotlin harness | 23 tests, six sources; LINE 173/176, INSTRUCTION 840/849, METHOD 33/33, BRANCH 85/92; strict verification passed. |
| Native static checks | Pinned, SHA-256-verified Detekt 1.23.8, source-length gate and whitespace checks passed. |
| CI helper and workflow checks | 34 Node helper tests passed, including native selection for the new recording bridge; pinned actionlint passed. |
| Coordinated Gradle failure fixtures | Six integration regressions passed against the final six-class JVM manifest, including four negative coverage mutations and real failure/skip propagation. |
| Secret scan | Checksum-verified Gitleaks 8.30.1 working-tree scan passed; both synthetic scanner regressions passed. |

Statement/function coverage mappings and native instruction/method proxies are documented in [code quality](../code-quality.md). Full coverage refers to the complete maintained source inventory, not selected test coverage. No dependency update was needed; a new OSV scan was not executed by this performance pass. The coordinated quality work separately reported a successful scan of the unchanged dependency graph.

An independent Sol review checked cursor ordering, cache freshness, selected details, provider credentials and native lifecycle boundaries. Its concrete findings were corrected and rechecked: responsive search synchronization, empty deep-page recovery, cancellation after persistent WAV finalization failure, and serialization of queued capture calls with engine cleanup.

## PERF-01: Bounded History and Targeted Details

Main and share bootstrap no longer load notes or transcripts. After the main interface starts, [NotesHistoryQuery](../../lib/data/repositories/notes_history_query.dart) returns one metadata page of at most 50 entries, using a 51st row only as a next-page probe. Ordering is stable by `created_at DESC, id DESC`; forward and reverse keysets avoid deep OFFSET work. Pages replace each other instead of accumulating an unlimited client list.

The projection excludes summary text, transcript segments and child collections. To-do badge counts use the indexed child primary key. Phone and tablet history use note-level lazy slivers. [HistoryController](../../lib/state/history_controller.dart) owns the active search and page; the controlled search field preserves its query across responsive layout changes. Empty pages caused by concurrent deletion fall back once to the first page.

[NotesRepository](../../lib/data/repositories/notes_repository.dart) loads a selected note and its ordered children by primary key. Mutations read/write only the target note; deletion retrieves only its audio metadata beforehand. Full replacement/loading remain explicit fixture/import operations, without ordinary application callers. The mutation cache retains at most eight recently changed notes; active detail providers dispose with their consumers.

### Database plans, query counts and freshness

Schema 4 adds `notes_history_order(created_at DESC, id DESC)` and a Dart-normalized `title_search` column. Upgrade normalizes existing titles in batches of 128 metadata rows. Substring matching retains Unicode lowercase behavior and treats percent, underscore and backslash as literal input.

Regression tests inspect actual SQL and execution plans. Unfiltered first/deeper-page queries use the history index; per-page to-do counts use the covering child primary key. Detail children use `(note_id, position)` ordering. There is no global child-table read or N+1 network request.

| Flow | Current application database work |
|---|---|
| Main/share bootstrap | No history SELECTs; settings, migration and credential initialization remain. |
| History page/search | One filtered count and one bounded metadata SELECT, in one transaction. |
| Selected detail | One target-note SELECT plus three note-scoped ordered child SELECTs; missing IDs stop after the first query. |
| Add/restore | Targeted note/child writes; no full-history readback. |
| To-do toggle | Targeted to-do SELECT/UPDATE and target-note detail readback. |
| Delete | One target audio-metadata SELECT plus targeted child/note DELETEs. |
| Mutation/resume invalidation | Active history reloads one page; active details refresh through their bounded providers/cache. No eager full-history reload. |

Filtered exact totals and arbitrary substring search still inspect note metadata. A page limit bounds returned data and child work, not every metadata row visited. This is the retained cost of exact totals and substring search; no universal constant-time database claim is made. Read-after-write publication and resume invalidation preserve cross-engine visibility. Search/page/order determine the active page, mutation/resume invalidation resets its cursor, and no additional TTL permits stale private data across users or engines.

### Actual local measurements

The real `AppDatabase(NativeDatabase.memory())` and repository used synthetic histories of 100 and 1,000 notes. Each note had five points, three to-dos and fifty 200-byte transcript segments, matching the earlier database workload. One untimed warm-up preceded five timed samples; deletion used three samples with restoration outside the timed interval. Values are warm desktop debug medians, excluding Android storage, production database-isolate IPC, device frames and controlled CPU throttling.

| Operation | 100 notes | 1,000 notes |
|---|---:|---:|
| First metadata page, 50 returned entries | 0.676 ms | 0.487 ms |
| Next metadata page | 0.621 ms | 0.434 ms |
| Targeted detail | 0.479 ms | 0.370 ms |
| Targeted to-do toggle | 0.516 ms | 0.406 ms |
| Targeted deletion | 0.429 ms | 0.476 ms |

These samples demonstrate bounded hydration and targeted work, not an Android speedup ratio. Earlier full-history timings are not treated as an equivalent controlled comparison.

Widget regressions used 50-entry pages with a reported total of 1,001 notes. At 390 × 800, phone history mounted four rows initially and ten at the page end. A 360-wide tablet sidebar at a 1,000 × 800 viewport mounted seven initially and seven at the end. Real scroll gestures reached entry 49; keyboard page navigation, loading/error/retry and search beyond the first 1,000 stored notes passed.

Durable regressions: [history SQL/pagination](../../test/data/repositories/notes_history_test.dart), [controller races/freshness](../../test/state/history_controller_test.dart), [lazy history/navigation](../../test/ui/screens/home/history_pagination_test.dart), [detail loading/retry](../../test/ui/screens/detail/note_detail_loading_test.dart), and [responsive search/resume](../../test/app_test.dart).

## PERF-02: Native Recording Budget

[RecordingLimits](../../lib/services/audio/recording_limits.dart) resolves the configured model's upload cap at capture start. Mono PCM16 at 16 kHz uses 32,000 bytes/second. Reserving the 44-byte WAV header and rounding down to full seconds gives:

| Configured client cap | Maximum capture duration | Maximum recorded file |
|---|---:|---:|
| 100 MiB batch cap | 3,276 seconds | 104,832,044 bytes |
| 20 MiB OpenAI inline cap | 655 seconds | 20,960,044 bytes |

[BoundedWaveWriter](../../android/app/src/main/kotlin/com/transcriber/app/BoundedWaveWriter.kt) checks capacity before every native write and clips oversized chunks to complete PCM samples. The cap therefore holds while the Dart isolate is paused. Capture automatically stops at the budget; the UI displays advance/limit notices and keeps explicit processing or discard actions. Pausing adds no recorded samples. Provider validation remains authoritative; a local cap does not guarantee provider acceptance or access.

Native channel operations run on a serial background task queue. Capture transitions and engine teardown share a monitor, and a terminal disposed flag prevents queued start/resume operations from reviving capture after cleanup. Stop closes descriptors even when header finalization fails; retry can reopen the file. Cancel closes/discards independently of successful finalization. Dart cleanup releases timers, streams and permission-plugin resources in failure paths. Engine cleanup closes abandoned capture without a main-thread file sync.

Regression tests cover sample alignment, boundary/oversized writes, invalid limits, paused capture, stop retry, persistent finalization failure, startup cancellation and stale queued handlers after teardown. See [native writer tests](../../android/app/src/test/kotlin/com/transcriber/app/BoundedWaveWriterTest.kt), [native channel tests](../../android/app/src/test/kotlin/com/transcriber/app/BoundedRecordingChannelTest.kt), [service lifecycle tests](../../test/services/audio/audio_recorder_service_test.dart), [controller tests](../../test/state/recording_controller_test.dart) and the [native recording ADR](../decisions/bounded-native-recording.md).

Actual microphone behavior, background suspension and multi-minute recording were not exercised on Android hardware.

## PERF-03: Shared Provider Catalog

[remoteModelCatalogProvider](../../lib/state/remote_models_provider.dart) caches one normalized raw listing per provider and public connection revision. Transcription and summary filter that data locally. Cache identities and catalog values do not contain API keys.

Mocked transport regressions establish one OpenAI catalog request or one Gemini paginated traversal for simultaneous task views, with no additional warm-view request. Explicit refresh/retry refreshes both views. Successful credential replacement, disconnect/reconnect and connection-state changes invalidate the affected provider; an unrelated provider remains warm. Late responses from replaced credentials cannot overwrite current state. Raw/derived providers use explicit user retry rather than hidden automatic request retries.

The 4 MiB response limit, ten-page Gemini bound and request deadlines remain. Owned HTTP clients close on completion/disposal. No inference probe, monetary saving, live-provider latency or billing amount was measured.

Durable regressions: [catalog cache, request counts and credential races](../../test/state/remote_models_provider_test.dart), [Gemini pagination](../../test/services/remote/google_client_catalog_test.dart) and [shared picker refresh](../../test/ui/screens/settings/remote_transcription_test.dart).

## Preserved Decisions and Limits

The accepted [cloud BYOK/Drift decision](../decisions/cloud-byok-and-drift.md), independent processing stages, arm64 packaging, secure credential storage and [audio ownership](../cache-lifecycle.md) remain. Temporary cleanup stays startup-based, with its existing 24-hour TTL and 512 MiB quota; retained user audio is outside that temporary quota. No background service, tracking, model download, new dependency or audio transcoding was introduced.

Three provider marks remain bundled PNG assets, totaling 97,208 bytes. They are not WebP; the broader checklist observation remains separate from the website-specific image rule. There is no runtime image network request or measured native image bottleneck justifying conversion.

No supported Android device was available. Device profile/release startup, raster/UI timings, retained heap, slow-editor/socket stress, battery, real recording and native permission/content-provider flows remain unmeasured. Native unit tests and compiled instrumented tests do not prove device behavior. No live cloud API, production record, credential, field telemetry or billing usage was accessed. Lighthouse/React/Next.js/Vercel checks do not apply to this native target.
