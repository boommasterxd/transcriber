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

The versioned plan contains comparison revisions, the execution checkout, mode/reason, selected test files, and production coverage sources. Unknown impact uses `full`; a selected plan must contain tests. Production coverage is restricted to directly changed surviving production sources and the enclosing libraries of changed parts, with all thresholds unchanged and missing sources rejected. Transitive consumers select tests but do not expand the coverage denominator to unchanged code. It is explicitly reported as **partial**, not repository-wide coverage. A test-only selection with no changed production sources explicitly reports that no application coverage was measured. Scopes without measurable function/branch candidates use full tests so the unchanged empty-denominator checks remain meaningful. Full mode retains the complete maintained-source inventory. No coverage is restored from a previous run.

## Dependencies outside imports

The conservative mappings intentionally include broader suites when a reliable narrower contract is unavailable:

| Input | Required treatment |
|---|---|
| Three provider-logo assets | Explicit runtime edges from `assets/images/providers/openai.png`, `openai_dark.png`, and `gemini.png` to `lib/ui/widgets/provider_logo.dart` select its transitive widget consumers. The asset bundle still builds. |
| Other Flutter assets and asset declarations | Full Flutter tests and asset-bundle build; unknown runtime paths cannot safely narrow the scope. |
| Package dependencies, SDK selectors, global analysis/test configuration | Full affected language checks and tests. |
| Native Android channels, resources, manifests, and Gradle inputs | Native quality/JVM tests and instrumented-test compilation plus Flutter checks for cross-language contracts. Native test-only changes run native checks. There is no reliable Kotlin impact graph, so relevant native changes run the complete small native suite. |
| Filesystem, HTTP, and platform contracts | Import consumers include mocked boundary tests; unknown fixtures or contract files require the full suite. |
| Shared test support and setup | Transitive test consumers; global setup requires full tests. |
| CI/quality tooling | Tool regressions and applicable quality checks; unknown tooling requires full checks. |
| CSS or unrecognized asset/contract formats | No CSS is currently used; unknown inputs require full checks. |

This Android application has Flutter unit/widget tests and Android JVM/instrumented tests. Accessibility assertions and keyboard interactions inside Flutter tests follow the same selection graph. Device tests remain a separate release procedure. There is no configured Playwright, browser E2E, dedicated performance suite, or Vercel project to optimize. CI does not start browsers, containers, or device emulators for Flutter-only selections. This change does not add missing categories or claim device/manual accessibility verification.

## Runner work and caches

Formatting, analysis, size/complexity, dead-code detection, duplication, selected Flutter tests, and the optional asset-bundle build share a runner and one locked dependency resolution. Dart static checks retain their complete source scope. Native jobs run only for relevant changes and keep a separate Gradle environment. SDK and lockfile-keyed Pub caches remain enabled. The native job caches only Gradle `modules-2` dependencies and the wrapper with OS, SDK selector, lockfile, and Gradle-configuration keys. After successful native checks it stops Gradle, releases build outputs and uncached Gradle scratch/transform caches, and reports free disk space before post-job cache archiving. This avoids the observed disk exhaustion when archiving the SDK and complete Gradle cache together. Test-result and coverage caches are not reused across revisions.

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
