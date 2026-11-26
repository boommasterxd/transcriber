# CI Test Selection

## Scope and safety

The required `CI` workflow runs on pull requests to `main`. It compares the complete pull-request head with its merge base, rather than the latest commit or a truncated changed-files API response. Disabling rename detection exposes both endpoints as additions/deletions. A nonempty diff entirely under root `docs/` skips application checks and still runs the final `CI` gate. Empty, unknown, incomplete, or unreadable changes require full checks.

The final gate validates the change plan, required job results and the expected device test step outcome. The outer job plan includes `base_sha`, `head_sha`, and the actual checkout's `merge_sha`; the final gate compares all three with the current GitHub event. Manual runs bind all three to the dispatched checkout and select full checks. Failures, cancellations, missing outputs, malformed or stale plans, and unexpected skips fail the gate. Existing `gitleaks`, PR-title requirements, branch freshness, and squash-only merge protection remain independent and unchanged. There is no additional full test run before merge or on the resulting `main` push.

Dependency vulnerability scanning remains mandatory on every non-documentation PR: advisory databases can change even when the dependency files do not. The final gate rejects a plan that omits this security check.

The change-classification job validates npm dependency groups and runs the locked production npm audit whenever the plan selects dependency auditing. A failing preflight blocks the audit caller. Only this successful caller passes `npm-preflight-passed: true` to the reusable audit workflow. Scheduled, manual, and other reusable calls run the same preflight by default. OSV requires either successful validation and auditing or the explicitly prevalidated skip.

Changes to the central CJS classifier and final gate, top-level Dart CI and quality helpers, and their regression tests require full checks. This includes test-plan generation, test execution, and parameter enforcement. The final-gate regressions reject failed, cancelled, or unexpectedly skipped work for these full plans. The isolated JVM failure fixture has an explicit workflow and JVM scope.

Any GitHub Actions workflow YAML or Dependabot configuration change also selects the full Dart, JVM, Android, and bundle checks. These files control global build, release, and security behavior, so workflow lint and the dependency audit alone do not provide sufficient verification.

## Flutter dependency graph

The selector parses maintained Dart sources with the analyzer. It follows imports, exports, conditional directives, and library parts from the merge base, head, and simulated merge checkout. The combined graph finds direct and transitive test consumers, including those of deleted or renamed files. A changed test selects itself. A changed shared test helper selects its consumers.

The versioned plan records the comparison revisions, checkout, mode, reason, and selected test files. A `selected` plan contains at least one test. A verified `no-impact` plan skips test execution when the graph proves no critical test depends on the changed Dart sources. The selector uses `full` for deleted or renamed test suites, global inputs, an incomplete graph, unknown impact, a dirty checkout, or an unusable comparison. The runner recomputes the plan against the execution checkout and rejects altered or stale plans.

To inspect and execute the same selection locally, use a clean checkout and complete Git history with the pinned Flutter SDK:

```bash
flutter pub get --enforce-lockfile
dart run tool/ci/select_tests.dart \
  --base "$(git rev-parse origin/main)" --head "$(git rev-parse HEAD)" \
  --output .dart_tool/ci/test-plan.json
cat .dart_tool/ci/test-plan.json
dart run tool/ci/run_test_plan.dart .dart_tool/ci/test-plan.json
```

## Flutter test execution

