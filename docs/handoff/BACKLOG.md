# Implementation backlog

Prepared October 30, 2026. All native work packages are unassigned.
Use these identifiers in pull requests and test reports. Do not mark a package done from scaffolding alone.
M01–M24 refer to the [native acceptance checklist](../specs/0002-first-native-mvp.md#11-acceptance-checklist).

## Work packages

| ID | Suggested owner | Depends on | Deliverable | Acceptance coverage | Status |
| --- | --- | --- | --- | --- | --- |
| WP-00 | Integration lead | None | Generate project, compile shell, run core and UI tests, record toolchain and signing setup | Foundation for all checks | Ready; source scaffold exists, macOS verification pending |
| WP-01 | Camera lead + storage lead | WP-00 | Physical capability probe, first DNG, neutral decode, frozen configuration and service contracts | M02, M11; baseline for M22 | Probe source and service contracts prepared; device verification pending |
| WP-02 | Camera engineer | WP-01 | Live preview, permission flow, lifecycle, readiness, one-shot onscreen and hardware capture | M01, M04, M05, M19 | Not started |
| WP-03 | Interface engineer | WP-00; final geometry needs WP-01 | Native Grip, landscape layouts, grid, stable feedback, accessible controls | M03, M10, M21 | Shell exists; native behavior not implemented |
| WP-04 | Persistence engineer | WP-01 | Metadata codec, durable order reservation, commit, index, recovery, save retry and discard | M11, M12, M13, M14, M15 | Metadata codec and order reservation prepared in SlitCore with tests; commit, index, recovery, retry, and discard not started |
| WP-05 | Camera engineer | WP-02 | Tap focus, long-press lock, stale-operation protection, compensation and restoration | M06, M07, M08, M09 | Logical token helper exists; hardware work not started |
| WP-06 | Review engineer | WP-03, WP-04; decoder verified in WP-01 | Previews, ordered review, detail, return, original sharing | M16, M17, M18 | Not started |
| WP-07 | Integration lead | WP-02, WP-03, WP-04, WP-05, WP-06 | Complete capture-to-commit-to-review flow, late callbacks, capacity and error recovery | M04, M05, M08, M12, M13, M15, M17, M19, M20 | Not started |
| WP-08 | Quality/performance engineer | Instrumentation can start at WP-01; full runs need WP-07 | Fault injection, local diagnostics, memory/thermal behavior, frozen gates and measured results | M20, M22, M23, M24 | Diagnostics event model, rotation policy, and report tooling prepared; device instrumentation and gate freezes not started |
| WP-09 | Release owner + product owner | WP-07, WP-08 | All acceptance evidence, field walk, installable internal build, limitations and handback | M01–M24 | Not started |

## WP-00: establish a build baseline

Run every command in SETUP.md. Fix generation, compilation, and test failures before camera work starts.
Select a team-owned bundle identifier and record exact Xcode, SDK, Swift, and XcodeGen versions.
Replace this host's Not run entries with evidence from the receiving Mac.
Do not mark the camera functional because the shell launches.

## WP-01: remove device uncertainty first

Probe only the physical rear main camera.
Save one real Bayer DNG and verify its dimensions and neutral decoding on the target phone.
Record autofocus, focus-lock support, exposure range, readiness, and hardware input phases.
Choose the raw format and dimensions without assuming 48 megapixels.
Measure an initial capture/save loop before implementing optional preview work.
Freeze identity, order reservation, metadata, result events, and ownership with the persistence engineer.
If raw capture is unsupported or impractical, document the evidence and return the format decision to the product owner.

## WP-02 through WP-06: feature implementation

Each owner implements the relevant specification sections and fault cases, not just the happy path.
Camera work keeps capture delegates alive and disables input outside capture.
Persistence work injects failures at write, close, rename, and index boundaries.
Interface work keeps controls outside the image and preserves the return/shutter position in every orientation.
Focus work demonstrates cancellation and timeout behavior under real session interruptions.
Review work reports the actual inspection resolution and preserves originals on every preview failure.

Each pull request includes relevant acceptance IDs, automated checks, device evidence where needed, and remaining gaps.
Use [the decision template](templates/decision.md) for changes to defaults or contracts.

## WP-07: integrate before polishing

Exercise concurrent capture, saving, preview generation, and review transitions.
Prove that callback order cannot reorder the library.
Prove that save failure retains capacity and that retry uses the same bytes and identifier.
Prove that returning from review cannot create another exposure.
No new capture modes or rendering profiles enter this package.

## WP-08: define performance from evidence

Record 20 cold starts, 20 warm resumes, and at least 100 accepted captures.
Run the specified one-per-second and two-per-second attempt sequences.
Report accepted, rejected, failed, and committed counts separately.
Freeze startup, resume, cadence, accepted-fraction, backlog, and storage reserve gates before acceptance runs.
Record grid-on/off and preview-active/idle comparisons under equivalent conditions.
Never silently lower the accepted-fraction gate to hide rejected moments.

## WP-09: internal handback

Verify all 24 acceptance checks on the primary physical phone.
Add the app icon and required internal distribution assets.
Record battery/thermal observations and unresolved visual or ergonomic concerns from a real street session.
Deliver source, an installable internal build, capability report, acceptance report, performance report, and known limitations.
Do not publish an App Store release or add the monochrome milestone.

## Suggested team schedule

First complete WP-00 and WP-01 together.
Then run interface, persistence, and camera work in parallel with agreed contracts.
Review implementation can begin against synthetic committed metadata after the storage contract is frozen.
Merge small vertical slices through WP-07 rather than combining all features at the end.
Do not invent deadlines before the team measures device and signing constraints.
