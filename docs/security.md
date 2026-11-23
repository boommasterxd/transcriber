# Security and Privacy

## Protected Assets

- personal OpenAI and Gemini API keys
- audio recordings and imported/share working copies
- transcripts, summaries, points, and to-dos
- provider and model provenance
- the Drift database and Android signing material

## Trust Boundaries

External URIs, filenames, audio bytes, provider responses, legacy JSON, editor metadata, and model output are untrusted. OpenAI and Google are external API providers selected through the user's own account. Their privacy roles depend on the applicable terms and account. For batch processing, audio goes to the selected transcription provider, and optional transcript text goes to the selected summary provider. Live keyboard dictation adds an Android editor boundary and sends microphone PCM to the selected live transcription provider while recording is active.

## Credentials

Keys are stored only in `FlutterSecureStorage` and authenticate requests in headers. Configured API endpoints use HTTPS. The provider-supplied Gemini upload URL has a separate validation boundary. Validation happens before persistence, and replacement preserves the previous key on failure. See [network controls](#network-and-resource-controls).

Live WebSocket handshakes authenticate through headers. The Dart controller releases the key-bearing configuration when a session ends. Keys are not placed in WebSocket URLs, events, logs, or editor content.

Provider response bodies are bounded and error messages are normalized, whitespace-limited, truncated, and redacted. The application does not log request headers, credentials, transcript bodies, or raw provider responses.

Failed summaries retain a diagnostic alongside the transcript in the note database. Before persistence, diagnostics remove both stages' API keys and credential-shaped fields, normalize whitespace, and limit detail to 512 characters plus a truncation marker. Only user-facing service messages are retained; unexpected exceptions use a generic message without exception contents. Diagnostics are rendered as selectable plain text and are removed with the note. Provider messages may still contain personal information and receive the same local protection as transcripts.

### Historical Scanner Exceptions

The historical exceptions for Google keys detected in `app/google-services.json` rely on the project owner's confirmation that the keys are no longer usable.

[`.gitleaksignore`](../.gitleaksignore) contains exactly three fingerprints, each bound to the complete immutable commit ID, path, `gcp-api-key` rule and line 18. These exceptions apply only to those historical findings. Default detectors still cover every path, including tests and Firebase configuration; later commits, other locations and current files receive no exemption. Do not replace these entries with path, rule or credential-pattern allowlists. Reassess them if the confirmation changes or scanner fingerprint semantics change.

The pinned Gitleaks release scans history and the current tree with these exceptions. Pull requests use the manifest, scanner policy, fingerprints, and regression suite from their exact base commit. Inline suppression comments are disabled. Scanner regressions check that the exact historical fingerprint is ignored and that the same synthetic credential in a later commit still fails. See [code quality](code-quality.md#ci-jobs) for scanner commands and coverage.

### Repository Security Controls

GitHub repository secret scanning and push protection are enabled. Public fork workflows require maintainer approval for all external contributors; approval does not grant secrets or write permissions to untrusted code. The required Gitleaks workflow remains a separate tree/history control.

External pull requests are accepted. Before approving an external workflow run and before merging, maintainers must review changes to workflows, classifiers, scanner download manifests/checksums, detector configuration and exclusions. The scanner reads those controls from the PR checkout: a matching archive checksum or green check alone does not establish that the supplied scanning policy is trusted. Keep this targeted control review separate from the zero-required-reviews ruleset.

The repository-owned CodeQL workflow prepares the pinned Flutter/Android environment and explicitly compiles Kotlin for analysis, alongside JavaScript and GitHub Actions. It replaces default setup, whose Kotlin autobuild could not create the required `android/local.properties`. Keep one active configuration. The PR's matching analysis results establish hosted extraction; local compilation alone does not.

## Files and Cache

External originals are never deleted. Destructive operations require explicit app ownership and a path inside a known app-private directory. Share filenames are sanitized, stream copies are limited to 250 MiB, symlinks are not followed during cleanup, and partial copies are removed after failures.

Temporary picker, share and recording copies expire after 24 hours and have a combined 512 MiB quota enforced by the normal app. Retention stages expire under the same TTL. Each engine protects its active paths. Deleting a note queues its retained audio, and startup retries recorded candidates after checking current note references and storage ownership. The same queue tracks unreferenced promotion destinations after save failures or process death. Unsaved share previews keep temporary audio. See [audio lifecycle](cache-lifecycle.md).

## Database

Drift uses typed tables and transactions. Queries are parameterized. Foreign-key enforcement is enabled before normal queries, rejecting child records without a note and cascading parent deletion. Notes and transcripts are stored in SQLite without app-level encryption. Privileged debugging or a compromised device can expose that content.

Schema upgrades commit their changes and version marker atomically. An older partially applied title-search upgrade can resume safely. The current title index uses FTS5 secure deletion when supported. Legacy migration removes valid source values after commit and retains only rejected entries from mixed note lists in the private recovery preference. Unreadable or wholly rejected note values remain at their original key. Failed writes or removals can leave the original temporarily in place until a later startup retries cleanup. Database failures exposed to callers omit SQL details and bound values. See [persistence architecture](architecture.md#persistence).

## Network and Resource Controls

- configured API endpoints use fixed OpenAI and Google HTTPS origins; Gemini resumable uploads additionally use the provider-supplied URL described below;
- request timeouts prevent indefinite hangs;
- deadlines and local user cancellation abort supported HTTP transports and cancel response consumption;
- response size is capped;
- audio size and extension are validated before upload, and remote file names use neutral labels;
- Gemini Files uploads are streamed, with a bounded best-effort deletion request for a known uploaded file;
- Gemini transcription Interactions set `store: false`;
- Gemini file polling uses one deadline across wait and status requests;
- provider output is parsed defensively before it reaches application state.

The Gemini Files client validates the resumable URL from `x-goog-upload-url` before reading the audio stream. The URL must use HTTPS at the configured Gemini host on port 443, with no user information or fragment. It may contain the opaque upload identifier. Credential query fields and the API key itself are rejected, and redirects are disabled. The initial request authenticates in a header. The subsequent upload uses the validated session URL. See [the upload implementation](../lib/services/remote/google_client.dart) and [URL validation](../lib/services/remote/gemini_upload_uri.dart).

The application does not pin TLS certificates. HTTPS connections rely on Android's platform trust store.

## Android

The Android manifest disables backup and supplies explicit exclusion rules for owned storage, including app files, databases and preferences. The legacy rules cover Auto Backup. The Android 12 and newer rules cover cloud backup and device transfer. These rules apply to current app data. Existing exported copies and backups from earlier versions have their own lifecycles.

The transcript copy action marks the Android clipboard item as sensitive so supported systems can hide its text in the clipboard preview. The contents still go to the system clipboard. Pasting or sharing transfers the contents to the chosen destination, where that application's handling applies.

The main activity is exported for the launcher. Audio `VIEW` and share filters target the translucent `ShareActivity`; explicit media intents addressed to `MainActivity` are hidden from Flutter plugins and forwarded to the share activity. The share activity validates schemes and MIME type, sanitizes names, bounds copies, and stores data in application cache before processing.

Document-picker and share imports use one background slot and a 60-second readiness deadline. Before native content reads, Android must grant temporary access and resolve the URI to a foreign provider. A bounded cleanup executor handles lifecycle cancellation, stream closure and partial-file deletion on a best-effort basis. An external provider that ignores cancellation can hold the slot until its I/O returns.

The exported input-method service is protected by Android's `BIND_INPUT_METHOD` permission. It records only while its keyboard window is visible and a supported editor is active. Password variations, numeric PINs, non-text editors, and editors that prohibit personalized learning are rejected before recording. Each editor transition invalidates the previous session and discards late events. The service writes composing spans and commits the final text through `commitText`. It clears its previous composition when Android confirms the candidate span and cursor position. Some editors omit or delay these callbacks, which can leave draft text in the editor. The service does not request surrounding text.

Keyboard audio remains in memory and is never written to application storage. Stopping, cancelling, hiding the keyboard, changing editor, unbinding the input connection, losing the active session, or destroying the service stops `AudioRecord`, closes the WebSocket, and clears queued audio. Session-checked stop calls prevent stale Flutter cleanup from stopping a newer recording. No foreground service is used because background dictation is intentionally prohibited. A hard process termination has no guaranteed lifecycle callback; Android reclaims native resources and the provider connection expires without preserving the active dictation session.

Live WebSocket payloads are limited to 5 MiB before JSON decoding, with compression disabled and a separate transport read budget. Invalid JSON or event fields terminate the session through a controlled error path. Native PCM handoff, provider partials and item IDs, the complete transcript and pending composition updates are bounded. Newer composing text replaces an older waiting update, while final writes complete in order.

## Residual Risks

- provider retention, regional processing, billing, quotas, and account controls remain governed by each provider;
- transcription and summary output may be inaccurate or maliciously structured;
- a rooted or otherwise compromised device can bypass application storage protections;
- device-level secure-storage and share-intent verification cannot be fully represented by unit tests;
- third-party editor implementations can vary in their `InputConnection` and composing-text behavior, so release testing must cover supported Samsung and Pixel applications;
- direct mobile BYOK exposes provider credentials to the application process during an active request even though storage and transport avoid plaintext URLs;
- active cloud processing is not guaranteed to survive Android process suspension or termination because no foreground service is retained;
- deleting a Gemini Files resource is best-effort if the cleanup request itself cannot reach Google;
- an external content provider that ignores cancellation can keep the bounded import slot occupied until its I/O returns; no forced thread termination is attempted;
- custom injected HTTP transports must support abortable requests to terminate their own I/O, although response consumption is cancelled independently.
- a cancelled live connection can occupy the sole handshake slot while the platform's native TLS attempt settles. The editor session and microphone can release independently.

Do not claim complete confidentiality or correctness. Release review must verify the actual provider terms, privacy disclosures, Android behavior, and data flows.
