# T015 local verification

Date: October 30, 2026. Scope: Round 1, WP-08 preparation (T015).
Host: Linux 6.8.0-147-generic, x86_64. Python: 3.12.3.
No Swift toolchain, Xcode installation, simulator, or primary phone exists on this host.

## What this task delivers

Portable diagnostics preparation only, not live-app wiring:

- A platform-independent event model in SlitCore with an injected clock.
- A pure bounded-rotation policy over an in-memory index plus a store protocol.
- An export model that starts only from the user's Share diagnostics action.
- Report tooling: `scripts/diagnostics-report.py` and the deterministic
  generator `scripts/diagnostics-fixture.py`.
- Swift tests written for the swift-testing framework; not executed here.

New sources: `DiagnosticsClock.swift`, `DiagnosticsEvent.swift`,
`DiagnosticsRecorder.swift`, `DiagnosticsRotation.swift`, `DiagnosticsExport.swift`.
New tests: `DiagnosticsEventTests.swift`, `DiagnosticsRecorderTests.swift`,
`DiagnosticsRotationTests.swift`, `DiagnosticsExportTests.swift`.

## Check results

| Check | Result |
| --- | --- |
| `make check` | PASS, exit 0; portable files, Python and shell syntax, JSON, links, acceptance coverage, task ledger, and workflow YAML |
| Handoff manifest freshness | WARNING: `dist/HANDOFF-MANIFEST.json` lists stale hashes for files other workers changed in parallel. `make check` still exits 0. Regeneration is the coordinator's step; this task changed no file the manifest policy covers beyond the additions below |
| `git diff --check` | PASS, exit 0; no whitespace errors |
| `python3 -m py_compile scripts/diagnostics-report.py scripts/diagnostics-fixture.py` | PASS |
| `python3 scripts/diagnostics-fixture.py .../diagnostics-fixture.jsonl` | PASS; 221 deterministic synthetic events, 42,952 bytes |
| `python3 scripts/diagnostics-report.py .../diagnostics-fixture.jsonl` | PASS, exit 0; output recorded below |
| Report tool `--json` mode | PASS; identical counts and percentiles |
| Report tool on malformed input | PASS; blank line skipped, malformed line counted, unsupported schema version counted, run continues |
| Report tool on a missing file | PASS; message on stderr, exit 1 |
| Fixture wire-key parity | PASS; every fixture key, including nested configuration keys, is inside `DiagnosticsEvent.wireKeys`, with no extra and no unused key |
| `make test-core` | NOT RUN; no Swift executable on this host |
| `make build`, `make test-ios` | NOT RUN; they require macOS and Xcode |
| Physical M22 and M24 evidence | NOT RUN; needs the integrated app and the primary phone |

## Recorded tool run

Command: `python3 scripts/diagnostics-report.py docs/handoff/reports/2026-10-30-t015/diagnostics-fixture.jsonl`

```text
Source: diagnostics-fixture.jsonl
Lines parsed: 221; malformed skipped: 0; unsupported skipped: 0

Duration measurements in milliseconds (monotonic)
Metric | Count | Unavailable | Median | 95th percentile | Min | Max
--- | ---: | ---: | ---: | ---: | ---: | ---:
Cold start to eligible shutter | 8 | 1 | 1242.2 | 1492.4 | 829.9 | 1492.4
Warm resume to eligible shutter | 8 | 0 | 437.9 | 691.4 | 314.9 | 691.4
Request overhead | 40 | 0 | 23.0 | 43.2 | 6.2 | 45.9
Acceptance feedback | 40 | 0 | 59.4 | 91.1 | 21.3 | 93.6
Callback latency (proxy) | 30 | 0 | 165.1 | 387.4 | 67.0 | 389.1
Storage latency | 30 | 0 | 1194.0 | 1662.5 | 441.5 | 1698.3
Backlog drain | 8 | 0 | 1689.5 | 2569.0 | 921.5 | 2569.0

Callback proxy latency by phase, milliseconds
Phase | Count | Median | 95th percentile
--- | ---: | ---: | ---:
didFinishCapture | 10 | 148.9 | 375.9
didFinishProcessingPhoto | 10 | 110.8 | 370.1
willCapture | 10 | 253.8 | 389.1

Application-observed attempts
Observed: 36; accepted: 31; rejected: 5; accepted fraction: 0.861
Rejection category | Count
--- | ---:
inactive | 2
outputUnavailable | 2
storageBlocked | 1
Input source | Observed attempts
--- | ---:
hardwarePrimary | 3
hardwareSecondary | 3
onscreen | 30
Failure code | Count
--- | ---:
captureFailed | 1
previewFailed | 1
saveRetained | 1

Context and resource use
Thermal states: {'fair': 2, 'nominal': 2, 'serious': 1}
Peak memory bytes: 238359762
Peak preview stalls: 3
Peak pending saves: 2
Slot limit: 2; peak occupied slots: 2

Application-overhead gates (informational)
requestOverhead: 95th percentile 43.2 ms is within the gate at most 50 ms
acceptanceFeedback: 95th percentile 91.1 ms is within the gate at most 100 ms

Medians use the mean of the two middle values; percentiles use the nearest-rank method.
Statistics only. Not device evidence.
```

Every number above comes from the seeded synthetic
[fixture](diagnostics-fixture.jsonl). The numbers are not measurements of any
device. The gate lines compare synthetic percentiles against the specification
gates to exercise the comparison path only. The fixture deliberately uses fewer
samples than the specification's measurement counts. Real runs must keep the
full counts: at least 100 accepted captures for capture timing and 20 runs for
each startup measurement.

## What cannot run on this host

The Swift sources target Swift 6 with strict-concurrency-safe value types and
protocol abstractions. They were never compiled. Possible compile errors,
swift-testing discovery problems, and Linux Foundation differences remain
possible until the Mac baseline in T003 runs `make test-core`.

No privacy manifest change is included. The App-side store and clock
implementations, plus the required-reason API audit, belong to the integration
task that wires diagnostics into the live app.

## Files added by this task

| File | Content |
| --- | --- |
| `Packages/SlitCore/Sources/SlitCore/DiagnosticsClock.swift` | Injected clock, instant, duration, stopwatch, manual test clock |
| `Packages/SlitCore/Sources/SlitCore/DiagnosticsEvent.swift` | Closed event model, wire keys, JSON Lines codec |
| `Packages/SlitCore/Sources/SlitCore/DiagnosticsRecorder.swift` | Sequence assignment and typed event factories |
| `Packages/SlitCore/Sources/SlitCore/DiagnosticsRotation.swift` | Bounded rotation policy, pure planner, store protocol |
| `Packages/SlitCore/Sources/SlitCore/DiagnosticsExport.swift` | User-actioned export trigger and planner |
| `Packages/SlitCore/Tests/SlitCoreTests/Diagnostics*Tests.swift` | swift-testing tests for the above |
| `scripts/diagnostics-fixture.py` | Deterministic synthetic fixture generator |
| `scripts/diagnostics-report.py` | Counts, medians, and 95th percentiles per metric |

No existing file was modified. Rotation and accounting rules are recorded in
the [rotation decision](decision.md).

## Execution update, October 30, 2026

The full SlitCore suite was compiled and executed on this Linux host with
Swift 6.4.2 (`/tmp/swift-dist`): 17 XCTest tests and 62 swift-testing tests
passed with 0 failures, including the 33 diagnostics tests written for this
task. The report tool was re-run against the regenerated fixture. App-side
wiring, the real clock, and the segment store remain future work; the macOS
run in T003 is still required for the app targets.
