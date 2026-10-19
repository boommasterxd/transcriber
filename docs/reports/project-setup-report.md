# Project Setup Report

## Setup remediation follow-up

On 2026-10-19, the requested local corrections for F1, F2 and F4 were implemented on the work branch starting at `b78b97b`. F3/F5 were completed by the concurrent implementation and independently inspected and tested as described below. All five original source findings are addressed locally. This setup review performed no commits, pushes, workflow dispatches or provider changes. The later combined local verification passed and is recorded in the [code-quality report](CODE-QUALITY-REPORT.md); device and hosted execution remain unverified.

Before integration, the project owner confirmed that the three historical Google keys are no longer usable. Only their exact immutable finding fingerprints are excepted in `.gitleaksignore`, as documented in [security](../security.md#historical-scanner-exceptions). Current-tree and full-history Gitleaks scans and three scanner regressions pass. The owner separately authorized committing and pushing the full local changes, creating a PR and squash merging with the existing administrator bypass without hosted CI for this integration because of cost. The commit uses `[skip ci]`; normal required checks and ruleset settings remain unchanged.

| Finding | Follow-up status | Evidence |
|---|---|---|
| F1: scanner path exclusions | Fixed locally | `.gitleaks.toml` now enables default detectors without path allowlists. Two actual Gitleaks 8.30.1 integration tests cover four formerly excluded paths, a clean control and a deleted credential in introduced history. The workflow runs them with the checksum-verified scanner before its tree/history scans. A 415-file tracked snapshot passed without exceptions. |
| F2: central CI selection | Fixed locally | Central CJS classification/acceptance helpers, top-level Dart CI/quality helpers and their mirrored tests require full checks. Regression tests assert full flags, mixed-change behavior and rejection of failed/cancelled/skipped required work. |
| F3: parameter enforcement | Fixed in source; focused regressions passed | The existing analyzer now counts every formal parameter list, including constructors, factories, `copyWith`, closures and function/callback types. The unchanged limit is six. Invalid syntax fails closed; DCL's remaining required metrics reject omissions, duplicates and invalid values. Constructor/`copyWith` exemptions are not retained. Boundary/failure tests passed. |
| F4: administrative runners | Fixed in source; hosted execution unverified | Nine lightweight jobs now select `ubuntu-slim`, with five- or ten-minute timeouts. Substantive quality/build and container-based scanner work retain compatible runners. No hosted experiment was dispatched. |
| F5: model/presentation boundary | Fixed in source; focused regressions passed | `AppSettings` uses separate appearance, transcription and summary values, with five constructor/`copyWith` parameters. Theme/accent/language values live in `data/models`; Flutter mappings stay in `core/theme`. The inspected model/catalog dependency inventory has no Flutter, UI, state or presentation import. Existing flat JSON identifiers and legacy brightness behavior remain compatible. |

Local verification for these CI changes passed: 34 Node helper tests with 100% line/function and 99.22% branch coverage, both scanner integration tests, actionlint 1.7.12 and ShellCheck 0.11.0. Scanner/linter archives matched existing pinned checksums. The scanner job explicitly installs Node `24.x` with `check-latest: true` for its new regression command. Documentation and commands are synchronized in [code quality](../code-quality.md) and [CI selection](../ci-test-selection.md).

Independent follow-up checks used the existing pinned Flutter 3.47.7 / Dart 3.13.5 SDK without changing application source:

- `dart test test/tool/quality/parameter_count_test.dart test/tool/quality/code_quality_metrics_test.dart --reporter=expanded`: 29 tests passed, covering six/seven-parameter boundaries, positional/named declarations, constructors, factories, `copyWith`, closures, callbacks, parse errors and missing/invalid DCL metrics.
- `flutter test --no-pub test/data/models/app_settings_test.dart test/core/theme/appearance_mapping_test.dart --reporter=expanded`: ten tests passed, covering settings copies, complete JSON round trips, legacy/default behavior and every persisted theme-mode mapping.

The concurrent implementation's final combined local verification passed 1,235 Flutter tests, 73 Android tests across 19 maintained production sources, 23 standalone JVM tests, strict coverage and the Android-targeted debug asset bundle. These later results are recorded in the [code-quality report](CODE-QUALITY-REPORT.md), not independently rerun by this setup review. The original application checks below belong to the original inspected commit. Actual device and hosted Slim execution remain outstanding; hosted CI is intentionally skipped for this integration under the owner's explicit instruction.

## Original assessment

**Initial assessment at the inspected commit: partial conformance with five confirmed departures.** The active GitHub PR protections, complete-diff test selection, coverage thresholds and native Flutter/Android checks worked. Secret scanning excluded entire paths, the parameter-count gate omitted constructors and some methods, global CI helpers selected insufficient checks, lightweight automation used regular runners, and the settings model depended on presentation types. The follow-up above supersedes all five original source findings.

All 1,086 local Flutter/Dart tests passed. Full production-source coverage passed at 94.00% lines/statements, 91.25% functions and 87.53% branches. Passing the existing metrics command does not resolve its parameter-count omission.

## Original target and baseline

| Item | Inspected value |
|---|---|
| Review date / baseline | 2026-10-19; coding-tools 0.29.11 setup contract through that date, effective user instructions and root `AGENTS.md` |
| Repository | Private [boommasterxd/transcriber](https://github.com/boommasterxd/transcriber), default branch `main` |
| Inspected source | `6b69cb834daaa8c317ac4bcd2320bfa4f4a02ec9`; local starting HEAD and live `main` matched |
| Application | Flutter Android, Riverpod, Drift/SQLite, personal OpenAI/Gemini keys; no Next.js or Vercel configuration found |
| Verification runtime | Flutter 3.47.7, Dart 3.13.5, Node.js 24.22.0; Temurin 17.0.20.1 for Gradle |
| Review authority | Source/provider read-only; only this report and its root documentation-index row are maintained |

The npm/Next.js template is adapted to the existing Flutter stack. No npm application, browser server, Turso resource or cloud deployment is required. The accepted [cloud BYOK and Drift decision](../decisions/cloud-byok-and-drift.md) remains applicable. SQLite is on-device persistence, not a database intended for Vercel/Turso.

No earlier setup report or scoped setup note was present in the repository. The working tree was initially clean. Concurrent README/license work appeared during verification and was left untouched. No commits, pushes, PRs, workflow dispatches, settings changes, deployments or live provider requests were performed.

## Original findings

### F1. Secret scanning excludes the entire test tree

- **Expected:** scan the merge tree and introduced history, retaining only reviewed exact false-positive exceptions.
- **Current:** [`.gitleaks.toml`](../../.gitleaks.toml), lines 6–14, globally allows `test/.*` and `google-services\.json$`. Both invocations in [`gitleaks.yml`](../../.github/workflows/gitleaks.yml), lines 39 and 50, discover this configuration.
- **Impact:** real credentials committed under tests or a matching Firebase filename can escape both required scans. Built-in detectors, archive verification, redaction and blocking exit codes otherwise remain enabled.
- **Correction:** remove broad path exclusions. Where actual false positives remain, document and permit only the smallest exact finding-specific exceptions. Verify a synthetic credential in an isolated test-path fixture fails scanning.

### F2. Global CI-control changes do not require full checks

- **Expected:** global CI/classifier/final-gate changes run full applicable CI, including application tests, native checks and bundle verification.
- **Current:** [`detect-change-scope.cjs`](../../tool/ci/detect-change-scope.cjs), line 41, maps top-level CI CJS files to workflow checks only. Calling `classifyPaths` separately for `tool/ci/detect-change-scope.cjs` and `tool/ci/require-ci-success.cjs` produces `workflow=true`, `dependency_audit=true`, but `dart=false`, `jvm=false`, `native=false`, `build=false`.
- **Impact:** changing the mechanism selecting or accepting checks can skip the application/native verification required by the explicit global-change policy. Existing helper tests accept this narrower mapping.
- **Correction:** map central selection and acceptance helpers to full checks, with regressions for these exact counterexamples. Keep genuinely bounded inputs selective where the contract permits it.

### F3. The parameter-count gate silently omits maintained declarations

- **Expected:** at most six parameters per maintained function, without undocumented constructor or `copyWith` exemptions.
- **Current:** [`AppSettings`](../../lib/data/models/app_settings.dart), lines 14 and 67, has an eleven-parameter constructor and an eleven-parameter `copyWith`. Fresh DCL output contains no `number-of-parameters` metric for either, and [`check_code_quality.dart`](../../tool/quality/check_code_quality.dart), lines 127–135, checks only metrics that exist.
- **Evidence:** installed Dart Code Linter 4.4.2 `NumberOfParametersMetric.supports` excludes constructors and same-class-returning `copyWith` methods. Of 2,403 reported declarations, 386 omit this metric; this is not a count of violations. Named parameters are counted for supported declarations. All reported declarations contain the other three configured DCL metrics.
- **Impact:** the successful metrics command does not enforce the stated parameter limit across its source inventory.
- **Correction:** count parameters with the existing analyzer for constructors, methods, functions and closures, and fail on incomplete measurement. Add boundary/failure fixtures and refactor actual violations without broad exclusions or higher limits.

### F4. Lightweight automation uses regular runners without exceptions

- **Expected:** `ubuntu-slim` for administration/scanning/publication coordination, with explicit timeouts at most 15 minutes and verified tool compatibility. Substantive quality/build jobs retain suitable regular runners.
- **Current:** `ubuntu-latest` is configured for `Change scope` and final `CI`; `Validate PR Title`; `gitleaks`; both Dependabot jobs; Flutter and Gitleaks updater jobs; and `Publish GitHub Release`. Locations: [`ci.yml`](../../.github/workflows/ci.yml), [`commit-style-check.yml`](../../.github/workflows/commit-style-check.yml), [`gitleaks.yml`](../../.github/workflows/gitleaks.yml), [`dependabot-auto-merge.yml`](../../.github/workflows/dependabot-auto-merge.yml), [`update-flutter.yml`](../../.github/workflows/update-flutter.yml), [`update-gitleaks.yml`](../../.github/workflows/update-gitleaks.yml), [`release.yml`](../../.github/workflows/release.yml).
- **Timeout gap:** title validation, both updaters and release publication have no explicit job timeout. Other listed jobs already specify five or ten minutes.
- **Impact:** these jobs depart from the selected runner/resource policy. No measured monetary saving or hosted Slim compatibility is established.
- **Correction:** use Slim with bounded timeouts, or document concrete tool/resource exceptions. Verify representative existing or separately authorized hosted executions. Keep workflow lint/tests, Dart/native quality, APK builds and container-based OSV execution on compatible runners.

The current [GitHub runner documentation](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) describes Slim as a one-CPU, 5-GB unprivileged container with a fixed 15-minute limit. Its [official image inventory](https://github.com/actions/runner-images/blob/main/images/ubuntu-slim/ubuntu-slim-Readme.md) includes Git, jq, curl and GitHub CLI; inventory alone does not prove every selected action works.

### F5. The settings model crosses the documented presentation boundary

- **Expected:** `lib/data/models/` contains values independent of UI/state, as stated by root `AGENTS.md` and [architecture](../architecture.md).
- **Current:** [`app_settings.dart`](../../lib/data/models/app_settings.dart), lines 1–4 and 29–30, imports Flutter `ThemeMode` and presentation `AppAccent`; [`app_accent.dart`](../../lib/core/theme/app_accent.dart), lines 1–17, embeds Flutter `Color` values.
- **Impact:** persisted settings/domain consumers depend on Flutter presentation types. There is no automated import guard detecting this boundary, and the documentation's framework-independent description is inaccurate for this model.
- **Correction:** keep persisted theme/accent identifiers in framework-independent values and map them to Flutter types at the presentation boundary, preserving existing serialized identifiers. Verify the model can be used without Flutter UI imports. No concrete file-import cycle was established.

## Original control coverage

`verified` is limited to the evidence stated below; source, hosted execution and device behavior are separate layers.

| Control | Status | Current evidence / limitation |
|---|---|---|
| Native stack/layout, names, localized copy and mirrored tests | verified | Flutter layout and source-parallel `test/`; instructions and technical documentation exist; no stack migration required. |
| Recursive documentation index | verified | Complete nine-document index passed initially; final validation passed with all ten documents, including this report. Local report links and whitespace checks also passed. |
| Model/presentation boundary | drift | F5. No wider architecture or application security audit is claimed. |
| Flutter pin and locked dependency resolution | verified | `.fvmrc` 3.47.7; exact-SDK `flutter pub get --enforce-lockfile` passed without lockfile changes. Global PATH initially selected 3.44.8; checks used the existing correct SDK instead. |
| Node workflow inventory | verified | All six project-Node jobs explicitly select `24.x`, `check-latest: true`; no matrix/container/caller override. Five executed matching-run jobs resolved 24.22.0; JVM job was intentionally skipped. |
| Node application/hosting engines | not-applicable | Node is CI tooling; no npm application or hosting runtime. [Node 24 remains supported LTS](https://nodejs.org/en/about/previous-releases). |
| Formatting and fatal analyzer checks | verified | 326 Dart files formatted, zero changes; `flutter analyze --fatal-infos --no-pub` passed. |
| Size, complexity, nesting and parameter enforcement | drift | Existing metrics command passed; parameter enforcement is incomplete, F3. File, cognitive, LOC, cyclomatic and nesting checks are present. |
| Unused Dart declarations/files | verified | Both DCL unused-code/private-member and unused-file checks passed. |
| Kotlin metrics/format/unused checks | verified | Detekt 1.23.8 CLI/plugin downloads matched pinned SHA-256; configured checks passed. Native/shell length gate passed. |
| Strict duplication gate | verified | jscpd 5.0.16, Dart format, 50 tokens, threshold zero; 316 measured files, zero clones. Generated Drift adapter excluded as documented. |
| Full tests and coverage | verified | 1,086 passing tests; all 150 executable sources of 158 maintained sources measured. Thresholds 85/85/85/80 passed. Documented line-based statement/function proxies remain a measurement limitation. |
| Selected coverage and untested affected modules | verified | Required changed production inventory, missing-source rejection, unchanged thresholds, explicit partial label and full fallback; focused regressions passed. |
| Complete diff / renames / deletions | verified | Merge-base-to-head Git comparison, NUL paths, disabled rename detection plus both graph snapshots; bounded commands and conservative unknown/history fallback. |
| Transitive/runtime/assets/shared-test selection | verified | Analyzer imports/exports/conditional directives/parts plus explicit provider-logo edges; changed tests and transitive consumers; unknown contracts use full fallback. |
| Global CI/tooling fallback | drift | F2. Dependency/framework/global workflow inputs otherwise select full scope. |
| Bound plans and execution evidence | verified | Checkout binding, recomputation, stale/tampered plan rejection, complete execution reports and no empty/entirely skipped suites. |
| Root-docs-only classification and final gate | verified | Local positive/negative fixtures; valid intentional skips only, real successful final `CI`, no whole-workflow path filter. No docs runtime/build inputs found. |
| Hosted docs-only acceptance | unverified | No representative docs-only execution identified in the inspected 100 PR-event runs; use an existing matching run when available. |
| Native/JVM selection, independent local full commands | verified | Standalone JVM test execution/guard passed; Android unit-test task/guard and instrumented-test compilation passed, partly from Gradle cache. Full commands remain independent of PR context. |
| Flutter bundle and native packaging configuration | verified | Debug bundle built; nonempty kernel and asset manifest verified. Android arm64, SDK and signing configuration inspected. No release APK built in this review. |
| Device integration and manual accessibility | unverified | Instrumented tests were compiled, not run on a device. Share/permissions/secure storage/recording/IME, TalkBack and physical keyboard release matrix remain in [operations](../operations.md). |
| Web axe/browser/CSP/hydration checks | not-applicable | Android-only app. Existing widget semantics/large-text/keyboard assertions do not prove complete Android accessibility. |
| Dedicated performance budgets | unverified | No configured performance suite or device measurements; no performance conformance or savings claim. |
| Fresh dependency audit | verified | Every non-docs PR selects OSV; matching hosted run passed Pub/JVM lock/verification-metadata scan. No new local OSV scan or live provider smoke test performed. |
| Secret-scanner coverage | drift | F1; introduced-commit range, working-tree scan, redaction, blocking status and checksum control otherwise present. |
| Required workflow/check names and branch freshness | verified | Active [Protect main ruleset 6440831](https://github.com/boommasterxd/transcriber/rules/6440831): exactly `CI`, `gitleaks`, `Validate PR Title`; strict up-to-date and enforcement on creation. Workflow and final job both `CI`. |
| Merge/bypass/reviews | verified | Squash-only; deletion/non-fast-forward blocked. Sole bypass repository-admin role 5, `always`; no ordinary-user/bot bypass. Zero required reviews matches baseline. |
| Latest merge provenance | verified | Admin merge occurred before final CI completed; matching tree subsequently passed. Details below. |
| Historical override authorization | unverified | PR description reports explicit authorization; this review did not independently verify the historical user instruction. This does not authorize another bypass. |
| PR-only quality and secret scans | verified | PRs targeting `main` plus manual dispatch; no current automatic push/workflow_run repetition. Historical main-push runs predate the PR-only change. Scheduled independent OSV audit remains intentional. |
| Cancellation and caches | verified | Superseded PR CI/Gitleaks runs cancelled; SDK/lock/config-keyed dependency caches; separate JVM cache; no restored test-result/coverage cache. |
| Runner selection/time bounds | drift | F4; no hosted Slim compatibility evidence in inspected representative runs. |
| Actions pinning/upstream provenance | verified | Full-SHA policy active; ten release-tag pins matched upstream. Flutter setup and OSV use inspected post-tag checksum/pinning fixes, not unexplained tag mismatches. |
| Downloaded scanner/linter versions and checksums | verified | Gitleaks 8.30.1 published checksum matched; local actionlint 1.7.12/ShellCheck 0.11.0 archives matched workflow hashes; Detekt hashes verified on execution. |
| Workflow roles and dependabot boundaries | verified | All five baseline roles plus Flutter updater/audit/Android release; metadata-only `pull_request_target`, actor/author/same-repo/no-fork checks and separate write merge job. |
| Dependency update scheduling | verified | Pub/Gradle/Actions weekly Monday 08:00 Europe/Berlin, limit ten, minor/patch groups. npm-only auto-merge deliberately leaves actual ecosystems manual, documented in code quality. |
| Actions permissions/private forks | verified | Default read token, SHA enforcement, PR creation enabled; fork approval required, no fork write token or secrets/variables. No self-hosted runners, deploy keys or hooks. |
| Repository features and merge metadata | verified | Private, `collaborators_only`; Issues on, Projects/Wiki/Discussions/Pages off; auto-merge/branch deletion on; PR-title/commit-message squash metadata. |
| Security provider settings | verified | Dependabot alerts/automatic fixes enabled and unpaused. Explicit API responses establish native Code/Secret Scanning disabled; required custom scanning is separate. |
| Secrets/environments/retention/OIDC | verified | Four repository Android signing secret names; no values read. No repo variables/Dependabot secrets. `release` has no secrets/variables/protection/branch policy. Retention 90 days; default OIDC subject; no OIDC workflow permission. Android signing adapts the npm baseline. |
| Release signing and publication | unverified | Source rejects debug-signed APKs before upload/publication. No current release-signature, device installation or publication experiment performed; no Vercel release interface applies. |
| On-device DB schema/migration isolation | verified | Drift schema 3 and versioned Dart migration; legacy transaction precedes main/share bootstrap; synthetic in-memory v1/v2 upgrade tests passed. No real user DB opened. |
| Cloud DB environments, SQL/deploy hooks, Turso tokens/rotation | not-applicable | Local Android Drift persistence; no cloud DB, shared Preview DB or server deployment. Native schema migration is not a missing Turso deployment hook. |
| Vercel project/build ownership, Git admission, runtime/regions | not-applicable | No selected/configured Vercel target or server deployment in repository evidence. |
| App Router boundaries / initial data / blocking ESLint | not-applicable | No Next.js, App Router or browser/server module split. |
| WebP source / AVIF-WebP delivery | not-applicable | Three bundled Android provider-logo PNGs; the selected image rule is scoped to Next.js websites. |
| Vercel CSP/rendering/cache/no-store, Bot Management/WAF/BotID | not-applicable | No Vercel website, public server API or hosted form. Native calls to external provider APIs are not application WAF endpoints. |
| Vercel settings/env isolation/retention/usage/cost | not-applicable | No hosting target; no account enumeration or fabricated zero-cost claim. GitHub usage limitations are recorded below. |

## Hosted checks and release provenance

[PR #106](https://github.com/boommasterxd/transcriber/pull/106) produced inspected `main`. The [matching CI run](https://github.com/boommasterxd/transcriber/actions/runs/39227380793) checked out synthetic merge `ed421bf15bf0620d732f4afc6490d0fb4b662e74`, with base `e9e093e1f735e4dbae47ab711790c84344f2d8c1` and PR head `8312d874bfe770338f21ae3797e09fe7d3558f53`. Both the tested merge and squash commit have tree `66f407d479d981e3d1edb4b40189cee8d00449a5`, verified through GitHub's commit API.

The merge happened at 11:14:27 Europe/Berlin on 2026-10-19; Android finished at 11:15:44 and final `CI` at 11:16:03. Gitleaks/title had already passed. The PR description reports explicit user authorization; this review did not independently verify that historical instruction. The merge did not wait for all required checks, although the identical resulting tree subsequently passed. The configured admin bypass is intentional; successful later checks do not retroactively establish protected-check completion at merge time.

The eventual hosted run passed 645 Dart VM and 441 Flutter tests, with 150 executable sources covered at 94.03% lines/statements, 91.38% functions and 87.62% branches. These are separate measurements from this report's complete local Flutter invocation. The standalone JVM job and separate bundle step were intentionally excluded because Android fulfilled them.

## Executed local verification

All commands below passed using the pinned Flutter SDK, with synthetic tests and no production provider credentials. Temporary reports/bundle outputs were placed outside tracked source. Native tooling also generated normal ignored build/cache files.

| Check | Actual execution/result |
|---|---|
| Dependency resolution | `flutter pub get --enforce-lockfile`; no lockfile delta |
| Format / analysis | `dart format --output=none --set-exit-if-changed lib test tool`; `flutter analyze --fatal-infos --no-pub` |
| Full tests | `flutter test --no-pub --coverage --branch-coverage --coverage-path=<temporary-lcov> --reporter=expanded`; 1,086 passed |
| Coverage | `dart run tool/quality/check_coverage.dart <temporary-lcov>`; 150/150 executable sources, 94.00/94.00/91.25/87.53% |
| DCL metrics / custom checks | `dart run dart_code_linter:metrics analyze lib test tool --reporter=json --json-path=<temporary-json> --no-fatal-warnings`; `dart run tool/quality/check_code_quality.dart --metrics <temporary-json>`; passed with F3 limitation |
| Unused code/files | DCL `check-unused-code lib test tool --analyze-private-members` and `check-unused-files lib test tool`; none found |
| Duplication | Existing cached jscpd 5.0.16 executable, `--min-tokens 50 --threshold 0 --reporters console --format dart --ignore '**/*.g.dart' lib test tool`; zero clones |
| Workflows/shell | Pinned actionlint 1.7.12 with ShellCheck 0.11.0, all workflow files and `tool/package/*.sh tool/quality/*.sh`; passed |
| Kotlin/source length | `bash tool/quality/check_kotlin_quality.sh`; `node tool/ci/check-native-file-length.cjs`; passed |
| Standalone JVM | `android/gradlew -p tool/ci/jvm test --no-daemon`, JDK 17; tests and maintained-execution guard executed successfully |
| Android | `android/gradlew -p android :app:testDebugUnitTest :app:compileDebugAndroidTestKotlin --no-daemon`, JDK 17; successful, with cached test/compile tasks and execution-report guard |
| Asset bundle | `flutter build bundle --debug --no-pub --asset-dir=<temporary-directory>`; nonempty `kernel_blob.bin` and `AssetManifest.bin` verified |
| Independent CI regressions | 32 Node tests; 100% lines/functions, 99.21% branches. Additionally 186 focused Dart selector/runtime/coverage tests passed. These overlap the complete Flutter suite and are not additional unique application tests. |

Two bounded Sol reviewers independently collected GitHub evidence and examined CI selection/coverage; the latter also confirmed F3 and the scope of F5. The main reviewer verified effective ruleset settings, matching commit trees, hosted job outcomes and local check results. This was a setup review, not an invoked Codex Security scan or a legal/privacy assessment.

## Runner usage and remaining evidence

| Existing CI run | Summed job occupancy | Workflow elapsed |
|---|---:|---:|
| [39227380793](https://github.com/boommasterxd/transcriber/actions/runs/39227380793), matching source | 20 min 21 s | 11 min 10 s |
| [39225376496](https://github.com/boommasterxd/transcriber/actions/runs/39225376496) | 20 min 23 s | 11 min 14 s |
| [39175796408](https://github.com/boommasterxd/transcriber/actions/runs/39175796408) | 19 min 48 s | 10 min 14 s |
| [38784163535](https://github.com/boommasterxd/transcriber/actions/runs/38784163535), preselection baseline | 24 min 46 s | 10 min 12 s |

These are existing start/end measurements, not a controlled experiment: revisions, cache state and scope differ. The matching run's timing API returned `UBUNTU.total_ms=0`; it does not establish zero account cost. Included minutes, invoices, shared budgets and attributable billed usage were not inspected. [GitHub billing rounds jobs separately](https://docs.github.com/en/billing/reference/actions-runner-pricing), so lower runner rates or occupancy alone do not establish monetary savings.

Remaining evidence requires a representative hosted docs-only path and Slim runs, actual device/instrumented and manual accessibility checks, release signing/installation evidence, and any separately scoped performance measurements. [Flutter's release checklist](https://docs.flutter.dev/ui/accessibility) specifically calls for screen-reader, contrast, target-size and scaling checks; existing widget semantics assertions cover only part of that work. No provider verdict, publication or full conformance is claimed from local mocks, a compiled device suite or a debug asset bundle.
