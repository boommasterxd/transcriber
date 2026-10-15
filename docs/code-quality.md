# Code Quality

## Policy

All quality limits are strict. The repository has no legacy baseline, no grandfathered violations, and no accepted duplication percentage. Existing violations intentionally fail CI until the code is corrected.

Review thresholds guide refactoring before CI limits are reached. CI limits are hard failures:

| Metric | Review threshold | CI limit | Implementation |
|---|---:|---:|---|
| Function length | over 50 lines | 100 lines | Dart Code Linter `lines-of-code`; Detekt `LongMethod` |
| File length | over 300 lines | 500 lines | `tool/quality/check_code_quality.dart` for Dart and Kotlin |
| Cyclomatic complexity | over 15 | 20 | Dart Code Linter `cyclomatic-complexity`; Detekt `CyclomaticComplexMethod` |
| Cognitive complexity | over 15 | 25 | Dart analyzer AST traversal; Detekt `CognitiveComplexMethod` |
| Parameters | over 4 | 6 | Dart Code Linter `number-of-parameters`; Detekt `LongParameterList` |
| Nesting depth | over 3 | 4 | Dart Code Linter `maximum-nesting-level`; Detekt `NestedBlockDepth` |
| Line coverage | below 85% | 85% | Flutter LCOV `DA` records |
| Statement coverage | below 85% | 85% | Executable-line proxy from Flutter LCOV `DA` records |
| Function coverage | below 85% | 85% | LCOV `FNDA`, or analyzer-derived function spans mapped to line hits |
| Branch coverage | below 80% | 80% | Flutter LCOV `BRDA` records |

Flutter coverage is line-oriented and currently omits native `FNDA` records. The repository therefore uses executable lines as the statement proxy and maps analyzer-derived Dart function spans to LCOV line hits as the function proxy. The checker enumerates every tracked `lib/**/*.dart` source and fails closed if Flutter omits any source from LCOV. It also fails when a required metric denominator is empty. These mappings must remain documented until Flutter emits independent statement and function coverage.

`analysis_options.yaml` explicitly excludes generated build output and platform roots from Dart analysis. These are language and tool-scope boundaries, not a quality baseline: CI explicitly formats and analyzes maintained Dart code in `lib/`, `test/`, and `tool/`. Maintained Kotlin under `android/app/src/main/kotlin/` is checked separately with Detekt and its formatting rules.

Drift generates `lib/data/database/app_database.g.dart`. The file is checked into source control so builds do not depend on code generation, but it is excluded from direct analyzer, size, complexity, and duplication measurements only when it carries Drift's generated-code header. It remains compiled through `app_database.dart`. Maintained database declarations, queries, repositories, and migrations remain fully subject to every quality gate.

## Local Commands

Resolve the exact locked dependency graph:

```bash
flutter pub get --enforce-lockfile
```

Check formatting and static analysis:

```bash
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --fatal-infos
```

Collect and enforce size and complexity metrics:

```bash
quality_dir="$(mktemp -d)"
dart run dart_code_linter:metrics analyze lib test tool \
  --reporter=json \
  --json-path="$quality_dir/metrics.json" \
  --no-fatal-warnings >/dev/null
dart run tool/quality/check_code_quality.dart \
  --metrics "$quality_dir/metrics.json"
```

Check unused declarations and files:

```bash
dart run dart_code_linter:metrics check-unused-code \
  lib test tool --analyze-private-members
dart run dart_code_linter:metrics check-unused-files lib test tool
```

Check maintained Kotlin with the pinned, checksum-verified Detekt CLI and formatting plugin:

```bash
bash tool/quality/check_kotlin_quality.sh
JAVA_HOME=/path/to/jdk17 android/gradlew -p android \
  :app:testDebugUnitTest :app:compileDebugAndroidTestKotlin
```

Run `:app:connectedDebugAndroidTest` separately on an attached Android device or emulator. CI compiles the maintained instrumented test sources, while device-specific input-method behavior remains part of release verification.

Generate and enforce test coverage:

