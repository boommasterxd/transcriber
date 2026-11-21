# Audio Cache Lifecycle

## Ownership

Every processing input has one ownership value:

| Ownership | Meaning | Deletion policy |
|---|---|---|
| `external` | Original file outside managed storage | Never delete |
| `temporary` | App-owned import, share, or recording working copy | TTL, quota, explicit cancellation/discard, or successful processing; processing errors preserve the copy for retry |
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

Empty files, unsupported extensions, traversal outside managed roots, and symlink entries are rejected or ignored. Each engine excludes its active paths from cleanup. Staging has a per-file size limit and uses the same TTL.

## Lifecycle

Recordings use the recording cache. The Android document picker and share flow stream each file to the shared import cache before processing. Dart validates and registers the existing copy. An unsaved share result keeps its input in temporary storage and can play it when audio retention is enabled. When a note is saved, the working copy is either retained with the note or deleted under the audio retention setting.

The Android picker and the share activity use the same bounded background worker. Path handoff waits asynchronously with a 60-second deadline after file selection or share import start. Before handoff, native cancellation closes descriptors and streams and deletes partial files on a best-effort basis. After handoff, Dart owns the working copy and discards it on cancellation. An uncooperative provider may occupy the single process-wide worker slot until its I/O returns.

Cancellation and abandoned share previews discard the app-owned working copy. Provider or processing errors preserve it for retry until the user abandons the run or expiration removes it. After rendering its first frame, the normal app expires temporary files and enforces the cache quota. Share startup only applies expiration. This avoids quota pressure from a new share operation evicting fresh files used in the other engine.

Deleting a note records its retained-audio path as a pending deletion in the same database transaction. Undo restores the note and clears that candidate. When the undo window closes, the app checks for another note reference and attempts ownership-checked deletion. Normal app startup retries at most 128 queued candidates in insertion order. Unsuccessful attempts move to the end of the queue so they cannot indefinitely block later candidates. The share entry point skips this recovery, and cleanup never sweeps unrelated retained files, which may belong to an unsaved share preview.

Retained audio is prepared as a bounded temporary copy. The repository records its destination in the durable deletion queue before a guarded rename promotes the file to retained storage. A successful note transaction claims that destination and the app discards the source working copy. If persistence fails, the result and source remain available for retry without another provider request. Startup can reclaim an unreferenced promoted file from the queue and expire abandoned stages and partial files. Share dismissal waits for an in-flight commit, and repeated commit requests share one operation.
