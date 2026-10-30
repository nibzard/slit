# Validation and handback

Use the [native specification](../specs/0002-first-native-mvp.md) as the acceptance source.
The browser prototype only validates an interaction proposal.

## Automated checks

| Command | Purpose | Limitation |
| --- | --- | --- |
| `make check` | Required files, Python and shell syntax, privacy plist, JSON, portable links, project.yml and workflow YAML structure, task-ledger structure, acceptance coverage, and handoff-manifest freshness | Does not compile Swift; YAML parsing needs PyYAML |
| `make test-core` | Admission limits, failure retention, hidden input, and stale focus operations | Does not test AVFoundation |
| `make build` | Generates and compiles the app for an iOS simulator | Does not verify physical raw capture |
| `make test-ios` | Grid persistence and explicit unavailable capture in the shell | Extend as native features become functional |
| `make verify` | Runs check, test-core, build, and test-ios in order | Stops at the first failure; requires native tools |

The UI test that expects a disabled shutter is a bootstrap check.
Replace it with explicit permission, readiness, and failure-state checks when WP-02 connects the camera.
Do not keep capture disabled merely to preserve that test.
Keep pure-state tests as regression coverage when connecting the platform services.

## Evidence to collect

Copy the templates into a dated directory under `docs/handoff/reports/`.
The [2026-10-30 local preparation record](reports/2026-10-30-t001/local-checks.md) tracks initial checks and missing evidence.
`make check` verifies that acceptance templates and dated acceptance reports contain M01–M24 once, in order.
Use a synthetic identifier for each run. Keep user photos outside the repository.

- [Capability report](templates/capability-report.md).
- [Performance report](templates/performance-report.md).
- [Acceptance report](templates/acceptance-report.md).
- [Decision record](templates/decision.md).

For each result record the app build, exact phone and operating system, Xcode/SDK, capture settings, and relevant workload.
Label callback timing as a proxy; do not call it exact exposure latency.
Record failures and missing evidence, including inconclusive results.

## Required fault injection

Inject failures during original write, metadata write, bundle rename, index update, and preview development.
Terminate before and after each commit boundary and rerun reconciliation twice.
Simulate late callbacks, two-slot exhaustion, focus completion after cancellation, and return-to-camera touch handling.
Confirm that repeated recovery does not duplicate originals or reuse durable order values.
Memory pressure must evict regenerable data before it loses delivered originals.

## Physical phone session

1. Confirm permissions, actual lens, 1× framing, raw dimensions, and focus support.
2. Run portrait and both landscape workflows, with and without the grid.
3. Photograph moving subjects with autofocus and a prefocus lock.
4. Exercise capture, review, detail, sharing, and return while saves or previews are pending.
5. Test backgrounding, interruption, screen lock, low storage, and failed-save recovery.
6. Run the performance sequences and inspect every resulting original.
7. Complete M01–M24 and record remaining limitations before internal handback.

## Completion rule

A work package is done only when its implementation and evidence satisfy its acceptance IDs.
A screenshot, a mock, or a successful simulator build cannot replace camera evidence.
The MVP is complete only after all 24 physical acceptance checks and the recorded numerical performance gates pass.
No automatic publication, email handoff, or App Store upload is part of this workflow.