```bash
flutter test --coverage --branch-coverage
dart run tool/quality/check_coverage.dart coverage/lcov.info
```

Check duplication with the pinned Dart-capable detector:

```bash
npx --yes jscpd@5.0.16 \
  --min-tokens 50 \
  --threshold 0 \
  --reporters console \
  --format dart \
  --ignore "**/*.g.dart" \
  lib test tool
```

Build and verify the Flutter asset bundle:

```bash
flutter build bundle --debug
test -d build/flutter_assets
```

## CI Jobs

All Flutter jobs, including manual APK validation and releases, use `.github/actions/setup-flutter` to read the exact version from `.fvmrc`. It calls the MIT-licensed `flutter-actions/setup-flutter` at commit `6e2468fd827c4a7337cd4b835a6049b78bc0bd1f`, which pins both cache dependencies to full SHAs and verifies downloaded SDK archives against the official Flutter release checksum. SDK and lockfile-keyed package caches remain enabled. This replaces `subosito/flutter-action`, whose internally tagged cache dependency is incompatible with enforced SHA pinning.

`.github/workflows/ci.yml` separates independent checks so one known failure does not hide unrelated categories:

- `Workflow lint` verifies every GitHub Actions workflow with a pinned, checksum-verified `actionlint` binary.
- `Analyze and test` checks the lockfile, formatting, analysis, tests, and coverage.
- `Size and complexity` enforces all source-size and complexity limits.
- `Dead code` checks unused declarations and files.
- `Kotlin quality and tests` enforces the same function, complexity, parameter, nesting, formatting, and unused-private-code boundaries for maintained Kotlin, runs JVM unit tests, and compiles instrumented Android tests.
- `Duplication` rejects every Dart clone of at least 50 tokens.
- `Build bundle` proves that Flutter can assemble the application asset bundle.

`.github/workflows/dependency-audit.yml` scans `pubspec.lock` with the pinned OSV Scanner reusable workflow and fails on known vulnerabilities. CI calls it for full checks; the independent weekly and manual scans remain available. `.github/workflows/gitleaks.yml` scans both the merge working tree and every commit introduced by the PR, including secrets removed before the final tree.

## Protected Pull Requests

Automatic quality checks and secret scanning run on pull requests targeting `main`, using GitHub's simulated merge checkout. They do not run again on the resulting `main` push. The final `CI` check requires all seven quality/build jobs and the dependency audit to succeed. Failed, cancelled, missing or unexpectedly skipped jobs block the final check.

Only a nonempty, complete change set entirely below the root `docs/` directory takes the short path. `tool/ci/detect-change-scope.cjs` compares the merge base with the PR head, includes both sides of renames, and defaults to full CI on uncertainty. Documentation-only changes intentionally skip all expensive jobs and still receive a real successful `CI` result. Root Markdown, workflows, tooling and mixed changes run full CI. Secret scanning and PR-title validation remain required.

The active GitHub ruleset requires exactly `CI`, `gitleaks` and `Validate PR Title`, with an up-to-date branch. Only repository administrators retain an `always` bypass; that capability does not authorize its use. Actions must be pinned to complete commit SHAs. Dependabot's metadata-only automation has separate read and write jobs, verifies actor, author and repository identity, and only enables auto-merge for npm minor/patch updates. This Flutter repository has no npm dependency ecosystem, so Pub, Gradle and Actions updates remain manual.

Run the dependency-free CI helper regressions with Node.js 24.x:

```bash
node --test test/tool/ci/*.test.cjs
```

Full CI runs these tests in the workflow-lint job. They cover complete change ranges, rename boundaries, incomplete history and failure handling in the final gate. Manual CI runs take the full path; manual secret scans cover all available history.

## Fixing Failures

Fix the underlying code or tests. Do not add baselines, exclusions, suppressions, threshold increases, empty tests, or generated-looking wrappers that only move a violation. Refactor toward focused functions and files, test observable behavior, remove genuinely unused code, and extract shared behavior only when the duplication represents one stable responsibility.
