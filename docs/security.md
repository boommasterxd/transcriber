# Security

## Protected Assets

- Provider API keys and the Hugging Face token
- Android release-signing material
- Audio recordings and imported or shared audio
- Full transcripts, summaries, key points, and to-do items
- Downloaded model artifacts and application configuration
- Published APKs and release checksums

Transcript content and audio may contain personal or confidential information even when the application has no account system.

## Trust Boundaries

### External audio

Android `VIEW`, `SEND`, and `SEND_MULTIPLE` intents accept content from other applications. URIs, MIME types, display names, sizes, and bytes are untrusted. `ShareActivity` copies received content into application cache before Flutter processes it. Filename sanitization, size limits, multiple-item behavior, cache cleanup, and malformed-content handling require explicit validation at this boundary.

File-picker results and recording paths also cross platform-plugin boundaries. Audio conversion and metadata probing must treat them as untrusted files and bound resource use.

### Local model execution

Whisper and local summarization models execute through third-party native libraries. Model files are downloaded over HTTPS but the repository does not currently enforce independent model checksums or signatures. A compromised download source, dependency, or plugin can affect code execution and generated content.

### Cloud providers

Cloud ASR sends audio to the selected provider. Cloud summarization sends transcript text. Provider responses and live model lists are untrusted inputs. Request timeouts bound network waits, but response-size and schema validation remain important.

Google API keys are currently transmitted as URL query parameters. URL logging outside application control may expose them more readily than header-based credentials.

### Persistence

API keys and the Hugging Face token use `FlutterSecureStorage`. Non-secret settings and full transcript notes use `SharedPreferences`; transcript content is therefore not application-level encrypted. Device compromise, backup behavior, debug access, or another privileged process may expose it.

Foreground processing serializes required credentials and settings through `flutter_foreground_task`. Repository code does not prove the plugin's retention duration or encryption properties.

### Model output

Summary output is untrusted. `SummaryPrompt.parse` attempts to extract a four-field JSON object and otherwise uses trimmed raw text as the gist. Never treat generated text as commands, trusted markup, file paths, provider configuration, or authorization input.

## Controls

- Long-lived credentials use secure storage rather than shared preferences.
- Local and cloud stages are explicit settings, and cloud mode is described in the UI.
- Remote requests use HTTPS endpoints and bounded timeouts.
- Local model work moves to a foreground-service isolate when either processing stage is local.
- Android signing material is injected only at build time and remains ignored locally.
- APK workflows reject debug-signed release artifacts.
- Release artifacts include SHA256 checksums.
- GitHub Actions are commit-SHA pinned.
- Gitleaks scans pull requests and `main` pushes with a pinned, checksum-verified binary.
- OSV Scanner checks the committed Pub lockfile and fails on known dependency vulnerabilities.
- Dependabot proposes Pub, Gradle, and GitHub Actions updates.
- CI runs static analysis, tests, dead-code detection, strict duplication detection, and package-build verification.

## Secret-Scanning Boundaries

`.gitleaks.toml` extends the default rules and currently allowlists test paths and `google-services.json`. The Google client file is treated as a distributable client configuration rather than a secret and must be protected with Google Cloud API restrictions. The broad test-path allowlist can hide realistic leaked credentials and should be narrowed when test fixtures are next changed.

## Required Security Practices

- Never log credentials, transcript bodies, raw audio, signing values, or unnecessary device identifiers.
- Validate external URI schemes, resolved filenames, path containment, content size, and supported audio types before expensive processing.
- Avoid shell construction from user-controlled paths. Use APIs or escaping mechanisms that preserve argument boundaries.
- Validate provider status codes and response types before consuming fields.
- Bound retries, downloads, request bodies, response bodies, model output, stored-note counts, and retained cache files.
- Preserve least-privilege Android permissions and GitHub Actions permissions.
- Do not weaken signing checks, secret scans, dependency scans, or branch protection to make a build pass.
- Re-evaluate data flows and user disclosure whenever a provider, model source, plugin, storage mechanism, or processing mode changes.

## Residual Risks

- `ShareActivity` derives a cache filename from an external display name without an explicit repository-level sanitization helper.
- `SEND_MULTIPLE` currently processes only one URI; the intended user and cleanup behavior is not durably specified.
- FFmpeg command construction requires focused validation for paths containing quotes or other special characters.
- Shared cache files do not have a documented cleanup lifecycle.
- Model downloads have no independent repository-configured integrity verification.
- Transcript notes are not application-level encrypted.
- Foreground-task credential persistence properties are not established by source evidence.
- Google query-parameter credentials may appear in infrastructure logs outside application control.
- The services layer contains a remote-client and transcription-result dependency cycle that complicates boundary review.

These risks are not security guarantees or confirmed vulnerabilities. They are evidence-backed review targets that require focused validation before remediation claims.

## Verification

Run:

```bash
flutter analyze --fatal-infos
flutter test
dart run dart_code_linter:metrics check-unused-code \
  lib test --analyze-private-members
```

CI additionally runs gitleaks, OSV Scanner, quality metrics, duplication detection, coverage checks, and a bundle build. Device-level verification remains required for exported share intents, runtime permissions, foreground-service behavior, secure-storage behavior, local-model execution, and release signing.
