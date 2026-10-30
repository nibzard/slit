# T005 local verification

Date: October 30, 2026. Scope: Round 1, WP-01 source preparation.
Host: Linux. No accessible Swift compiler, Xcode installation, simulator, or primary phone was established.

## Results

| Check | Result |
| --- | --- |
| `make check` | PASS, exit 0 |
| `make test-core` | NOT RUN; Swift executable absent, make exit 2 |
| `make build` | NOT RUN; script requires macOS with Xcode, make exit 2 |
| `make test-ios` | NOT RUN; script requires macOS with Xcode, make exit 2 |
| `git diff --check` | PASS, exit 0 |
| Verification file snapshots | SHA-256 snapshots of all tracked and unignored files match before and after the checks |
| Generated artifacts | No tracked build artifacts found; probe export directory is ignored |
| Original core and UI tests | Preserved |
| New core tests | Written, not executed: durable ordering across sessions and retained-failure identity through retry |
| Physical M02 and M11 evidence | NOT RUN; assigned to T006 |

Static checks do not establish Swift compilation, concurrency correctness, or physical camera capability.
No sample photograph, generated project, signing file, or fabricated device result is committed.
No external service, database, or server was created. No cleanup registration was required.
The existing Looper input files and backlog are unchanged.

## Prepared outcome

The debug launch argument opens a physical-camera capability probe.
It reports connected capabilities and prepares real Bayer capture, byte comparison, and neutral development.
It records hardware phases and readiness observations without replaying rejected input.
It keeps a write failure's bytes for retry, using the same artifact identifier.
It reports decoder failures separately and keeps the original.

Shared contracts define identity, durable order reservation, requested and delivered metadata,
commit, retry, confirmed discard, reconciliation, and independent result events.
The [ownership decision](service-contract-decision.md) assigns the serial camera queue and storage worker boundaries.
The [probe report](capability-report.md) contains the device procedure and explicit unknowns.

## Existing follow-up work

| Task | Remaining outcome | Resume condition |
| --- | --- | --- |
| T003 | Compile and test the probe and contracts with the native toolchain; fix compiler or concurrency failures | T002 provides the Mac |
| T006 | Run the probe, inspect a real DNG and neutral image, verify focus and hardware behavior, measure and freeze configuration | T003, T004, and T005 complete |
| T007 | Implement the metadata codec, durable allocator, and their failure tests | T005 complete |
| T008 | Implement production bundle persistence, retry, discard, and reconciliation | T007 complete |

T005 completes source preparation only. WP-01 remains incomplete until T006 provides physical evidence.
