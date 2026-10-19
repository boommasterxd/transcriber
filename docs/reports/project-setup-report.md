# Project Setup Report

## Assessment

**Partial conformance: F2 remains, with hosted Kotlin CodeQL verification pending.** Repository secret scanning and push protection are enabled; fork approvals use the public-profile policy. External pull requests are now accepted, matching README guidance. The two source duplicates are corrected. Some workflow changes still select insufficient CI; the owner requested an explanation rather than a change for that point.

After the source correction, fresh local verification passed 1,235 Flutter tests and full coverage, formatting, analysis, size/complexity/parameter enforcement, unused-code checks and jscpd with zero clones. The earlier native Gradle, dependency-audit and full-history scan results below remain qualified evidence for unchanged inputs. Local success does not establish current hosted application CI, device behavior or complete setup conformance.

## Authorized follow-up

| Control | Before | Applied result / evidence |
|---|---|---|
| Repository secret scanning / push protection | Both disabled | Both enabled through the repository API and independently read back. No visibility, paid feature or credential change. |
| Fork workflow approval | `first_time_contributors` | `all_external_contributors`, changed through the Actions API and read back. |
| Pull-request admission | `collaborators_only` | `all`, explicitly authorized, changed through the repository API and read back. Repository interaction-limit response is empty; account-wide interaction readback lacks `read:user` permission. |
| CodeQL | Not configured | Default setup enabled; successful hosted JavaScript and Actions analyses. Initial Kotlin autobuild failed and GitHub excluded Kotlin. A single advanced configuration is prepared locally to replace default setup when published; hosted Kotlin analysis remains pending. |
| Duplication | Two clones at the zero threshold | Shared `ModelCatalogListing` reuses the existing catalog filter, and tablet deletion calls the existing shared confirmation directly. Unchanged jscpd gate passes with zero clones. The lifecycle fixture explicitly types its common provider interface. |

