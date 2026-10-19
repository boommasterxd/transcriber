# CI Test Selection

## Scope and safety

The required `CI` workflow runs on pull requests to `main`. It compares the complete pull-request head with its merge base, rather than the latest commit or a truncated changed-files API response. Disabling rename detection exposes both endpoints as additions/deletions. A nonempty diff entirely under root `docs/` skips application checks and still runs the final `CI` gate. Empty, unknown, incomplete, or unreadable changes require full checks.

The final gate validates the change plan and every expected job result. Failures, cancellations, missing outputs, malformed plans, and unexpected skips fail the gate. Existing `gitleaks`, PR-title requirements, branch freshness, and squash-only merge protection remain independent and unchanged. There is no additional full test run before merge or on the resulting `main` push.

Dependency vulnerability scanning remains mandatory on every non-documentation PR: advisory databases can change even when the dependency files do not. The final gate rejects a plan that omits this security check.

## Flutter dependency graph

The selector parses maintained Dart sources with the existing analyzer dependency. It includes imports, exports, conditional directives, and library parts in both merge-base and head snapshots. Reverse reachability over their union finds direct and transitive consumers, including consumers of deleted or renamed files. Existing changed tests select themselves; changed shared test helpers select their consumers. An unknown dependency or unexpectedly empty selection falls back to the full suite.

Tests execute against GitHub's simulated merge checkout, which is also included in the graph. Plans bind to that checkout and are recomputed and validated before execution; a stale or altered selection must not silently remove tests. Uncommitted source changes require full tests. Full local test commands remain in [code quality](code-quality.md#local-commands).

To inspect and execute the same selection locally, use a clean checkout and complete Git history with the pinned Flutter SDK:

```bash
flutter pub get --enforce-lockfile
dart run tool/ci/select_tests.dart \
  --base "$(git rev-parse origin/main)" --head "$(git rev-parse HEAD)" \
  --output .dart_tool/ci/test-plan.json
cat .dart_tool/ci/test-plan.json
dart run tool/ci/run_test_plan.dart .dart_tool/ci/test-plan.json
```

The versioned plan contains comparison revisions, the execution checkout, mode/reason, selected test files, and production coverage sources. Unknown impact uses `full`; a selected plan must contain tests. Production coverage is restricted to directly changed surviving production sources and the enclosing libraries of changed parts, with all thresholds unchanged and missing sources rejected. Transitive consumers select tests but do not expand the coverage denominator to unchanged code. It is explicitly reported as **partial**, not repository-wide coverage. A test-only selection with no changed production sources explicitly reports that no application coverage was measured. Scopes without measurable function/branch candidates use full tests so the unchanged empty-denominator checks remain meaningful. The precheck shares the coverage checker's instrumentability classification, excluding part fragments and interface-only contracts from those candidates. Full mode retains the complete maintained-source inventory. No coverage is restored from a previous run.

## Dart and Flutter test runtimes

The runner partitions the selected files, or the complete local test inventory in full mode, exactly once. A direct `package:test/test.dart` import opts a suite into the Dart VM. Direct or transitive local dependencies on Flutter or `dart:ui`, and an applicable automatically loaded `flutter_test_config.dart`, retain the Flutter runner. Unmarked tests retain Flutter; invalid paths, escaped/symlinked sources, unresolved local dependencies, and empty or duplicate inventories fail closed. Runtime partitioning never removes a test from the validated impact plan.

Both runners also write bounded JSON execution reports. A successful process must have a complete successful report and at least one executed, non-hidden, non-skipped test in every selected suite. Missing, truncated, or malformed reports and entirely skipped suites fail, including test-only plans that intentionally require no application coverage.

Only nonempty partitions launch a test process. Dart tests use `dart test --branch-coverage --coverage-path=...`; widget and platform-dependent tests use `flutter test --no-pub --coverage --branch-coverage`. With only VM suites selected, the runner does not invoke the Flutter test command. Tool regression fixtures can intentionally exercise both runtimes as part of their selected check. The Flutter SDK remains necessary for this application's package resolution and project-wide Flutter analysis.

When the plan requires application coverage, each runtime with reachable executable application sources must produce its own fresh LCOV report. Tool-only partitions and validated partial plans without affected application sources explicitly report that they measure no application coverage. Reports are merged before the existing coverage gate: canonical source/line/branch identities form a union and overlapping hits use the maximum, so sources are not counted twice. Malformed, missing, unexpectedly empty, or incompatible reports fail. Branch layouts must agree for overlapping sources. Both collectors retain the same executable-line statement proxy and analyzer-derived function proxy. Full mode still checks every maintained application source; partial plans retain their original restricted inventory and thresholds.

