# Repository Instructions

## Project Scope

Transcriber is a Flutter Android application that records, imports, or receives shared audio and turns it into transcript notes with optional summaries. Transcription and summarization independently use OpenAI or Google Gemini with personal API keys.

The supported toolchain is defined by `.fvmrc`, `pubspec.yaml`, and the Android Gradle configuration. Do not introduce another application platform, state-management system, persistence layer, or provider abstraction unless a current requirement justifies it.

## Architecture

- `lib/core/` contains cross-cutting localization, theme, presentation helpers, and utilities.
- `lib/data/models/` contains application data structures. Models must not depend on UI or state code.
- `lib/data/catalog/` owns supported cloud providers and model defaults.
- `lib/data/database/` owns Drift tables, migrations, and generated database adapters.
- `lib/data/repositories/` owns persisted settings and notes.
- `lib/services/` owns platform, storage, audio, remote-provider, and processing integrations.
- `lib/state/` exposes application state and dependency wiring through Riverpod.
- `lib/ui/` renders state and delegates work to controllers and services.
- `android/` contains the native Android entry points and build configuration.

Dependency direction is `UI -> state -> services/repositories -> models and external integrations`. Keep provider-specific behavior behind `TranscriptionProviderClient`, `SummaryProviderClient`, and `ModelCatalogClient`, transcription behind `TranscriptionService`, and summarization behind `SummarizationService`. Preserve the dedicated share entry point and explicit audio-ownership boundary.

See [`docs/architecture.md`](docs/architecture.md) for entry points, data flows, and integration boundaries.

## Naming and Layout

- Use English, ASCII-compatible technical names and `snake_case.dart` file names.
- Use `UpperCamelCase` for types, `lowerCamelCase` for members, and leading underscores for library-private Dart declarations.
- Keep user-visible German and English copy in the `lib/core/l10n/app_strings_*.dart` catalogs and expose it through `AppStrings`.
- Place tests in the source-parallel `test/` tree and name test files `*_test.dart`.
- Keep scripts under a focused `tool/<domain>/` directory.
- Keep technical Markdown under `docs/` with English `kebab-case` names.

## Quality Boundaries

| Metric | Review threshold | CI limit |
|---|---:|---:|
| Function length | over 50 lines | at most 100 lines |
| File length | over 300 lines | at most 500 lines |
| Cyclomatic complexity | over 15 | at most 20 |
| Cognitive complexity | over 15 | at most 25 |
| Parameters per function | over 4 | at most 6 |
| Nesting depth | over 3 | at most 4 |
| Line coverage | below 85% | at least 85% |
| Statement coverage | below 85% | at least 85% |
| Function coverage | below 85% | at least 85% |
| Branch coverage | below 80% | at least 80% |

These limits are strict. Do not add baselines, grandfathered violations, broad exclusions, disabled rules, raised thresholds, or empty assertions. Fix violations at their source. A narrow exception requires an evidenced tool limitation or generated source, the smallest possible scope, and durable justification in `docs/code-quality.md`.

## Required Quality Tooling

Run the checks documented in [`docs/code-quality.md`](docs/code-quality.md). Pull-request CI selects the applicable gates below from the complete merge-base-to-PR-head diff, including deletions, both rename endpoints, transitive consumers, changed tests, and explicit runtime contracts:

- locked dependency resolution;
- Dart formatting and `flutter analyze --fatal-infos`;
- function size, file size, cyclomatic complexity, cognitive complexity, parameter count, and nesting depth;
- Detekt metrics, formatting, and unused-private-code checks for maintained Kotlin;
- ESLint correctness, formatting, unused-code and size/complexity limits for maintained Node tooling, with locked development dependencies and jscpd at 50 tokens and at most 5% duplication;
- unused Dart declarations and files as the Dart equivalent of `knip`;
- tests with strict line, statement, function, and branch coverage thresholds;
- `jscpd` for Dart with `minTokens: 50` and zero accepted duplication;
- workflow syntax and embedded shell checks with pinned `actionlint`;
- OSV dependency vulnerability scanning;
- a Flutter asset-bundle build and artifact existence check;
- the existing gitleaks workflow for secret scanning.

