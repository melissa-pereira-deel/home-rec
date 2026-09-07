# Home Rec — app, roadmap and development review

Reviewed 5 September 2026. Three agents independently reviewed architecture, product priorities, and security/testing; the coordinating review reconciled their findings with GitHub and local checks.

**Recommendation: keep the native architecture and make recording integrity and release evidence the next milestone.** The app already has useful abstractions, thoughtful recovery behavior and substantive tests. Its main risks are at the boundaries between capture, saving, error handling, update installation and the final signed product. Adding pause or live monitoring before tightening those boundaries would increase complexity in precisely the weakest area.

This is an assessment and proposed backlog. No app code, repository settings, release assets or production deployments were changed. Reports are outside the cloned repository.

## What was reviewed

| Item | Verified state |
|---|---|
| Local source | Fresh clone of `melissa-pereira-deel/home-rec`, `main` at `2f9c42dd92dad72cb7e1d29ce555c2ee48967e53` |
| Published release | [v1.1.1](https://github.com/melissa-pereira-deel/home-rec/releases/tag/v1.1.1), published 22 August 2026, tag at `c877b37c12b7c33014360393684e1de845c98ca9` |
| Source versus release | Main has one later change to release-note generation in the DMG script. This does not establish whether the separate production appcast has already adopted it. |
| Current GitHub work | No open issues or pull requests returned by the GitHub API |
| CI | [Latest main run succeeded](https://github.com/melissa-pereira-deel/home-rec/actions/runs/32596545545): functional tests and independent Release build are configured |
| Merge enforcement | Repository rulesets returned `[]`; main protection endpoint returned `Branch not protected` |
| Local verification | Xcode 26.4 unsigned unit suite: 300 tests passed, zero failed, one skipped; 325 successful executions including parameterized cases |
| Documentation check | Reproduced exit 1 on this fresh clone because `CLAUDE.md` is required but ignored |
| Roadmap limits | Public README, changelog and acceptance history reviewed. The private backlog, strategy and agent instructions are deliberately excluded; their location was requested but unavailable for this report. |

No live microphone/system recording, production installation, signing-key inspection or audit of the separate website repository was performed. Static findings identify real control-flow gaps; timing-dependent consequences still need targeted reproduction. Existing green tests do not disprove paths that their fixtures do not exercise.

## App and architecture assessment

Home Rec’s purpose is narrow and coherent: capture what the Mac, a selected app or a microphone produces, save it locally, and make that process easy to trust. WAV, FLAC and M4A, background/menu-bar recording, permission guidance, recovery and Sparkle updates are already implemented. Monitoring has an unwired implementation; it is not a finished feature. Mic plus system mixing is deliberately out of scope.

The implementation is SwiftUI with AppKit for windows and menu-bar integration. A shared view model renders recording and permission state. A recording controller coordinates a capture source, normalization and the encoder; preferences are local and recordings are ordinary files. There is no product need here for a backend or a broad rewrite.

| Decision | Assessment and next action |
|---|---|
| Native Apple capture and UI | Fits low setup and a small dependency surface. Keep it; validate OS/device boundaries with real hardware. |
| Canonical PCM before encoding | A good contract for differing device rates and channels. Test continuity and decoded signal, not just format headers. |
| Injected capture, storage, permission and clock interfaces | Good foundations for deterministic failure tests and simulated UI. Extend these seams instead of introducing a generalized framework. |
| Serial encoding queue | Appropriate for current throughput. Make ownership explicit, completion asynchronous and queue growth bounded. |
| WAV checkpoints and format-specific recovery | A meaningful differentiator. Strengthen active-file exclusion, long-file handling and process-interruption evidence. |
| Vendored design system with provenance | Reasonable for this app; make its existing drift check a reproducible gate. Avoid unrelated visual redesign. |
| Default MainActor inference with Swift 5 language mode | Helpful but insufficient proof of cross-queue safety. Adopt strict checks incrementally with explicit ownership. |
| Unsandboxed distribution | Preserve the working configuration during reliability work. Its necessity was not independently proven; investigate narrowing privileges separately with compatibility evidence. |

The most useful structural change is a **small recording-session owner**. It should own a session ID, source, format, output URL and all resources from acquisition through finalization. The view model can display an error immediately while that owner still blocks restart, repair, update and quit until cleanup completes.

## Most consequential findings

| Priority | Finding and practical impact | Required proof of a fix |
|---|---|---|
| P1 | Stream failure presents `.error` before asynchronous cleanup finishes. Error state permits restart/update, creating a window where teardown can overlap a new take or relaunch. | Hold teardown pending in a fake, request retry/update, and prove neither proceeds until the old session releases its resources; ignore late old-session callbacks. |
| P1 | Failed setup/start does not roll back an already opened encoder; a thrown capture-stop error bypasses subsequent finalization. | Inject failure at each acquisition/teardown stage; preserve captured audio, close resources and successfully start again. |
| P1 | The recording path swallows encoder write errors with `try?`; waveform movement can continue when saving fails. | An encoder that fails after N buffers produces one visible error and preserves the partial take. Assert accepted frames and decoded output. |
| P1 | `main` is currently unprotected. Passing CI on today’s commit does not require it on tomorrow’s change. | Enforce PRs and the existing functional/Release checks, restrict bypass authority and verify the effective rules. |
| P1 | Unsigned tests intentionally skip the signed-entitlement assertion; general signature checks do not verify every production requirement. | Verify identity, required entitlements, hardened runtime, feed/key, versions and architectures in the exact app inside the final DMG. |
| P1/P2 | Recovery excludes files using the narrow recording flag; starting/stopping/error cleanup can still own a file. Ordinary Quit has no explicit finalization drain. | Guard owned files at discovery and mutation; finalize safely before normal termination. |
| P2 | WAV has unchecked UInt32 accounting around its approximately 4 GiB / 6 h 13 min limit. Recovery loads whole files; finalization can block the UI. | Boundary tests without multi-hour fixtures; controlled stop or segmentation; bounded-memory off-main repair and asynchronous finalization. |

These are priorities for preventing lost or misleadingly successful recordings, not claims of an observed exploit. Exact source locations, reasoning and limits are in the [architecture report](</Users/melissadebritto/Desktop/The Building Blocks Co./Home Rec/home-rec-review-architecture.md>).

The release review also found two specific weaknesses worth fixing early. `staging-feed.sh` copies a supplied enclosure URL unchanged; an item produced by the release script therefore continues downloading from GitHub unless manually rewritten, bypassing the local throttling experiment. Separately, release signing selects the first Sparkle signing tool in global DerivedData and can continue without the key-identity check when its companion tool is absent. Resolve tools from the locked dependency in a dedicated build directory and make identity verification mandatory. The [security/testing report](</Users/melissadebritto/Desktop/The Building Blocks Co./Home Rec/home-rec-review-security-testing.md>) provides evidence and acceptance criteria.

## Proposed backlog order

This ranking is based on observed implementation risk and product fit. It is provisional until reconciled with the private backlog and actual user requests. Sizes below are relative scope, not delivery estimates.

| Order | Work package | Scope | Dependency / completion criterion |
|---|---|---|---|
| 1 | Establish merge gates and fresh-clone agent instructions | Small | Required existing CI checks; tracked non-sensitive `AGENTS.md`; working docs check; explicit private-context access path. |
| 2 | Make session acquisition and teardown transactional | Medium | Fault injection covers every stage; retries, updates, quit and recovery obey resource ownership. |
| 3 | Surface write failure and prevent invalid long takes | Medium | Depends on session cleanup; synthetic mid-write failure and WAV boundary tests pass. |
| 4 | Verify the packaged release and repair staging rehearsal | Medium | Final-DMG verifier, locked signing tools, local payload actually throttled, updater continuation tested directly. |
| 5 | Publish accurate roadmap/version/permission guidance | Small | Distinguish released, implemented and experimental; remove Sparkle from “next”; correct mic denial guidance. Can run alongside 2–4. |
| 6 | Add meaningful UI, crash and hardware evidence | Medium | Reuse existing fakes; cover critical journeys and decoded audio on a dedicated test Mac. |
| 7 | Bound finalization/recovery work and enforce concurrency | Medium | No main-thread save stalls; bounded resource policy; reliable app-owned race checks block regressions. |
| 8 | Improve source/settings discovery and keyboard accessibility | Small–medium | Complete record/stop/source/recovery with keyboard and assistive technology; preserve the compact UI. |
| 9 | Validate monitoring as a bounded experiment | Medium, uncertain | Real latency, feedback and device-change checks; a monitoring failure cannot damage the recording. Ship only after evidence. |
| 10 | Decide pause/resume and MP3 using demand | Separate increments | Pause requires stable session ownership and continuity checks; MP3 requires an encoder capability spike, cancellation/storage policy and preservation of the original take. |

Do not assume the README’s proposed MP3 API proves platform support. Verify the actual encoding path before scheduling the feature. Likewise, a full Preferences window should follow a demonstrated settings problem rather than be a prerequisite for keyboard shortcuts.

Opportunities with a stronger immediate fit than more formats include honest recording health, clearer “saved” confirmation, discoverable recovery and better source selection. Use opt-in issue templates and small qualitative beta checks to learn where people fail, without adding telemetry or accounts. Defer cloud storage, AI transcription, a mixer, plug-in architecture and monetization expansion unless the product brief changes. The [roadmap report](</Users/melissadebritto/Desktop/The Building Blocks Co./Home Rec/home-rec-review-roadmap.md>) expands the product rationale.

## Agent development and release workflow

Agents should have broad freedom to implement, test and assemble reviewable candidates, with release authority isolated by credentials and repository rules. A prompt telling an agent to be careful is not a credential boundary. This review’s desktop context does not establish such isolation already exists.

1. **Make each task executable.** A short task packet records the user outcome, affected modules, acceptance evidence, constraints and owner. Public technical invariants belong in `AGENTS.md` and short decision records. Keep private strategy private; supply only the needed approved context. The tracked pre-commit hook exists, but activation is local and bypassable, so mirror enforceable checks in CI.
2. **Use bounded parallel work.** Give agents separate worktrees, derived-data paths and explicit file ownership. Parallelize independent UI/docs/test work; serialize overlapping changes to the session owner, Xcode project, entitlements and release scripts. An independent agent should review the integration against the task’s acceptance criteria.
3. **Keep development unprivileged.** Use synthetic recordings, unsigned builds and a scoped GitHub identity without rule-bypass authority. Signing keys, production feed credentials and personal recordings should be unavailable to development execution. Do not run untrusted PR code on a persistent signing Mac.
4. **Prepare one identified candidate.** Build a reviewed commit in a dedicated environment and record commit, toolchain, dependency revisions, app identity, versions, artifact digest and test results. Sign/notarize there under an explicit release authorization policy. Verify the app inside the final DMG and use those exact bytes for testing and publication.
5. **Promote with narrow authority.** Prepare the release metadata and matching feed change before approval. The authorized release step promotes the identified artifact rather than rebuilding something different. The website feed is in another repository, so its permissions, preview checks and production promotion need a matching contract.
6. **Verify and retain rollback evidence.** Check the published asset and feed agree on version, digest, signature and URL. A bad rollout requires addressing the appcast as well as the GitHub release; publish a higher-version fix for already updated clients. Do not rely on lowering version numbers or changing old bytes in place.

For GitHub automation, declare least-privilege token permissions and pin actions to reviewed commit SHAs. GitHub specifically cautions about untrusted work executing on persistent self-hosted runners. These controls support the separation above. [GitHub secure-use guidance](https://docs.github.com/en/actions/reference/security/secure-use).

Protected environments can restrict deployment refs and withhold secrets pending authorization. For a solo maintainer, use an explicit maintainer-controlled promotion step rather than requiring a second human who does not exist. Configure exact allowed refs; “protected branches only” is insufficient while no branch is protected. [GitHub environment controls](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments).

Keep Apple signing/notarization and Sparkle update signatures as separate verification obligations. Sparkle’s signature and enclosure size must describe the actual distributed archive. [Sparkle publishing guidance](https://sparkle-project.org/documentation/publishing/).

## Testing capability plan

| Layer | What to add or strengthen | When it should gate |
|---|---|---|
| Fast deterministic checks | Session fault injection, late callback handling, encoder rejection, updater callback exactly once, ownership/quit, size boundaries | Every relevant PR |
| Repository checks | Clean-clone docs, vendor drift, secret patterns with narrow public-key allowance, dependency lock, release-script fixture tests | Every PR, with path-aware expensive work |
| Concurrency | Blocking reliable app-owned TSan subset; separately reported framework/codec quarantine with an owner and exit criterion | Relevant PRs; currently all TSan errors are advisory |
| UI behavior | Test-only fake permissions/capture/storage; onboarding, denied mic, record/stop, source selection, recovery and keyboard navigation | Relevant PRs; current UI tests are launch templates |
| Durability | Subprocess termination at known encoder checkpoints; malformed recovery files; disk/write failures; independent decoded signal checks | Relevant PRs and candidate verification |
| Signed product | Exact-bundle identity, entitlements, feed/key/version and architectures; notarization/Gatekeeper evidence | Every release candidate |
| Hardware / OS | Fresh/denied/revoked permissions; 44.1/48 kHz and mono/stereo mic; device removal; per-app isolation; sleep/wake; update during capture | Relevant candidates on a dedicated test environment |

Keep the strong existing golden-file and encoder tests. Expand measurable frequency, amplitude, channel and duration assertions; a file existing, a timer advancing or a waveform moving is insufficient evidence of a successful take. The existing mic-rate verification script is a useful starting point.

Publish test pass/fail/skip counts and artifacts. Treat “test never ran” as a failure of evidence. Retain UI renders as review aids but do not equate an opt-in screenshot generator with a visual regression test. Measure escaped recording defects, flaky reruns and time from reviewed commit to verified candidate; coverage percentage alone will not show whether this workflow protects users’ audio.

## Verification addendum

The coordinating review ran the full unsigned unit target successfully on Xcode 26.4 after allowing dependency access and Xcode services. Xcode reports **301 tests: 300 passed, zero failed, one skipped**. Parameterized cases produced 325 successful executions. The skipped test is `InfoPlistTests/microphoneEntitlementIsInTheProduct()`, expected for an unsigned host. This directly illustrates why a separate signed-product gate matters.

The run used an Apple Silicon Mac Studio on macOS 26.6.2. It does not establish Intel or minimum-supported-macOS runtime behavior, hardware capture, UI acceptance, Thread Sanitizer cleanliness or production-artifact correctness. The result bundle is `/private/tmp/home-rec-review-functional-retry.xcresult`; the build/test log is `/private/tmp/home-rec-review-test-retry.log`. The documentation check failed as described above. The cloned repository remains clean on `main`. No production signing, live capture or security setting changes were performed.