An ordinary complete `flutter test --coverage --branch-coverage` remains available locally, including suites that opt into the Dart VM in CI. [Code quality](code-quality.md#local-commands) documents individual runtime and merge commands.

## Dependencies outside imports

The conservative mappings intentionally include broader suites when a reliable narrower contract is unavailable:

| Input | Required treatment |
|---|---|
| Three provider-logo assets | Explicit runtime edges from `assets/images/providers/openai.png`, `openai_dark.png`, and `gemini.png` to `lib/ui/widgets/provider_logo.dart` select its transitive widget consumers. The asset bundle still builds. |
| Other Flutter assets and asset declarations | Full Flutter tests and asset-bundle build; unknown runtime paths cannot safely narrow the scope. |
| Package dependencies, SDK selectors, global analysis/test configuration | Full affected language checks and tests. |
| Ordinary Dart production or test changes | Dart quality checks and affected Dart/Flutter tests, without Java, Android compilation, or a separate application bundle. Tests compile their selected Dart inputs. |
| Native Android channels, resources, manifests, and Gradle inputs | JVM/Android tests and instrumented-test compilation plus Flutter checks for cross-language contracts. Unknown native impact retains the complete native suite. |
| Pure Kotlin test changes | The manifest-listed `EditorSessionGateTest.kt` and `PcmLevelMeterTest.kt` require only the independent JVM quality/test job and dependency audit. |
| Pure Kotlin production changes | `EditorSessionGate.kt` and `PcmLevelMeter.kt` require JVM tests and Android compilation/tests to check transitive consumers; Dart checks remain excluded. |
| Dart entrypoint/channel contracts | `lib/main.dart`, `lib/share_entrypoint.dart`, `lib/keyboard_entrypoint.dart`, and `lib/services/dictation/dictation_platform.dart` also select native checks and bundle verification. Maintain this mapping when adding or relocating native bridges. |
| Filesystem, HTTP, and platform contracts | Import consumers include mocked boundary tests; unknown fixtures or contract files require the full suite. |
| Shared test support and setup | Transitive test consumers; global setup requires full tests. |
| CI/quality tooling | Tool regressions and applicable quality checks; unknown tooling requires full checks. |
| CSS or unrecognized asset/contract formats | No CSS is currently used; unknown inputs require full checks. |

This Android application has Flutter unit/widget tests and Android JVM/instrumented tests. Accessibility assertions and keyboard interactions inside Flutter tests follow the same selection graph. Device tests remain a separate release procedure. There is no configured Playwright, browser E2E, dedicated performance suite, or Vercel project to optimize. CI does not start browsers, containers, or device emulators for Flutter-only selections. This change does not add missing categories or claim device/manual accessibility verification.

## Runner work and caches

Formatting, analysis, size/complexity, dead-code detection, duplication, selected Dart/Flutter tests, and the optional asset-bundle build share a runner and one locked dependency resolution. Dart static checks retain their complete source scope. Ordinary Dart edits do not build the application bundle; entrypoints, assets, dependencies, packaging inputs, global configuration, and uncertainty retain bundle checks. When native checks already assemble the Flutter debug bundle, CI verifies its nonempty kernel and asset manifest instead of building it again on the Dart runner.

Native tests, Detekt settings, and changes exclusively to `EditorFieldPolicy.kt`, `EditorSessionGate.kt`, `ImeNavigationBarAppearance.kt`, `PcmLevelMeter.kt`, or `ShareFileNamePolicy.kt` do not start the Dart job. These helpers do not define Dart channels or entrypoints. The selected JVM or Android job runs Detekt and the dependency-free Node gate preserving the 500-line Kotlin/Gradle/shell limit.

`tool/ci/jvm/sources.txt` is the single manifest for the independent Gradle source sets and Node classification. The JVM project references the actual Kotlin sources and tests; it copies no production code and needs neither Flutter nor an Android SDK. Its JDK, Kotlin plugin, JUnit version, dependency locks, and artifact checksums are pinned. Both Gradle builds validate their JUnit reports with the same execution guard: every configured test class must execute an unskipped test. Android discovers all maintained `src/test/kotlin/**/*Test.kt` files; the independent build uses its manifest. Missing reports, empty tasks, and entirely skipped classes fail.

The independent JVM job runs only when Android checks are excluded. When Android checks are necessary, their regular test command already runs all native JVM tests, so the extra JVM runner is excluded by the validated plan. Global/workflow changes additionally verify the independent harness and its defect/skip regressions on the existing Android runner. Local Android commands remain complete without special exclusion flags. Production helper changes retain Android checks because a standalone helper test cannot prove compatibility of its Android callers.

SDK and lockfile-keyed Pub caches remain enabled. The JVM job uses its own Gradle home and dependency/wrapper cache, avoiding the Android dependency cache on pure test changes. The Android job still needs Flutter and can compile its assets internally.

Both Gradle jobs cache only `modules-2` dependencies and the wrapper with appropriate OS/toolchain/lock/configuration keys. After successful Android checks the job stops Gradle, releases build outputs and uncached Gradle scratch/transform caches, and reports free disk space before post-job cache archiving. This avoids the observed disk exhaustion when archiving the SDK and complete Gradle cache together. Test-result and coverage caches are not reused across revisions.

Graph snapshots read Git blobs in a single bounded `git cat-file --batch -z` process. The parser validates byte lengths, UTF-8, object type, complete framing, and resource limits. Each plan validation still reconstructs the complete graph; no previous graph or selection is trusted as a cache.

Signed APK builds and releases retain their explicit workflows and signing/protection requirements. This optimization does not publish artifacts or deployments.

## Measured starting point

The successful [PR CI run on 2026-10-15](https://github.com/boommasterxd/transcriber/actions/runs/38784163535) provides the baseline below. Job durations include setup, execution, and post-job cleanup. The sum is elapsed runner occupancy, before billing rounding or account-specific prices.

| Measurement | Observed duration |
|---|---:|
| Workflow wall time, creation to completion | 10 min 12 s |
| Sum of all 10 job durations | 24 min 46 s |
| Native Kotlin quality/tests job | 9 min 35 s |
| Flutter analyze/test job | 6 min 15 s |
| Size/complexity job | 2 min 59 s |
| Dead-code job | 2 min 15 s |
| Bundle-build job | 2 min 14 s |

Five jobs independently installed Flutter and resolved the same dependencies. Skipping unaffected jobs and sharing Dart setup removes repeated work; serialization can also change the critical path. Compare future runs with equivalent change scope and cache state. No percentage or monetary saving is established by this baseline alone.

Local regression verification used a separate checkout with a formatting-source change: the plan selected 19 of 119 existing test files, all 90 selected tests passed, and the changed source reached 100% in every enforced coverage metric. An injected arithmetic regression then made the same selected-test runner fail with three assertion failures. This demonstrates selection and failure propagation, not a measured hosted-runner saving.

The [successful full-scope optimization run on 2026-10-18](https://github.com/boommasterxd/transcriber/actions/runs/39174369025) occupied six runners for a summed 20 min 19 s, with 11 min 33 s from workflow creation to completion (including 45 s before the first job started). Its native test/compile step took 7 min 35 s. This is not a controlled comparison with the earlier baseline, and it predates the further scope and Git-reading changes above. The optimization PR itself changes global CI configuration, so its complete PR diff requires full checks even on subsequent commits. Normal future Dart PRs use the narrower scope.

For 314 Dart files, three local snapshot reads took 5,836/5,312/5,298 ms before batching and 425/189/162 ms afterward; the median changed from 5,312 to 189 ms. These are local snapshot timings, not hosted workflow duration or billed runner usage. No monetary saving or percentage reduction in runner minutes is established.

The last [full run before runtime splitting](https://github.com/boommasterxd/transcriber/actions/runs/39175796408) used 19 min 48 s of summed runner time and 10 min 14 s from creation to completion. Its combined Flutter test/coverage step took 6 min 26 s and native test/compile step took 7 min 7 s.

A local comparison ran the same 33 pure suites (433 tests), including branch coverage, with concurrency two and CPU affinity restricted to two logical CPUs. Three Dart VM runs took 3.89/4.52/4.49 s; the same Flutter runs took 16.55/16.82/16.88 s. The medians were 4.49 s and 16.82 s. These measurements cover those test processes on a warm local setup, not SDK installation, a complete CI job, or billed usage. The independent JVM suite was also verified with missing Android SDK paths and no Flutter project configuration; production-defect and entirely/partially skipped-class fixtures failed as required.
