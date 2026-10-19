# Code Quality

## Policy

All quality limits are strict. The repository has no legacy baseline, no grandfathered violations, and no accepted duplication percentage. Existing violations intentionally fail CI until the code is corrected.

Review thresholds guide refactoring before CI limits are reached. CI limits are hard failures:

| Metric | Review threshold | CI limit | Implementation |
|---|---:|---:|---|
| Function length | over 50 lines | 100 lines | Dart Code Linter `lines-of-code`; Detekt `LongMethod` |
| File length | over 300 lines | 500 lines | `tool/quality/check_code_quality.dart`; equivalent `tool/ci/check-native-file-length.cjs` for native-only CI |
| Cyclomatic complexity | over 15 | 20 | Dart Code Linter `cyclomatic-complexity`; Detekt `CyclomaticComplexMethod` |
| Cognitive complexity | over 15 | 25 | Dart analyzer AST traversal; Detekt `CognitiveComplexMethod` |
| Parameters | over 4 | 6 | Complete analyzer AST parameter counts; Detekt `LongParameterList` |
| Nesting depth | over 3 | 4 | Dart Code Linter `maximum-nesting-level`; Detekt `NestedBlockDepth` |
| Line coverage | below 85% | 85% | Flutter LCOV `DA` records |
| Statement coverage | below 85% | 85% | Executable-line proxy from Flutter LCOV `DA` records |
| Function coverage | below 85% | 85% | LCOV `FNDA`, or analyzer-derived function spans mapped to line hits |
| Branch coverage | below 80% | 80% | Flutter LCOV `BRDA` records |

Flutter coverage is line-oriented and currently omits native `FNDA` records. The repository therefore uses executable lines as the statement proxy and maps analyzer-derived Dart function spans to LCOV line hits as the function proxy. The full checker enumerates every tracked `lib/**/*.dart` source and fails closed if Flutter omits any source from LCOV. Selected-test coverage uses an explicitly validated, restricted source inventory and is reported as partial coverage. Thresholds remain identical, and missing required sources or empty metric denominators fail. These mappings must remain documented until Flutter emits independent statement and function coverage. See [CI test selection](ci-test-selection.md) for scope and fallback rules.

Executable maintained Dart parts are separate measured sources, including `dictation_connection.dart` and `keyboard_components.dart`. Missing part records fail; changing either a library or one of its parts includes the enclosing library and sibling parts in selected coverage. Only generated `.g.dart` units with the generated-code header, pure abstract interfaces/typedefs, directive-only units, and constant-only data/memberless enums lack independent executable metrics. These are syntax-checked tool limitations, not blanket part exclusions.

The parameter gate walks every analyzer `FormalParameterList`, including constructors, factories, `copyWith`, functions, closures, callbacks, and function types. DCL omits some of those declarations, so its parameter metric is not authoritative. Remaining DCL size/cyclomatic/nesting measurements must be present exactly once and contain valid numeric values for each reported function; malformed or incomplete reports fail.

`analysis_options.yaml` explicitly excludes generated build output and platform roots from Dart analysis. These are language and tool-scope boundaries, not a quality baseline: CI explicitly formats and analyzes maintained Dart code in `lib/`, `test/`, and `tool/`. Maintained Kotlin under `android/app/src/main/kotlin/` is checked separately with Detekt and its formatting rules.

Drift generates `lib/data/database/app_database.g.dart`. The file is checked into source control so builds do not depend on code generation, but it is excluded from direct analyzer, size, complexity, and duplication measurements only when it carries Drift's generated-code header. It remains compiled through `app_database.dart`. Maintained database declarations, queries, repositories, and migrations remain fully subject to every quality gate.

The pinned Flutter 3.47.7 SDK requires `test_api` 0.7.12, compatible with the Dart VM runner `test` 1.31.1. That test runner excludes Analyzer 14; the project selects Analyzer 13.x and resolves Build Runner 2.16.1. Their declared constraints and generated lockfile intentionally preserve this compatibility, without dependency overrides. Revisit the combination when updating Flutter. Code generation and all strict quality/coverage checks must remain verified across such changes.

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
node tool/ci/check-native-file-length.cjs
JAVA_HOME=/path/to/jdk17 android/gradlew -p android \
  :app:testDebugUnitTest :app:verifyNativeCoverage :app:compileDebugAndroidTestKotlin
