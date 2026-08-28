# Operations

## Prerequisites

- Flutter 3.47.1 from `.fvmrc`
- Android SDK with compile SDK 37
- Java 17
- Android NDK 28.2.13676358 for APK builds
- Node.js 24 only for the pinned `jscpd` duplication check
- A physical `arm64-v8a` Android device for recording, share intents, foreground processing, and local model execution

The package lower bounds permit older compatible Flutter versions, but project validation and CI use the pinned version.

## Initial Setup

Resolve the committed dependency graph:

```bash
flutter pub get --enforce-lockfile
```

Flutter generates `android/local.properties` with the local SDK path. This file is machine-specific and must not be committed.

Run the application on a connected device:

```bash
flutter run
```

The first local model execution requires model downloads that may consume several gigabytes. Provider-backed processing additionally requires the relevant API key configured inside the application.

## Validation

Run the complete local quality suite from [`docs/code-quality.md`](code-quality.md). The core application checks are:

```bash
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --fatal-infos
flutter test --coverage --branch-coverage
dart run tool/quality/check_coverage.dart coverage/lcov.info
```

Existing code-quality violations are intentionally not suppressed. A failed gate is actionable remediation work, not an infrastructure failure, unless the checker itself crashes or mismeasures a verified source construct.

## Build

Build a local release APK:

```bash
flutter build apk --release
```

The APK contains only `arm64-v8a`. Large FFmpeg and local-model native libraries make Android builds disk-intensive.

Pull-request CI builds a Flutter asset bundle as a fast package-integrity check:

```bash
flutter build bundle --debug
test -d build/flutter_assets
```

The dedicated APK workflows preinstall required NDK versions and reclaim hosted-runner disk space before the full Android build.

## CI Workflows

- `.github/workflows/ci.yml` runs workflow and shell linting, Dart and Kotlin quality checks, tests, coverage, dead-code detection, duplication detection, and a bundle build.
- `.github/workflows/dependency-audit.yml` scans `pubspec.lock` for known vulnerabilities.
- `.github/workflows/gitleaks.yml` scans the repository for committed secrets.
- `.github/workflows/build-apk.yml` produces a short-lived APK artifact for explicit build runs.
- `.github/workflows/release.yml` builds, verifies, checksums, and publishes release APKs.
- `.github/workflows/commit-style-check.yml` enforces Conventional Commit-style pull-request titles.
- Dependabot covers Pub, Gradle, and GitHub Actions updates.

## Release Signing

CI creates `android/key.properties` and the upload keystore from these repository secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_KEY_ALIAS`

The Android build falls back to debug signing when secrets are absent, but release and build workflows verify the certificate and fail before publishing a debug-signed artifact. Never print signing values or commit generated signing files.

## Release Procedure

Push a version tag matching `v*`, or manually dispatch the release workflow with a version. The workflow:

1. resolves and stamps the application version;
2. builds the release APK;
3. verifies that the APK is not debug-signed;
4. renames the artifact with the version;
5. generates `SHA256SUMS`;
6. publishes a GitHub Release;
7. removes the temporary workflow artifact after publication.

Release publication is protected by the `release` environment.

## Failure Recovery

- Dependency resolution failure: verify that `pubspec.yaml`, `pubspec.lock`, and the pinned Flutter SDK agree. Regenerate the lockfile only with `flutter pub get` or an intentional package-manager update.
- NDK download failure: use the versions pinned in the Android build files and the retry logic in the APK workflows.
- Missing local model: open application settings and complete the model download before processing.
- Missing provider key: configure the key in application settings. Do not use environment variables or source constants as a replacement.
- Foreground-service failure: verify Android notification permission, foreground-service declarations, and device logs.
- Release signature failure: verify the repository secrets and keystore alias. Do not bypass the signature check.
- Quality-gate failure: fix the reported source or tests. Do not add a baseline, exclusion, or threshold increase.

## Cleanup

Build output, coverage output, local Flutter SDK caches, machine-specific Android properties, and signing material are ignored. Use standard Flutter and Gradle clean commands when local caches are suspected, and verify the explicit target before deleting any additional files.
