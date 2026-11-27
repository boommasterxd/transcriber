# Audio Cache Lifecycle

## Ownership

Every processing input has one ownership value:

| Ownership | Meaning | Deletion policy |
|---|---|---|
| `external` | Original file outside managed storage | Never delete |
| `temporary` | App-owned import, share, or recording working copy | Explicit discard or successful save makes the copy eligible for removal. The engine lease protects working copies kept for retry. Unleased files are eligible for expiration and quota eviction. |
| `retained` | App-owned audio attached to a saved note | The note deletion flow queues the audio for removal when undo closes |

## Directories

- Android document-picker and share copies: cache `shared`
- temporary path imports and legacy working copies: cache `audio/import`
- recordings: cache `audio/recording`
- staged retention copies: cache `audio/retention-staging`
- retained note audio: application support `audio/retained`

Paths are created through `StoragePaths`. Ownership checks resolve filesystem aliases before comparing a file with its managed root. This accepts Android aliases such as `/data/data` and `/data/user/0` for the same app-private cache without broadening the allowed directories. Cleanup refuses paths outside the directory implied by ownership.

## Limits

- maximum input: 250 MiB
- temporary TTL: 24 hours
- combined picker, share, path import and recording quota: 512 MiB
- quota eviction: least recently modified first

Android reserves space before writing a picker copy, share copy, or recording. The process-wide quota counts managed files and outstanding write reservations across engines. A recording reserves its full capture budget. An import with a declared length reserves that amount. An import of unknown length receives up to the available budget and must fit within its reservation. To make room, the quota evicts eligible unleased files, oldest modification first. A write fails if it cannot reserve the required space.

Engine-scoped leases protect in-progress writes and finished working copies, including those kept for processing retry or preview. Before Dart accepts a temporary file, the native cache checks that it belongs to that engine and its write has completed. Explicit discard releases the lease after removal. Failed discards can be retried on a later cache scan. Finished leases abandoned or left behind by a closed engine become eligible for cleanup. Expiration is checked during cleanup or reservation according to file modification time.

Empty files, unsupported extensions, traversal outside managed roots, and symlink entries are rejected or ignored. Retention staging is outside the shared reservation budget. Staged copies have a per-file limit and are eligible for expiration after 24 hours. Retained note audio is stored outside the temporary cache.

## Lifecycle

Recordings use the recording cache. The Android document picker and share flow stream each file to the shared import cache before processing. Dart validates and registers the existing copy. An unsaved share result keeps its input in temporary storage and can play it when audio retention is enabled. Audio retention is enabled by default. The processing run uses its approved settings snapshot to decide whether to promote a copy to retained storage. After a successful save, the app discards the temporary input.

The Android picker and the share activity use the same bounded background worker. Path handoff waits asynchronously with a 60-second deadline after file selection or share import start. Before handoff, native cancellation closes descriptors and streams and deletes partial files on a best-effort basis. After handoff, Dart owns the working copy and discards it on cancellation. An uncooperative provider may occupy the single process-wide worker slot until its I/O returns.

Cancellation and abandoned share previews discard their app-owned working copy. A processing failure can keep the copy for retry while the lease remains active. On startup, both flows attempt expiration of eligible files, and the normal app also reclaims eligible files above the quota. Later reservations enforce the budget in both flows.

Deleting a note records its retained-audio path as a pending deletion in the same database transaction. For undoable deletions, that transaction also captures the current note and its children. Undo restores that snapshot and clears the candidate. Recovery skips paths protected by an active undo or retry. Once the user lets undo expire or dismisses a failed restore, the app checks for another note reference and attempts ownership-checked deletion. Normal app startup retries at most 128 queued candidates in insertion order. Unsuccessful attempts move to the end of the queue so they cannot indefinitely block later candidates. The share entry point skips this recovery, and cleanup never sweeps unrelated retained files, which may belong to an unsaved share preview.

Retained audio is prepared as a bounded temporary copy. The repository records its destination in the durable deletion queue before a guarded rename promotes the file to retained storage. A successful note transaction claims that destination and the app discards the source working copy. If persistence fails, the result and source remain available for retry without another provider request. Startup can reclaim an unreferenced promoted file from the queue and expire abandoned stages and partial files. Share dismissal drains processing before closing its database, and repeated commit requests share one operation.
