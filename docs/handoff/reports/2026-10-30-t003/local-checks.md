# T003 local verification

Date: October 30, 2026. Scope: WP-00 build baseline and WP-01 probe compilation on the receiving Mac.
Host: macOS (Apple silicon). Xcode 27.2 (27B52), Swift 6.4.2 from the Xcode toolchain,
XcodeGen 2.46.0 (upgraded from 2.45.4 to meet the recorded minimum), iOS 27.0 and 27.1 simulator runtimes,
iPhone 18 Pro simulator. No physical phone was connected.

## Results

| Check | Result |
| --- | --- |
| `make check` | PASS, exit 0 |
| `make test-core` | PASS: 17 XCTest and 62 swift-testing tests, 0 failures, with the Xcode toolchain (Swift 6.4.2) |
| `make build` | PASS after one source fix: unsigned simulator build with the iOS 27.2 SDK |
| `make test-ios` | PASS after two UI-test fixes: both shell tests on iPhone 18 Pro, iOS 27.0 |
| `make verify` | All four stages pass in order |
| Probe launch | `--capability-probe` launched in the simulator with camera permission granted; it reported `physical rear main camera absent` (`AVFoundation code=-11802`), which is the honest expected result without a physical camera |
| Physical M02 and M11 evidence | NOT RUN; still assigned to T006; no device claim is made |

## Fixed compilation and test issues

- `CompositionGrid` used the `accessibilityContrast` environment key, which the iOS 27 SDK removed.
  It now reads `colorSchemeContrast`, which carries the same `.increased` case.
- On iOS 27, a Form `Toggle` identifier resolves to the row element whose value does not track the state,
  and the combined placeholder element no longer surfaces as an `otherElement`.
  The UI tests query the toggle's inner switch descendant and any element type for the placeholder.
- Host limitation: a swiftly Swift 6.3.1 toolchain shadows the Xcode toolchain on `PATH`, and its driver
  fails its own frontend with `-target-arch-variant`. `make test-core` needs the Xcode toolchain first on
  `PATH` on this host. Installing a swiftly 6.4.x toolchain would remove the workaround.

## Existing follow-up work

| Task | Remaining outcome | Resume condition |
| --- | --- | --- |
| T006 | Run the probe on the physical iPhone 16 Plus, inspect a real DNG and neutral image, verify focus and hardware behavior, measure and freeze configuration | A signed development build; supply `Config/Local.xcconfig` and connect the phone |
| T008 | Implement production bundle persistence, retry, discard, and reconciliation | T007 complete |

T003 completes the macOS build baseline only. WP-01 remains incomplete until T006 provides physical evidence.
