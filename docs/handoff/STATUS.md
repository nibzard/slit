# Bootstrap status

Prepared: October 30, 2026.

## Present

- Authoritative native MVP specification with 24 acceptance checks.
- Selected Grip prototype with optional grid and a portable offline HTML bundle.
- XcodeGen configuration for an iOS 18 app, UI test target, and shared Slit scheme.
- SwiftUI development shell with a persistent grid setting and disabled capture controls.
- Local SlitCore package with bounded capture admission and focus-operation invalidation.
- Normative capture.json version 1 field appendix in specification 0002 section 7.
- Portable capture metadata codec and durable order reservation with a persisted high-watermark contract.
- Portable diagnostics event model, bounded 5 MiB rotation policy, and a report tool for medians and 95th percentiles.
- Seventy-nine core tests covering admission, focus, capture contracts, the metadata codec, order reservation,
  and diagnostics. Seventeen use XCTest (twelve admission, five focus); sixty-two use swift-testing
  (two capture contracts, fifteen codec, twelve order reservation, thirty-three diagnostics).
- Two UI tests for unavailable capture and grid persistence.
- Camera permission description and a privacy manifest covering the shell's UserDefaults use.
- macOS scripts, a continuous integration workflow, portable checks, and a handoff archive script.
- Work packages and templates for capability, performance, acceptance, and handoff decisions.

## Not implemented

No session opens. No camera permission is requested by the current shell.
No photograph is captured, developed, committed, reviewed, or shared.
The shell's placeholder and disabled controls make this state explicit.

No production camera controller, original store, preview worker, or library service exists yet.
The metadata codec and order reservation are portable rules only; the storage service that persists them is T008.
The core types are not wired to a camera. They enforce a subset of the specification's rules only.
The shell uses a placeholder frame; native framing and orientation remain part of WP-02 and WP-03.
There is no app icon or distribution asset set. Add those before internal distribution in WP-09.

## Verification

| Check | Status |
| --- | --- |
| Portable repository checks | Passed; see [the bootstrap report](reports/bootstrap-verification.md) and [the T005 local checks](reports/2026-10-30-t005/local-checks.md) |
| Python syntax and shell syntax | Run during handoff preparation |
| Configuration YAML and privacy plist parsing | Run during handoff preparation |
| Swift compilation and core tests | Passed on this host with Swift 6.4.2 on Linux: 17 XCTest and 62 swift-testing tests, 0 failures; see [T007](reports/2026-10-30-t007/local-checks.md) and [T015](reports/2026-10-30-t015/local-checks.md). The macOS run in T003 is still required |
| Xcode project generation and simulator build | Not run: macOS, Xcode, and XcodeGen are absent |
| UI tests | Written, not run |
| Continuous integration workflow | Configured, not run remotely |
| Physical-device acceptance M01–M24 | Not run |

The first receiving developer must run the macOS build and tests before accepting the scaffold as a build baseline.
Fix any compile or generation issues in WP-00 and record the actual toolchain.
Do not treat static file checks as proof that the application builds.

## Remaining team inputs

- Assign named owners to the roles in the backlog.
- Supply an Apple development team, a unique bundle identifier, and an iPhone 16 Plus for testing.
- Select the team's repository remote and review process.
- Agree on numerical device-dependent performance gates after the capability baseline.
- Choose any distribution license separately; no third-party camera code was copied into the scaffold.

These inputs do not prevent source implementation. Signing and the physical device are required for device acceptance.

## T005 source preparation

A debug-only capability probe and shared service contracts are now prepared.
Use `--capability-probe` in a Debug launch after the native build baseline is available.
See the [probe procedure](reports/2026-10-30-t005/capability-report.md),
[service decision](reports/2026-10-30-t005/service-contract-decision.md), and
[local verification](reports/2026-10-30-t005/local-checks.md).
Swift and native checks remain unavailable on this host. No device result is claimed.
T006 must verify the real DNG, neutral decoder, focus, hardware input, and configuration.
