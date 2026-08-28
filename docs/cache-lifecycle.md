# Audio Cache Lifecycle

## Ownership

Every processing input has one ownership value:

| Ownership | Meaning | Deletion policy |
|---|---|---|
| `external` | Original file outside managed storage | Never delete |
| `temporary` | App-owned import, share, or recording working copy | TTL, quota, cancel, error, or successful processing |
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

Imports are copied before navigation. Recordings are written directly to the recording cache. Android share streams are copied with a byte limit and partial-file cleanup. On successful processing, the working copy is either moved by copy-and-delete into retained storage or discarded, depending on the audio retention setting.

Cancellation and abandoned share previews delete only app-owned temporary or retained data. Provider or processing errors preserve the temporary copy for retry until the user abandons the run or normal startup cleanup expires it. Startup cleanup removes expired and over-quota temporary files.
