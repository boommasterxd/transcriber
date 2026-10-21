# Security and Privacy

## Protected Assets

- personal OpenAI and Gemini API keys
- audio recordings and imported/share working copies
- transcripts, summaries, points, and to-dos
- provider and model provenance
- the Drift database and Android signing material

## Trust Boundaries

External URIs, filenames, audio bytes, provider responses, legacy JSON, editor metadata, and model output are untrusted. OpenAI and Google are external processors. Selecting different providers for transcription and summary creates two distinct data transfers: audio goes to the transcription provider, while transcript text goes to the summary provider. Live keyboard dictation adds an Android editor boundary and sends microphone PCM to the selected live transcription provider while recording is active.

## Credentials

Keys are stored only in `FlutterSecureStorage`. They are sent in request headers, never query parameters. Configured API endpoints use HTTPS; the provider-supplied Gemini upload URL has the separate trust boundary described under [network controls](#network-and-resource-controls). Drift and SharedPreferences do not store active keys. Validation happens before persistence, replacement preserves the previous key on failure, and UI errors never interpolate provider keys.

Live WebSocket handshakes authenticate through headers. The Dart controller releases the key-bearing configuration when a session ends. Keys are not placed in WebSocket URLs, events, logs, or editor content.

Provider response bodies are bounded and error messages are normalized, whitespace-limited, truncated, and redacted. The application does not log request headers, credentials, transcript bodies, or raw provider responses.

Failed summaries retain a diagnostic alongside the transcript in the note database. Before persistence, diagnostics remove both stages' API keys and credential-shaped fields, normalize whitespace, and limit detail to 512 characters plus a truncation marker. Only user-facing service messages are retained; unexpected exceptions use a generic message without exception contents. Diagnostics are rendered as selectable plain text and are removed with the note. Provider messages may still contain personal information and receive the same local protection as transcripts.

### Historical Scanner Exceptions

On 2026-10-19, the project owner confirmed that the historical Google keys detected in `app/google-services.json` are no longer usable. This is an owner confirmation, not an independent provider-authentication check. No key values are reproduced or tested against a provider.

[`.gitleaksignore`](../.gitleaksignore) contains exactly three fingerprints, each bound to the complete immutable commit ID, path, `gcp-api-key` rule and line 18. These exceptions apply only to those historical findings. Default detectors still cover every path, including tests and Firebase configuration; later commits, other locations and current files receive no exemption. Do not replace these entries with path, rule or credential-pattern allowlists. Reassess them if the confirmation changes or scanner fingerprint semantics change.

The checksum-verified Gitleaks 8.30.1 history and current-tree scans pass with these exceptions. Scanner regressions verify that an exact historical fingerprint can be ignored while the same synthetic credential in a later commit still fails. See [code quality](code-quality.md#ci-jobs) for scanner commands and coverage.

### Repository Security Controls

GitHub repository secret scanning and push protection are enabled. Public fork workflows require maintainer approval for all external contributors; approval does not grant secrets or write permissions to untrusted code. The required Gitleaks workflow remains a separate tree/history control.

External pull requests are accepted. Before approving an external workflow run and before merging, maintainers must review changes to workflows, classifiers, scanner download manifests/checksums, detector configuration and exclusions. The scanner reads those controls from the PR checkout: a matching archive checksum or green check alone does not establish that the supplied scanning policy is trusted. Keep this targeted control review separate from the zero-required-reviews ruleset.

The repository-owned CodeQL workflow prepares the pinned Flutter/Android environment and explicitly compiles Kotlin for analysis, alongside JavaScript and GitHub Actions. It replaces default setup, whose Kotlin autobuild could not create the required `android/local.properties`. Keep one active configuration. The PR's matching analysis results establish hosted extraction; local compilation alone does not.

## Files and Cache

External originals are never deleted. Destructive operations require explicit app ownership and a path inside a known app-private directory. Share filenames are sanitized, stream copies are limited to 250 MiB, symlinks are not followed during cleanup, and partial copies are removed after failures.

Temporary import, share, and recording files use a 24-hour TTL and a combined 512 MiB quota. Active files are protected from cleanup. Retained note audio is outside the temporary quota and is deleted only with the owning note or explicit audio deletion.
Retained audio queued by note removal survives a process exit during the undo window. Ordinary app startup retries only these recorded candidates after checking current note references and storage ownership; share previews that have not been saved are not swept.

## Database

Drift uses typed tables and transactions. Queries are generated and parameterized. Foreign-key enforcement is enabled before normal queries, rejecting child records without a note and cascading parent deletion. Notes and transcripts are not application-level encrypted, so device compromise, privileged debugging, or backup behavior may expose them. This residual risk must remain visible in release privacy review.

Schema upgrades commit their changes and version marker atomically; the title-search upgrade can resume from a partially applied older attempt. Legacy SharedPreferences migration commits the marker and imported data atomically. Source values are removed only after a successful commit. Malformed source values are retained rather than silently destroyed.

## Network and Resource Controls

- configured API endpoints use fixed OpenAI and Google HTTPS origins; Gemini resumable uploads additionally use the provider-supplied URL described below;
- request timeouts prevent indefinite hangs;
- request deadlines abort supported HTTP transports and cancel response consumption; internally owned clients are closed after every operation;
- response size is capped;
- audio size and extension are validated before upload;
- Gemini Files uploads are streamed and deleted remotely in `finally` cleanup;
- Gemini transcription Interactions set `store: false` because the app does not resume them; the separate Files resource is still deleted in `finally`;
- Gemini polling is bounded;
- provider output is parsed defensively before it reaches application state.

The Gemini Files client takes the resumable upload URL from the provider's `x-goog-upload-url` response header and sends the API key in a header to that URL. It checks that the URL is nonempty but does not independently restrict its scheme or origin. This path trusts the provider's response; it does not enforce a fixed HTTPS-origin allowlist. See [the upload implementation](../lib/services/remote/google_client.dart).

The application does not pin TLS certificates. HTTPS connections rely on Android's platform trust store.

## Android

The main activity is exported for the launcher. Audio `VIEW` and share filters target the translucent `ShareActivity`; explicit media intents addressed to `MainActivity` are hidden from Flutter plugins and forwarded to the share activity. The share activity validates schemes and MIME type, sanitizes names, bounds copies, and stores data in application cache before processing.

Dedicated share imports run outside the main thread with a 60-second readiness deadline and lifecycle cancellation. One process-wide import slot and a bounded cleanup executor prevent repeated stalled providers from creating unbounded workers. Cancellation signals, descriptor/stream closure, and partial-file deletion are best effort when an external provider does not cooperate.

The exported input-method service is protected by Android's `BIND_INPUT_METHOD` permission, so ordinary applications cannot bind to it. It records only while its keyboard window is visible and a current supported editor is active. Password variations, numeric PINs, non-text editors, and editors that prohibit personalized learning are rejected before recording. Every editor transition invalidates the previous session; late audio, provider events, and text mutations are discarded. Partial text uses composing spans and finalized text uses `commitText`. The service never requests surrounding editor text.

Keyboard audio remains in memory and is never written to application storage. Stopping, cancelling, hiding the keyboard, changing editor, unbinding the input connection, losing the active session, or destroying the service stops `AudioRecord`, closes the WebSocket, and clears queued audio. Session-checked stop calls prevent stale Flutter cleanup from stopping a newer recording. No foreground service is used because background dictation is intentionally prohibited. A hard process termination has no guaranteed lifecycle callback; Android reclaims native resources and the provider connection expires without preserving the active dictation session.

Live provider frames are limited to 5 MiB before JSON decoding. Invalid JSON or event fields terminate the session through a controlled error path. Provider partials and item IDs, the complete session transcript, and pending editor composition updates are bounded; newer composition text replaces an older waiting update. Final editor writes still complete in order.

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

Do not claim complete confidentiality or correctness. Release review must verify the actual provider terms, privacy disclosures, Android behavior, and data flows.