Apply the mappings and conservative fallbacks in [`docs/ci-test-selection.md`](docs/ci-test-selection.md). Global CI, dependency, framework, security, or test-setup changes and empty, unknown, or unreliable impact require full checks. Pure changes under root `docs/` may skip application checks while receiving a real successful final `CI` check. Every other PR retains a fresh dependency audit; gitleaks and PR-title validation remain required. Keep inexpensive Dart gates repository-wide when Dart checks apply, and preserve every selected gate's thresholds. The final `CI` check must validate the complete plan and reject failed, cancelled, missing, or unexpectedly skipped work.

Commit `pubspec.lock` and update it only through Flutter or Dart package-manager commands. GitHub Actions and downloaded security tools must remain version-pinned. Do not weaken release signing or checksum verification.

## Testing Requirements

- Add deterministic tests for every relevant behavior change.
- Cover normal, boundary, failure, and security-sensitive misuse paths.
- Test pure domain and formatting logic without platform services.
- Mock network, filesystem, secure-storage, model, and platform integrations only at explicit boundaries.
- Use integration or device-level checks for Android share intents, permissions, recording, provider requests, and release signing when unit tests cannot represent the behavior.
- Do not use fixed sleeps, order-dependent state, real provider requests, or production credentials in tests.

## Security and Privacy

- Treat shared URIs, filenames, audio files, model output, provider responses, and stored JSON as untrusted input.
- Never place API keys, signing material, or personal transcript data in source, logs, tests, documentation, or error output.
- Keep long-lived credentials in `FlutterSecureStorage`. Document and minimize any transient handoff to background processing.
- Make provider processing boundaries visible to users. Cloud ASR sends audio; cloud summarization sends transcript text.
- Validate URI, path, response shape, and resource-size assumptions at the responsible boundary.
- Preserve least privilege in Android permissions, exported components, GitHub Actions permissions, and release environments.
- Use established cryptography and platform signing. Do not implement custom cryptography.

See [`docs/security.md`](docs/security.md) for trust boundaries and current residual risks.

## Performance and Resources

- Keep recording and UI work off expensive synchronous paths.
- Stream large provider uploads where supported and keep network calls bounded.
- Bound uploads, response bodies, request timeouts, retries, file sizes, memory use, and retained audio.
- Avoid repeated model initialization, unnecessary rebuilds, duplicate storage reads, and unbounded collections.
- Preserve the arm64-only packaging decision unless supported platforms change.

## Documentation Rules

- Keep README concise and link to durable detail under `docs/`.
- Update documentation with behavior, architecture, configuration, security, CI, or operations changes.
- Record durable non-obvious decisions as ADRs under `docs/decisions/` only when a real decision needs preservation.
- Keep this Documentation Index complete, sorted, and free of stale links whenever Markdown below `docs/` changes.

## Documentation Index

| Document | Purpose |
|---|---|
| [`docs/architecture.md`](docs/architecture.md) | Describes application layers, entry points, processing flows, and integration boundaries. |
| [`docs/cache-lifecycle.md`](docs/cache-lifecycle.md) | Defines audio ownership, managed directories, cleanup, TTL, and quota behavior. |
| [`docs/ci-test-selection.md`](docs/ci-test-selection.md) | Explains impacted-test selection, conservative fallbacks, runner reuse, and measured CI timings. |
| [`docs/code-quality.md`](docs/code-quality.md) | Defines strict quality gates, commands, Flutter coverage mappings, and CI behavior. |
| [`docs/configuration.md`](docs/configuration.md) | Documents supported toolchains, runtime settings, external services, and secret handling. |
| [`docs/decisions/bounded-native-recording.md`](docs/decisions/bounded-native-recording.md) | Explains native WAV byte limits, capture ownership, and lifecycle synchronization. |
| [`docs/decisions/cloud-byok-and-drift.md`](docs/decisions/cloud-byok-and-drift.md) | Records the cloud-only BYOK and Drift persistence decision. |
| [`docs/operations.md`](docs/operations.md) | Provides local development, validation, build, and release operating procedures. |
| [`docs/provider-setup.md`](docs/provider-setup.md) | Explains how to create and safely configure OpenAI and Gemini API keys. |
| [`docs/security.md`](docs/security.md) | Describes protected assets, trust boundaries, controls, assumptions, and residual risks. |