The [initial CodeQL validation run](https://github.com/boommasterxd/transcriber/actions/runs/39256383026) completed after adjusting the configuration to exclude the failed Kotlin language. Its green overall result does not prove Kotlin coverage. The successful JavaScript analysis reports no alerts; Actions analysis reports two `actions/missing-workflow-permissions` alerts for the existing APK-build and release-build jobs. Those newly surfaced warnings are outside the requested source corrections and remain open. Native secret scanning also reports one historical Google-key alert matching an already documented unusable-key fingerprint; validity remains `unknown`, and the alert was not dismissed.

## Target and applicability

| Item | Inspected value |
|---|---|
| Review date / standard | 2026-10-19; coding-tools 0.30.0 setup contract through that date, effective user instructions and root `AGENTS.md` |
| Repository | [boommasterxd/transcriber](https://github.com/boommasterxd/transcriber), default branch `main` |
| Requested / current visibility | No change requested; current visibility is `public`, so the public profile applies |
| Owner / account plan | Personal account (`User`); plan omitted from authenticated/public account readback and remains unverified |
| Contribution policy / license | Effective `all`, matching README contribution guidance; MIT license in `LICENSE` and repository metadata |
| Source | Local and live `main`: `a17ff8c713e89bd945195f9dec2aa836bee0c018`; working tree initially clean |
| Report branch | `codex/project-setup-report-20261019` |
| Application | Flutter Android, arm64, Riverpod, on-device Drift/SQLite, personal OpenAI/Gemini keys |
| Verification runtimes | Flutter 3.47.7, Dart 3.13.5, Node.js 24.22.0, JDK 17 |
| Scope / authority | Initial review followed by authority to enable scanning, strengthen approvals, fix duplicates, accept external PRs, commit/push/open a PR and switch CodeQL configuration. No merge authorized. |

The npm baseline is adapted to native Flutter/Dart and Gradle interfaces. Node runs CI tooling only. The existing [cloud BYOK and Drift decision](../decisions/cloud-byok-and-drift.md) remains applicable. No Next.js application, Vercel target, server API or Turso integration is selected or configured in the inspected repository. On-device SQLite is not a cloud database intended for Turso; web hosting, browser-production-server checks and cloud migration hooks are inapplicable.

The prior setup, quality and performance reports were read in full and reconciled against current source and provider evidence. Superseded source findings are omitted; F2 retains its identifier for the surviving classification cause. Existing accepted decisions are scoped below. The follow-up changes source, the CodeQL workflow, related documentation and the named provider settings; publication and the CodeQL switch are explicitly authorized. No merge, manual workflow dispatch, deployment, visibility change or live inference request is authorized or performed. Enabling CodeQL itself triggered its normal provider validation run. This report's local results precede publication; the current PR checks provide subsequent hosted acceptance.

## Findings

### F2. Remaining workflow changes bypass full applicable CI

- **Expected:** global workflow/build/security configuration changes require all applicable checks, unless a narrow supported exception is documented.
- **Current:** [`detect-change-scope.cjs`](../../tool/ci/detect-change-scope.cjs), lines 44–45, assigns remaining workflow files only to workflow lint and dependency audit. Reproductions for `.github/workflows/build-apk.yml` and `.github/workflows/release.yml` return `dart=false`, `jvm=false`, `native=false`, `build=false`. Both workflows control Flutter dependencies/builds, signing or publication. No applicable accepted exception was found.
- **Impact:** changes to packaging/release controls can receive a successful final gate while application/native/build checks are intentionally excluded. The final gate correctly validates the supplied flags but cannot correct an insufficient classification.
- **Correction:** include global workflow changes in full classification and regression expectations; retain narrower scope only for concretely justified, documented exceptions. The earlier central-classifier/final-gate mapping is now correct and is not a current defect.

### F6. Kotlin CodeQL still requires activation of the prepared build workflow

- **Expected:** successful CodeQL analysis for supported maintained Kotlin as well as JavaScript and Actions.
- **Current:** default setup successfully analyzes JavaScript and Actions, but Kotlin autobuild fails at `android/settings.gradle.kts` because `android/local.properties` is absent. GitHub's adjustment removed Kotlin from the active language list. Repository secret scanning and push protection are enabled and are no longer departures.
- **Impact:** maintained Kotlin has no successful active CodeQL analysis; a green adjusted default-setup run must not be represented as complete language coverage.
- **Correction under verification:** [the advanced workflow](../../.github/workflows/codeql.yml) installs the pinned Flutter SDK/JDK, generates native configuration and manually recompiles Kotlin under CodeQL. Publication and replacement of default setup are authorized; successful hosted extraction and analysis remain to be checked on the PR. A source file alone does not establish active language coverage.

The exact configuration generation and forced Android compile passed locally, with all 135 tasks executed. This does not prove CodeQL extraction. The current [official support table](https://codeql.github.com/docs/codeql-overview/supported-languages-and-frameworks/) lists Kotlin through 2.4.20, whereas the project uses 2.4.21; that patch-version compatibility also remains unverified. No toolchain downgrade or source exclusion was introduced.

GitHub documents [public secret-scanning availability](https://docs.github.com/en/code-security/how-tos/secure-your-secrets/detect-secret-leaks/enable-secret-scanning) and [CodeQL analysis for Java/Kotlin](https://docs.github.com/en/code-security/concepts/code-scanning/codeql/codeql-for-compiled-languages). The repository is already public; this review neither requests nor performs a visibility transition.

## Control coverage

`verified` applies only to the evidence stated. Source, effective provider configuration, hosted execution and Android device behavior are separate layers.

| Control | Status | Evidence / limitation |
|---|---|---|
| Native stack, layout, localization and mirrored tests | verified | Existing Flutter/Android layout, localized catalogs, source-parallel tests and documented service/repository boundaries; no stack migration needed. |
| Project instructions and technical documentation | verified | Root instructions and architecture/configuration/operations/security/quality documents present; commands inspected against actual tools. |
| Recursive documentation index | verified | Bundled index validator passed for all 13 Markdown documents, one complete sorted root index; report path already indexed. |
| Framework-independent model/catalog values | verified | Current import inventory contains no Flutter/UI/state/presentation imports; Flutter appearance mappings remain in `core/theme`. No general automated architecture guard is claimed. |
| Flutter pin / locked dependency resolution | verified | `.fvmrc` 3.47.7; exact SDK resolution passed without lockfile changes. Default PATH still selects Flutter 3.44.8, so checks explicitly used the installed pinned SDK. |
| Node policy across jobs | verified | Seven project-Node jobs, six CI plus Gitleaks, select `24.x` and `check-latest: true`; no conflicting matrix/container/caller override found. Local version 24.22.0. |
| Resolved Node on current hosted workflows | unverified | Earlier successful run resolved 24.22.0 in five executed CI jobs; JVM was intentionally excluded. New Gitleaks setup and current revisions lack matching successful execution. |
| Node application/hosting engines | not-applicable | Node is tooling only, without an npm application or hosted runtime. |
| Formatting / fatal analyzer | verified | 366 files, no format changes; repository-wide `flutter analyze --fatal-infos --no-pub` passed after the lifecycle fixture's explicit interface type. |
| Size, complexity, nesting and parameters | verified | Fresh DCL/AST enforcement passed; complete formal-parameter traversal and malformed/missing metric regressions passed. Strict limits retained. |
| Unused Dart declarations / files | verified | Both DCL checks passed, including private members. |
| Kotlin metrics / formatting / file length | verified | Checksum-verified Detekt 1.23.8 CLI/plugin and native/shell length checks passed. |
| Zero duplication | verified | Unchanged jscpd 5.0.16, 50-token/zero-threshold command passes with zero clones after local corrections. |
| Complete Flutter tests / coverage | verified | Fresh 1,235 tests; 169/169 executable sources out of 176 maintained; 94.85% lines/statements, 92.81% functions, 88.25% branches. Documented measurement proxies remain. |
| Complete PR diff, renames and deletions | verified | Merge-base diff, NUL path handling, both rename endpoints and base/head graph snapshots; regressions passed. |
| Transitive / runtime / asset / shared-test selection | verified | Analyzer import/export/part graph, explicit logo/channel contracts, changed tests and conservative unresolved-impact fallback inspected and tested. |
| Global workflow fallback | drift | F2; central CI/quality controls and dependency/framework/security inputs otherwise retain full selection. |
| Bound plans / execution / selective coverage | verified | Stale/tampered plan rejection, nonempty execution reports and missing-source failure; selected coverage remains explicitly partial with unchanged thresholds. |
| Docs-only path / final `CI` gate | verified | Complete nonempty root-docs classification skips expensive work; unconditional final gate validates intentional skips and rejects failed/cancelled/missing/unexpected results. Local positive/negative regressions passed. |
| Hosted docs-only acceptance | unverified | No representative successful matching run identified in the inspected recent PR CI runs; no test PR or dispatch created. |
| Native and independent JVM checks | verified | Both Gradle paths passed with execution guards and strict source inventories/JaCoCo; some test/compile tasks reused up-to-date outputs. Counts and coverage below. |
| Flutter bundle / packaging configuration | verified | Fresh Android-arm64 debug bundle and nonempty kernel/manifest; arm64/SDK/signing configuration inspected. No AOT/release APK built. |
| Device integration / manual accessibility | unverified | Instrumented tests compiled, not executed. Real share, microphone, IME/editor, permissions, secure storage, TalkBack and keyboard release matrix remain device work. |
| Dedicated performance budgets | unverified | Existing debug microbenchmarks are qualified in the performance report; no device performance or blocking dedicated performance suite verified. |
| Fresh dependency audit | verified | OSV 2.7.0 passed online against Pub, Android and JVM lockfiles plus JVM verification metadata; no known findings reported. Overlapping inventories are not additive package counts. |
| Gitleaks detection / introduced history | verified | Default detectors cover all paths; three synthetic regressions, current directory and full 178-commit history scans passed. Pinned archive checksum matched. |
| Exact historical scanner exceptions | accepted-exception | Three immutable fingerprints for historical keys confirmed unusable by the owner; no general path/rule exemption. See decisions below. |
| Required names / freshness / merge rules | verified | Active [ruleset 6440831](https://github.com/boommasterxd/transcriber/rules/6440831): exactly `CI`, `gitleaks`, `Validate PR Title`; strict freshness, enforce on creation, squash-only and blocked deletion/non-fast-forward. Workflow/final job both named `CI`. |
| Review / bypass configuration | verified | Zero required reviews, extra unattributed approval enabled; sole bypass repository-admin role 5, `always`; no additional ordinary-user/bot bypass. |
| Current source hosted-check acceptance | unverified | Latest two integrations lack successful matching required checks; latest rollup contains only skipped Dependabot metadata jobs. Local tests do not substitute hosted acceptance. |
| Latest merge authority evidence | unverified | Latest merge description asserts a cost-based owner override; this review lacks independent trusted confirmation for that separate merge. Earlier confirmed one-time authority is scoped below. |
| PR-only CI / Gitleaks, no automatic post-merge duplication | verified | Application CI and Gitleaks remain PR-to-main/manual only. Prepared CodeQL push/schedule triggers are distinct supported-language analysis, not repeated application tests. Historical main-push CI predates the PR-only configuration. |
| Cancellation / caching / conditional work | verified | PR-scoped cancellation, runtime/lock/config-keyed dependencies, separate JVM cache and no reused coverage; Android fulfills JVM/bundle work without a duplicate runner. No browser/service install for native Flutter selections. |
| Runner selection / timeouts | verified | Nine lightweight jobs use Slim with 5/10-minute bounds; substantive quality/build on regular runners. Container-based OSV is a documented compatible-runner exception. |
| Actual Slim compatibility | unverified | Available successful executions predate the Slim source changes; skipped metadata jobs do not prove compatibility. |
| Action pins / upstream provenance | verified | Full-SHA enforcement active. Upstream tag/commit readbacks matched pins or inspected checksum/fail-closed fixes ahead of tags; all workflow roles present. |
| Five core workflow roles / additional automation | verified | CI, title, guarded Dependabot auto-merge, required Gitleaks and scanner updater; Flutter updater, independent audit and signed Android build/release adaptations also inspected. |
| Downloaded scanners / linters | verified | Gitleaks 8.30.1 and actionlint 1.7.12 archives matched committed hashes; ShellCheck 0.11.0 and Detekt used as pinned. No weakened checksum controls. |
| Dependabot schedule / auto-merge boundary | verified | Pub/Gradle/Actions weekly Monday 08:00 Europe/Berlin, ten PRs, minor/patch groups. Metadata-only actor/author/same-repo/no-fork guards, separate write job. npm-only auto-merge leaves actual ecosystems manual as documented. |
| Public profile / owner plan | unverified | Actual public visibility and personal ownership verified; account plan omitted by available readbacks. Public-profile availability does not depend on inferring a private plan. |
| Repository secret scanning / push protection | verified | Enabled and read back after the authorized change; one known historical unusable-key alert remains open, not silently dismissed. |
| Supported-language CodeQL | drift | F6: active JavaScript/Actions analyses succeeded; Kotlin was excluded after failed autobuild. Advanced manual-build configuration is prepared but unpublished. |
| Fork approvals | verified | API readback is `all_external_contributors`. Code-bearing PR jobs default to read-only permissions without signing secrets; private-only fork-settings endpoint inapplicable. |
| Outside-contributor PR admission | verified | Repository policy `all` and empty repository interaction limits. Account-wide limits cannot be read with the current token. |
| Hosted external-fork checks | unverified | No outside-contributor run created or approved to test admission/execution. Current source preserves read-only untrusted execution and metadata-only privileged jobs. |
| Review of scanner controls | verified | `docs/security.md` explicitly requires maintainer review of PR-modifiable workflow/scanner controls before external run approval and merge. Matching actual external review evidence remains unverified. |
| Public README / licensing / private reporting | verified | Contribution invitation now matches policy `all`; MIT license and `SECURITY.md` private reporting route present. Native private-vulnerability reporting disabled, with an existing alternative route. |
| Actions permissions / infrastructure | verified | Enabled, all Actions allowed, SHA pinning, default read token, workflow PR creation/approval enabled; no self-hosted runners, hooks or deploy keys. Required labels present. |
| Repository features / merge metadata | verified | Issues on; Projects/Wiki/Discussions/Pages off; auto-merge/head deletion on; merge/rebase/update suggestion off; `COMMIT_OR_PR_TITLE` / `COMMIT_MESSAGES`. |
| Dependabot security provider settings | verified | Alerts enabled; automatic fixes enabled and unpaused. Empty alert lists were not used to infer security-feature state. |
| Secrets / environments / retention / OIDC | verified | Four Android signing secret names only; no repository variables/Dependabot secrets. `release` has no secrets/variables/protection/branch policy. Retention 90 days/current maximum 90; default OIDC subject and no workflow token request. Native signing is the established stack adaptation. |
| Release signing / installation / publication | unverified | Both publication paths reject debug certificates before artifact release. No current signed-release/device installation/publication experiment performed. |
| On-device DB migrations / isolation | verified | Drift schema 4, bounded title backfill, transaction/legacy migration and v1/v2/v3 upgrade regressions in passing suite; synthetic databases only. No user database opened. |
| Cloud DB resources / tokens / environment migrations | not-applicable | Native on-device persistence; no shared Preview/Production database, Turso token or cloud deployment hook. |
| Vercel settings ownership / Git admission / regions / release gate | not-applicable | No selected or configured Vercel target; no provider configuration enumerated or changed. |
| App Router page/layout boundaries / initial data / ESLint enforcement | not-applicable | Native Flutter Android, without a Next.js server/client module split. |
| WebP assets / AVIF-WebP delivery | not-applicable | Next.js-scoped policy; bundled Android provider PNGs are not a departure from it. |
| Web accessibility / CSP / hydration / rendering / caching | not-applicable | No web UI or native production web server in supported scope; Flutter assertions do not establish manual Android accessibility. |
| Bot Management / API WAF rate limits / BotID | not-applicable | No hosted application API/form. Calls to external provider APIs are not application WAF endpoints. |
| Vercel environments / usage / cost assessment | not-applicable | No hosting target; no fabricated zero-consumption or hosting-savings claim. GitHub usage limits below. |

## Executed verification

Commands used the existing pinned Flutter SDK explicitly; the older default PATH SDK was not accepted for results. Temporary metrics, coverage, scanner logs and bundle outputs are outside tracked source. Standard ignored Flutter/Gradle caches were generated. No production provider credentials or user data were needed.

| Check | Actual result |
|---|---|
| `flutter pub get --enforce-lockfile` | Passed; `pubspec.lock` unchanged. |
| `dart format --output=none --set-exit-if-changed lib test tool` | Follow-up passed, 366 files, zero changes. |
| `flutter analyze --fatal-infos --no-pub` | Passed, no diagnostics. |
| DCL metrics plus `tool/quality/check_code_quality.dart --metrics <temporary-json>` | Passed, fresh measurements and complete parameter enforcement. |
| DCL unused-code/private-member and unused-file checks | Both passed. |
| `flutter test --no-pub --coverage --branch-coverage --coverage-path=<temporary-lcov>` | 1,235 tests passed. |
| `dart run tool/quality/check_coverage.dart <temporary-lcov>` | Follow-up 169/169 executable sources; 94.85/94.85/92.81/88.25%, thresholds 85/85/85/80 retained. |
| jscpd 5.0.16 package entrypoint with CI flags | Follow-up passed with zero clones; no threshold or exclusion changes. |
| Detekt and native/shell length checks | Passed; temporary CLI/plugin artifacts matched pinned SHA-256. |
| `android/gradlew -p android :app:testDebugUnitTest :app:verifyNativeCoverage :app:compileDebugAndroidTestKotlin --no-daemon` | Successful; 19 class reports, 73 tests; 250/256 tasks up to date. Verification/execution guards ran. LINE 848/859, INSTRUCTION 4634/4748, METHOD 169/176, BRANCH 492/568. |
| `android/gradlew -p tool/ci/jvm test verifyNativeCoverage --no-daemon` | Successful; six class reports, 23 tests; 4/7 tasks up to date. LINE 173/176, INSTRUCTION 840/849, METHOD 33/33, BRANCH 85/92. |
| `flutter build bundle --debug --no-pub --target-platform android-arm64 --asset-dir=<temporary-directory>` | Follow-up passed; kernel 89,026,264 bytes and asset manifest 261 bytes. Debug bundle is not release/AOT evidence. |
| Node helper regressions with 85/85/80 coverage gates | Independent reviewer: 34 passed, lines/functions 100%, branches 99.22%. |
| Focused Dart selector/runtime/metrics regressions | Independent reviewer: 155 passed; overlap complete suite and are not additional unique application tests. |
| actionlint 1.7.12 / ShellCheck 0.11.0 | All workflows, embedded shell and maintained shell scripts passed. |
| Prepared advanced CodeQL build | Native Flutter config generation and exact forced Kotlin compile passed; 135/135 tasks executed. Upstream CodeQL action v4.39.0 resolves to the pinned SHA. Workflow lint passed; hosted extraction remains unverified. |
| Provider security readbacks | Secret scanning/push protection enabled; fork approval `all_external_contributors`; default CodeQL active for JavaScript/Actions after Kotlin validation failure. |
| Gitleaks 8.30.1 | Three synthetic regressions, current-directory scan and full 178-commit history passed; exact historical exceptions retained. |
| OSV 2.7.0 online source scan | Passed four explicit Pub/Gradle/verification inventories; no known vulnerabilities reported. |
| Documentation index / report links / whitespace | Validated after integration; existing index rows already cover all affected documents. |

Dart statement/function coverage and native instruction/method metrics are the documented proxies in [code quality](../code-quality.md). Device suites were compiled, not executed. The separate native defect/skip/coverage mutation integrations were inspected and have prior qualified evidence in the quality report; they were not rerun by this review.

Two bounded Sol reviewers independently assessed GitHub provider/workflow evidence and CI selection/coverage. The main reviewer rechecked live rules, profile settings, current classification counterexamples, source imports, migrations and local results, then integrated this report. This was a setup assessment, not a Codex Security scan, legal assessment or comprehensive architecture audit.

## Decisions, provenance and remaining evidence

The owner-confirmed three historical unusable Google-key fingerprints remain an **accepted exception**. The exact immutable commit/path/rule/line scope and rationale are documented in [security](../security.md#historical-scanner-exceptions). Default detectors cover every path and later credentials; a synthetic regression verifies that the same credential in a later commit still fails. No key values, provider-authentication test, rotation or history rewrite were involved.

The earlier full-fix integration had explicit one-time authority to skip hosted CI and use the existing administrator bypass for cost. Preserve that historical scoped decision; it authorizes no future bypass and does not establish current hosted verification. The latest README/banner merge occurred at 12:38:03 Europe/Berlin on 2026-10-19. Its head and resulting squash commit have the same tree, `d8245e4131cfe899ab3e8b5de7737047e956124b`, but required `CI`, `gitleaks` and title checks are absent. Its description asserts separate owner authority; independent confirmation of that authority was unavailable in this review. Configured administrator bypass is intentional; unchecked merges must remain distinct from CI-verified ones.

The [earlier successful CI run](https://github.com/boommasterxd/transcriber/actions/runs/39227380793) tested synthetic merge `ed421bf15bf0620d732f4afc6490d0fb4b662e74`, before the current fixes and Slim configuration. Existing job durations sum to **20 min 21 s**; workflow elapsed time is **11 min 10 s**. These are different measures, not a controlled comparison or current-source acceptance. The timing API's `UBUNTU.total_ms=0` does not establish zero account cost.

[Standard hosted runner execution is free for public repositories](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job); storage, larger runners and other products need separate attribution. Slim still follows the setup resource policy and its [15-minute job limit](https://docs.github.com/en/actions/reference/runners/github-hosted-runners). Account invoices, included capacity, storage usage and shared budgets were not inspected. No monetary saving is claimed.

Remaining verification needs authorized publication/replacement of default CodeQL and successful Kotlin extraction, matching successful current PR checks, representative docs-only/Slim hosted execution, admitted collaborator-fork behavior and review of PR-modifiable scanner/workflow controls, actual Android device/manual accessibility checks, signed release installation, and separately scoped device performance measurements. No test PR, manual dispatch, deployment or source publication was created. Full setup conformance is not established.
