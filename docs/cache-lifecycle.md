# Audio Cache Lifecycle

## Ownership

Every processing input has one ownership value:

| Ownership | Meaning | Deletion policy |
|---|---|---|
| `external` | Original file outside managed storage | Never delete |
| `temporary` | App-owned import, share, or recording working copy | TTL, quota, explicit cancellation/discard, or successful processing; processing errors preserve the copy for retry |
| `retained` | App-owned audio attached to a saved note | Delete with the note or explicit audio deletion |

## Directories

- temporary imports: cache `audio/import`
- Android share copies: cache `shared`
- recordings: cache `audio/recording`
- retained note audio: application support `audio/retained`

Paths are created through `StoragePaths`. Ownership checks resolve filesystem aliases before comparing a file with its managed root. This accepts Android aliases such as `/data/data` and `/data/user/0` for the same app-private cache without broadening the allowed directories. Cleanup refuses paths outside the directory implied by ownership.

## Limits

- maximum input: 250 MiB
- temporary TTL: 24 hours
- combined temporary quota: 512 MiB
- quota eviction: least recently modified first

Empty files, unsupported extensions, traversal outside managed roots, and symlink entries are rejected or ignored. Files marked active by the processing pipeline are excluded from cleanup.

## Lifecycle

Imports are copied before navigation. Recordings are written directly to the recording cache. Android share and open-file streams are copied with a byte limit and partial-file cleanup. On successful processing, the working copy is either moved by copy-and-delete into retained storage or discarded, depending on the audio retention setting.

The dedicated Android share activity copies on a bounded background worker. Path handoff waits asynchronously for completion, with a 60-second deadline and lifecycle cancellation. Before handoff, cancellation owns descriptor/stream closure and partial-file deletion; after handoff, the existing Dart ownership rules apply. An uncooperative provider may retain the single process-wide worker slot, but cannot accumulate workers.

Cancellation and abandoned share previews delete only app-owned temporary or retained data. Provider or processing errors preserve the temporary copy for retry until the user abandons the run or normal startup cleanup expires it. Startup cleanup removes expired and over-quota temporary files.

Deleting a note records its retained-audio path as a pending deletion in the same database transaction. Undo restores the note and clears that candidate. When the undo window closes, the app checks for another note reference and attempts ownership-checked deletion. Normal app startup retries at most 128 queued candidates in insertion order. Unsuccessful attempts move to the end of the queue so they cannot indefinitely block later candidates. The share entry point skips this recovery, and cleanup never sweeps unrelated retained files, which may belong to an unsaved share preview.

A failed note save also retains the completed result and retained audio for retry. Abandoning a run during persistence removes that audio if the save fails, while a successful save preserves the note's ownership. Share dismissal waits for an in-flight commit: committed audio remains owned by the saved note, while a failed commit leaves it eligible for preview cleanup. Repeated commit requests share one operation.