```

Run `:app:connectedDebugAndroidTest` separately on an attached Android device or emulator. CI compiles the maintained instrumented test sources, while device-specific input-method behavior remains part of release verification.

Run the manifest-listed pure Kotlin tests without Flutter or an Android SDK:

```bash
JAVA_HOME=/path/to/jdk17 android/gradlew -p tool/ci/jvm test verifyNativeCoverage
```

The independent build uses the existing Gradle wrapper, JDK 17, Kotlin 2.4.21, and JUnit 4.13.2, with committed dependency locks and SHA-256 verification metadata. Its sources reference the maintained files under `android/app/src/`. Refresh these locks and verification metadata deliberately when updating dependencies, and review the changed artifact hashes. The regular Android command above still runs every JVM test; it needs no exclusion property. Both builds share a JUnit-report guard requiring actual execution in every configured test class, including Android's complete maintained unit-test inventory.

### Native coverage

Both builds use JaCoCo 0.8.14 and `tool/ci/jvm/native_coverage.gradle.kts`. The standalone report must exactly match `sources.txt`; Android must measure every maintained production Kotlin source without source exclusions. Missing or empty execution data, bytecode, reports, source records, or applicable metric denominators fail. The four blocking limits are LINE 85%, INSTRUCTION 85%, METHOD 85%, and BRANCH 80%. Bytecode instructions are the statement proxy and methods include constructors/getters; neither is an independent source-statement or source-function measurement.

Android unit tests use Robolectric 4.17 and Mockito 5.21.0 at explicit platform boundaries. Their SDK sandbox artifacts resolve through Gradle, are included in `android/app/gradle.lockfile`, and are supplied offline to Robolectric. The OSV workflow scans that Android graph alongside Pub and the standalone JVM graph. JaCoCo is EPL-2.0; Robolectric and Mockito are MIT-licensed. See the official [JaCoCo documentation](https://www.jacoco.org/jacoco/trunk/doc/), [Gradle coverage guide](https://docs.gradle.org/current/userguide/jacoco_plugin.html), and [Robolectric compatibility table](https://robolectric.org/compatibility_table/).

The Android test runtime explicitly declares `kotlin-stdlib-common` at the toolchain version so Gradle's runtime graph and committed locks agree. Verify an ordinary locked test/coverage invocation after refreshing locks; a successful `--write-locks` invocation alone does not prove that verification path.

Regression fixtures verify actual failed Gradle tasks for missing native sources, zeroed counters, missing XML, and deleted execution data:

```bash
JAVA_HOME=/path/to/jdk17 node --test test/tool/ci/native-coverage.integration.cjs
```

Robolectric coverage does not establish device microphone, editor, content-provider, or Flutter-engine behavior. The separate device test command above remains required for release verification.

### Dart coverage

Generate and enforce test coverage:

```bash
flutter test --coverage --branch-coverage
dart run tool/quality/check_coverage.dart coverage/lcov.info
```

Run an individual pure Dart suite without the Flutter test engine:

```bash
dart test --branch-coverage --coverage-path=coverage/dart/lcov.info \
  test/services/remote/mime_utils_test.dart
```

The CI plan runner partitions the complete impacted selection and invokes only the required runtimes. When both runtimes produce application coverage, it performs the equivalent merge below before applying the existing full or validated partial source inventory:

```bash
dart run tool/quality/merge_coverage.dart --output coverage/lcov.info \
  coverage/dart/lcov.info coverage/flutter/lcov.info
