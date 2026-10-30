# T007 local verification

Date: October 30, 2026. Scope: Round 1, WP-04 metadata codec and durable order allocation.
Host: Linux. No Swift compiler, Xcode installation, simulator, or primary phone was established.
Swift compilation and Swift tests were NOT RUN on this host.

## Results

| Check | Result |
| --- | --- |
| `make check` | PASS, exit 0 |
| `make test-core` | NOT RUN; Swift executable absent, make exit 2 |
| `make build` | NOT RUN; script requires macOS with Xcode |
| `make test-ios` | NOT RUN; script requires macOS with Xcode |
| `git diff --check` | PASS, exit 0 |
| Swift compilation of new sources | NOT RUN; `swift` and `xcodebuild` are absent on this host |
| New core tests | Written, not executed: 15 codec tests and 12 order-reservation tests |
| Existing core tests | Unchanged: `CaptureAdmissionTests`, `FocusOperationTests`, `CaptureContractTests` are untouched |
| Physical M11 through M15 evidence | NOT RUN; assigned to T008, T009, and the device rounds |

Static checks do not establish Swift compilation, concurrency correctness, or storage durability.
The termination-boundary tests use a protocol fake, not a process kill on a real filesystem.
No sample photograph, device result, or fabricated test outcome is committed.

## What was implemented

`CaptureMetadataCodec.swift` defines the `capture.json` version 1 wire schema, the
`CaptureMetadataSchema.version1` constant, the closed appendix key list, and a typed
`MetadataCodecFailure` for unsupported versions, missing fields, null fields, values
outside closed lists, type mismatches, and mixed-null groups. The codec flattens the
identity and environment groups to top-level keys, keeps `requested`, `delivered`,
`original`, and `recovery` as objects, and encodes every unavailable value as an
explicit JSON null. Decoding ignores unknown keys; encoding never writes them.

`OrderReservation.swift` defines the durable library-order allocator, the
`OrderReservationStore` protocol for the high-watermark file operations, and the
`OrderReservationFailure` rejection type. The store persists every new high-watermark
before any new value becomes consumable. `consumeNextOrder` is synchronous and performs
no store operation, so no disk allocation runs on the shutter path. Recovery reserves
above the largest committed, recoverable, and reserved value. Overflow of the 64-bit
order space fails explicitly with no wraparound. See the [decision notes](decisions.md).

`SlitDefaults.swift` gains the capture metadata file name, the high-watermark file name
and schema version, and a default reservation block size of 64.

## Handoff to T008 and T009

- T008 implements `OrderReservationStore` with atomic file replacement in
  `App/Sources/Storage`, and must inject faults through the same boundaries the
  fake simulates here.
- T008 must keep a recovered staging file's unknown keys unchanged without routing
  the file through a decode-and-encode cycle; the codec drops unknown keys on encode.
- T009 catches `OrderReservationFailure.exhausted` from `consumeNextOrder` and rejects
  admission briefly; `CaptureAdmission` needs no source change.
- The receiving Mac must run `make test-core` before any result here is trusted.

See the [T005 service decision](../2026-10-30-t005/service-contract-decision.md) for the
contract background and [the specification](../../../specs/0002-first-native-mvp.md)
section 7 for the normative field appendix.

## Execution update, October 30, 2026

The full SlitCore suite was compiled and executed on this Linux host with
Swift 6.4.2 (`/tmp/swift-dist`): 17 XCTest tests and 62 swift-testing tests
passed with 0 failures, including the 15 codec and 12 order-reservation tests
written for this task. This replaces the earlier "written, not executed"
statement for the core package only. The macOS run in T003 is still required
for project generation, the app targets, and the UI tests.