Run `dart run tool/ci/run_test_plan.dart` without a plan for full local discovery of `test/**/*_test.dart`. The runner invokes `flutter test --no-pub` once for the selected or discovered suites, including pure Dart tool tests. It requires at least one executed, visible, unskipped test in every expected suite. Empty test inventories and missing, malformed, truncated, or unsuccessful execution reports fail. See [code quality](code-quality.md#local-commands) for setup and platform-specific checks.

## Dependencies outside imports

The conservative mappings intentionally include broader suites when a reliable narrower contract is unavailable:

| Input | Required treatment |
|---|---|
| Three provider-logo assets | Explicit runtime edges from `assets/images/providers/openai.png`, `openai_dark.png`, and `gemini.png` to `lib/ui/widgets/provider_logo.dart` select its transitive widget consumers. The asset bundle still builds. |
| Other Flutter assets and asset declarations | Full Flutter tests and asset-bundle build; unknown runtime paths cannot safely narrow the scope. |
| Package dependencies, SDK selectors, global analysis/test configuration | Full affected language checks and tests. |
| Ordinary Dart production changes | Dart quality checks, affected tests, and asset-bundle verification. |
| Ordinary Dart test changes | Dart quality checks and affected tests. |
| Native Android channels, resources, manifests, and Gradle inputs | JVM/Android tests, instrumented-test execution and Flutter checks for cross-language contracts. Unknown native impact retains the complete native suite. |
| Pure Kotlin test changes | Tests corresponding to classes in the [JVM source manifest](../tool/ci/jvm/sources.txt) require only the independent JVM quality/test job and dependency audit. |
| Pure Kotlin production changes | Classes in the [JVM source manifest](../tool/ci/jvm/sources.txt) select Android compilation, JVM and device tests for transitive consumers. |
| Android instrumentation source changes | Native compilation, JVM tests and instrumented-test execution. |
| Dart entrypoint/channel contracts | `lib/main.dart`, `lib/share_entrypoint.dart`, `lib/keyboard_entrypoint.dart`, `lib/services/dictation/dictation_platform.dart`, and `lib/services/audio/audio_recorder_service.dart` also select native and device checks and bundle verification. Maintain this mapping when adding or relocating native bridges. |
| Filesystem, HTTP, and platform contracts | Import consumers include mocked boundary tests; unknown fixtures or contract files require the full suite. |
| Shared test support and setup | Transitive test consumers; global setup requires full tests. |
| CI/quality tooling | Central classification/acceptance helpers, top-level Dart CI/quality helpers and mirrored regressions require full checks; unknown tooling also requires full checks. Bounded native length and JVM failure fixtures retain explicit scopes. |
| CSS or unrecognized asset/contract formats | No CSS is currently used; unknown inputs require full checks. |

Device-selected changes use an isolated API 35 Google APIs emulator with KVM. The runner checks ARM64 compatibility before installing the APK and runs the guest offline. The instrumentation guard rejects missing reports and requires at least one executed, unskipped test per maintained class. The fixtures exercise Android share/open-file delivery, content-provider cancellation and the keyboard's editor boundary. The same emulator runs the system document picker recovery test across process death with the existing debug APK. The [device release procedure](operations.md#keyboard-dictation-verification) also covers physical Samsung and Pixel devices.

## Runner work and caches

Change classification, final `CI`, title validation, Gitleaks, Dependabot metadata and merge, version updaters, and release publication use `ubuntu-slim` with explicit five- or ten-minute timeouts. Workflow lint, Dart and native checks, APK builds, and container-based OSV scans use regular runners.

Formatting, analysis, size and complexity checks, dead-code detection, duplication, critical tests, and applicable asset-bundle builds share a runner and one locked dependency resolution. Dart static checks keep their complete source scope. A production Dart change builds the bundle even when no critical test is affected. When native checks assemble the Flutter debug bundle, CI verifies its nonempty kernel and asset manifest on the native runner.

Native tests, Detekt settings, and changes exclusively to manifest-listed Kotlin helpers, `EditorFieldPolicy.kt`, or `ImeNavigationBarAppearance.kt` use native checks. The JVM or Android job runs Detekt and the dependency-free Node gate for the 500-line Kotlin, Gradle, and shell limit.

`tool/ci/jvm/sources.txt` is the single manifest for the independent Gradle source sets and Node classification. The JVM project references the actual Kotlin sources and tests; it copies no production code and needs neither Flutter nor an Android SDK. Its JDK, Kotlin plugin, JUnit version, dependency locks, and artifact checksums are pinned. Both Gradle builds validate their JUnit reports with the same execution guard: every configured test class must execute an unskipped test. Android discovers all maintained `src/test/kotlin/**/*Test.kt` files; the independent build uses its manifest. Missing reports, empty tasks, and entirely skipped classes fail.

The independent JVM job runs only when the plan excludes Android checks. The Android unit test command runs the full maintained Kotlin suite, including the standalone subset. Global or workflow changes exercise focused Gradle fixtures on the Android runner. Robolectric uses the locked API 35 sandbox offline.

JVM regression fixtures reuse one Gradle daemon per Node test process. Each session owns a temporary Gradle home and daemon registry and links the existing dependency and compiler caches and the wrapper. Individual cases use separate source and build directories. Teardown stops the session's daemons before deleting its temporary home, with a 60-second daemon idle timeout as a fallback.

### Shared dependency stores

CI, manual APK builds, releases and Java/Kotlin CodeQL analysis use the same restore-only dependency interfaces. `.github/actions/dependency-cache` owns the versioned cache keys and paths for the Flutter SDK, Pub packages, npm content store and Gradle dependencies/wrapper. Keys include runner OS/architecture, compatible runtime inputs and the applicable lock/configuration files, without branch, commit or PR identity. Compatible fallback prefixes retain runtime boundaries. Bump the cache schema when changing store layout or completeness requirements.

Gradle consumers validate the committed Wrapper JAR and share `~/.gradle/caches/modules-2` and `~/.gradle/wrapper`. Android and standalone JVM checks use the same identity containing both dependency roots. The Gradle Wrapper verifies the pinned distribution checksum. Cache contents exclude build outputs, transforms, compiler caches, test results, credentials and signing files. Flutter SDK and Pub stores are separate. The SDK includes Android artifacts prepared by `flutter precache --android`. Both Node quality and Dart duplication use the locked Node tools and shared npm content store. Overlapping setup-action and CodeQL dependency caches are disabled. CodeQL analysis database caches remain independent.

`.github/actions/setup-android-ndk` shares the two pinned NDK versions across Android CI, CodeQL, build and release. It validates installed revisions, preserves valid runner installations and installs only missing or incomplete versions with bounded retries. NDKs have a separate OS/architecture/version identity; a changed NDK version requires updating the action and installer together.

The `Dependency cache warmup` workflow is the sole shared-store producer. It accepts only `main`, uses read-only repository permissions and no signing, provider or registry secrets. It runs after relevant dependency, runtime, cache-action or consuming-workflow changes on `main`. Manual dispatch on `main` supplies the initial seed or restores an evicted seed. Install hooks are suppressed for the complete npm development graph. Pub retains lockfile enforcement. A Gradle init script resolves external compile, runtime, compiler, lint, and Robolectric artifacts under each project's lock. The root task depends on the subproject tasks. The workflow resolves project dependencies without building project outputs or executing tests. A failed population step prevents saving the shared stores. Scratch outputs are removed before archiving the SDK to bound disk use.

Consumers never save partial PR or release stores. A cache miss or cache-service error proceeds to the normal installation. Incomplete SDK restores are discarded and NDKs are revalidated. Lockfile-enforced installs, Gradle verification, tests, audits, and signature checks remain mandatory. Fork PRs can read default-branch caches, so stores must contain only public dependencies. Security-scanner jobs that inspect lockfiles without installing dependencies need no package-store restore.

The repository uses a seven-day inactivity limit to cover an active weekly pull-request cycle. After prolonged inactivity or eviction, the ordinary locked install handles cold execution. Dependency changes trigger the next warmup, and maintainers can seed the cache manually from `main`. The 10 GB ceiling budgets for one active Flutter SDK, Pub, npm, Gradle and NDK store set, independent CodeQL snapshots, and overlap during replacement. Compatible fallback keys and verified replacement cleanup make room for rotation without extra paid capacity. See [GitHub's cache eviction policy](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching#usage-limits-and-eviction-policy).

Restore steps expose native exact/matched-key outcomes and write summaries distinguishing exact restores, compatible fallbacks, cold/error and unknown outcomes. For the optimization target, evaluate the first 30 days after a complete seed, counting each eligible unchanged-compatible-store PR installation as one opportunity. Target at least 95% confirmed successful restores: report exact and fallback counts separately, with cold, error and unknown outcomes retained in the denominator. Initial-seed and dependency-changing opportunities are separate. Compare restore/install durations with equivalent cold runs and include all warmup time, transfers and storage; a cache hit alone proves neither completeness nor time or monetary savings. This target is not a merge gate.


The producer's follow-up cleanup runs after successful installation and cache post-save.
It retires only older compatible main generations with a uniquely identified nonempty
replacement. The metadata-only `cache-lifecycle.yml` also removes closed-PR caches once
associated runs finish, and retires replaced CodeQL snapshots per configuration and tool version. Current keys, open PRs, active consumers,
unknown families and unproven replacements remain protected. The project-owned policy
and portable GitHub plugin runtime in `tool/ci/cache-lifecycle` recheck main, cache versions,
PR state and active runs before deleting numeric cache IDs, cap each run at 100 deletions
and verify the remaining inventory. API failures preserve uncertain caches.

Deferred main rotation resumes on completion events using only a verified successful
main producer and its exact run attempt. An earlier main revision is accepted only
after a complete bounded ancestor comparison proves that all declared native key,
setup and install-hook inputs remain unchanged, including rename sources. Producer
input paths also trigger the warmup; completion triggers cover all existing non-cleanup
workflows. Recovery considers at most 20 successful main runs, 100 commits and fewer
than 300 changed files. Missing or expired proof preserves caches until another
authorized warmup establishes a replacement. Its tiny
`cache-lifecycle-receipts-<attempt>` artifact contains only `replacements.json`, retained
for seven days and bounded to 64 KiB/20 identities. PR artifacts are never used.
Cleanup installs no dependencies and repeats no quality pipeline. Existing required gates,
cache retention/storage limits and the measurable 95% restore target remain independent.
Native regression checks cover replacement proof, protected caches, PR/run races,
CodeQL attempts where applicable, bounded metadata and recovery after concurrent runs.

Graph snapshots read Git blobs in a single bounded `git cat-file --batch -z` process. The parser validates byte lengths, UTF-8, object type, complete framing, and resource limits. Each plan validation still reconstructs the complete graph; no previous graph or selection is trusted as a cache.

Signed APK builds and releases use their own [workflows and signing requirements](operations.md#release).

When evaluating a CI change, compare equivalent source scopes and cache states. Track elapsed time from workflow creation to completion, and record each job's setup, execution and cleanup time to compare total runner occupancy. Use the applicable billing rules to estimate costs. Report local Git or test-runtime timings separately from hosted workflow timings.