```

One suite's report is not repository-wide coverage. A tool-only runtime explicitly measures no application coverage; an expected application report cannot be missing or empty. See [runtime selection and coverage merging](ci-test-selection.md#dart-and-flutter-test-runtimes).

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

`.github/workflows/ci.yml` starts only jobs required by the complete change scope:

- `Workflow lint` verifies every GitHub Actions workflow with a pinned, checksum-verified `actionlint` binary.
- `Dart quality, tests and bundle` shares one Flutter installation and locked dependency resolution across formatting, analysis, selected tests/coverage, size/complexity, unused-code/file detection, duplication, and the optional bundle build. Applicable independent checks still run after another check fails; the job remains failed.
- `JVM quality and tests` runs the manifest-listed pure Kotlin tests without Flutter/Android, plus the existing Detekt and Kotlin/Gradle/shell file-length gates, only when the plan excludes Android. CI-tool changes additionally exercise real defect/skip fixtures; ordinary pure-test changes skip those fixtures.
- `Android quality and tests` compiles Android consumers, runs every native JVM test, and compiles instrumented Android tests, with the same Detekt/file-length gates. Global/workflow changes also verify the independent JVM harness and its regression fixtures on this runner, without starting an additional JVM job. Local Android commands remain complete.
- Duplication still rejects every Dart clone of at least 50 tokens; static Dart checks retain their full source scope.
- Bundle verification runs for entrypoints, channel bridges, assets, dependencies, packaging/global configuration, and uncertainty. Ordinary Dart changes use analysis and selected test compilation. When Gradle already assembles the debug bundle, the native job verifies its kernel and asset manifest without a second bundle build on the Dart runner.

`.github/workflows/dependency-audit.yml` scans `pubspec.lock`, `android/app/gradle.lockfile`, the independent JVM `gradle.lockfile`, and its dependency verification metadata with the pinned OSV Scanner reusable workflow and fails on known vulnerabilities. Every non-documentation PR retains this gate because advisory data changes independently of the lockfile. The independent weekly and manual scans also remain available. `.github/workflows/gitleaks.yml` scans both the merge working tree and every commit introduced by the PR, including secrets removed before the final tree. Its default detectors cover every path without test or Firebase-file allowlists. Before scanning, the checksum-verified binary must pass synthetic regressions for those paths and for a credential deleted from the final tree but retained in introduced history.

The only historical exceptions are three commit/path/rule/line fingerprints in [`.gitleaksignore`](../.gitleaksignore), covering Google keys the project owner confirmed are no longer usable. Their rationale and limits are recorded in [security](security.md#historical-scanner-exceptions). Scanner regressions also prove that the same synthetic credential in a later commit remains blocked.

Lightweight classification, final gates, scanning, metadata and publication jobs use `ubuntu-slim` with five- or ten-minute timeouts. Substantive quality/build jobs and container-based OSV scanning retain regular runners. Actual hosted Slim execution remains separate from local workflow validation; no savings are inferred from runner selection alone.

### Native GitHub Scanning

Repository secret scanning and push protection are enabled, independently of required Gitleaks. Fork workflow approval is configured as `all_external_contributors`.

`.github/workflows/codeql.yml` defines one advanced configuration for Actions, JavaScript and manually compiled Kotlin, using the pinned Flutter SDK and JDK 17. It replaces default setup, whose automatic Kotlin build failed and excluded that language. Its substantive analysis jobs use regular runners with bounded timeouts. Kotlin compilation disables build-cache and up-to-date reuse so the extractor sees maintained sources. Local YAML validation and compilation do not establish hosted Kotlin extraction; inspect matching PR analysis results. CodeQL scans are distinct from application `CI` and do not add another required check or repeat its tests.

The current [CodeQL language support table](https://codeql.github.com/docs/codeql-overview/supported-languages-and-frameworks/) lists Kotlin through 2.4.20; the project uses 2.4.21. The first hosted traced build and analysis succeeded with CodeQL 2.27.2, as qualified in the [setup report](reports/project-setup-report.md#published-verification-snapshot). Reverify the actual hosted bundle when changing this toolchain. Do not downgrade the project or exclude Kotlin merely to make the scan green.

APK-build workflows explicitly default to `contents: read`. Only the separate release-publication job overrides that default with the content/artifact write access it needs; compilation itself receives no repository write permission.

## Protected Pull Requests

Automatic quality checks and secret scanning run on pull requests targeting `main`, using GitHub's simulated merge checkout. They do not run again on the resulting `main` push. The final `CI` check validates all planned job results. Failed, cancelled, missing or unexpectedly skipped jobs block the final check.

Only a nonempty, complete change set entirely below the root `docs/` directory takes the documentation short path. `tool/ci/detect-change-scope.cjs` compares the merge base with the PR head, includes both sides of renames, and defaults to full CI on uncertainty. Other recognized changes select relevant jobs, and Flutter tests use the analyzer dependency graph. Documentation-only changes intentionally skip all expensive jobs and still receive a real successful `CI` result. Root Markdown and other unknown inputs run full CI. Secret scanning and PR-title validation remain required. [CI test selection](ci-test-selection.md) documents mappings, limitations, local selection commands, and measured starting durations.

The active GitHub ruleset requires exactly `CI`, `gitleaks` and `Validate PR Title`, with an up-to-date branch. Only repository administrators retain an `always` bypass; that capability does not authorize its use. Actions must be pinned to complete commit SHAs. Dependabot's metadata-only automation has separate read and write jobs, verifies actor, author and repository identity, and only enables auto-merge for npm minor/patch updates. This Flutter repository has no npm dependency ecosystem, so Pub, Gradle and Actions updates remain manual.

Run the dependency-free CI helper regressions with Node.js 24.x:

```bash
node --test test/tool/ci/*.test.cjs
```

Run the scanner regressions with the pinned binary after verifying its archive against `.gitleaks-version`:

```bash
GITLEAKS_EXECUTABLE=/path/to/checksum-verified/gitleaks \
  node --test test/tool/ci/gitleaks.integration.cjs
```

These tests create only isolated synthetic credentials and Git history, suppress scanner output, and remove their temporary fixtures. A missing scanner fails instead of silently skipping verification.

Applicable workflow changes run the Node helper regressions in the workflow-lint job. They cover complete change ranges, rename boundaries, incomplete history, job selection, and failure handling in the final gate. The scanner integration tests run in the Gitleaks workflow. Dart selector and coverage regressions live alongside them under `test/tool/`. Manual CI runs take the full path; manual secret scans cover all available history.

## Fixing Failures

Fix the underlying code or tests. Do not add baselines, exclusions, suppressions, threshold increases, empty tests, or generated-looking wrappers that only move a violation. Refactor toward focused functions and files, test observable behavior, remove genuinely unused code, and extract shared behavior only when the duplication represents one stable responsibility.
