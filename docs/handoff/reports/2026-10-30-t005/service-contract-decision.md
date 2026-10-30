# Camera ownership and service contracts

Date: October 30, 2026. Scope: Round 1, T005 local preparation.
Status: Source contract selected. Native compilation and device behavior remain unverified.

## Camera ownership

Use one dedicated serial DispatchQueue for session configuration, readiness, capture admission, and focus state.
This avoids introducing a custom actor executor before the iOS 18 build baseline exists.
The main actor publishes interface state. It does not start the session or develop raw images.

The probe owns its session, physical device, output, observations, and delegate lifetime.
Delegate callbacks extract value data and enqueue updates on the camera queue.
A self-retain lasts from submission through the terminal callback. A late delivery remains owned after backgrounding.
The probe's `@unchecked Sendable` conformance depends on this queue confinement.
Do not expose platform objects or mutate the report outside that queue.
Review this rule when the production camera adds preview attachment in T009.

A separate serial worker writes probe artifacts and develops the neutral preview.
One occupied probe slot covers capture, writing, decoding, and a retained write failure.
Retry uses the same artifact directory and exact bytes without requesting another exposure.
A decoder failure preserves the original and records failure independently.
Production capture uses separate storage and optional preview workers in T008 and T012.
The probe's combined worker is not the product's capture-performance baseline.

## Value contracts

`Packages/SlitCore/Sources/SlitCore/CaptureContracts.swift` defines the shared values.
`CaptureIdentity` carries capture UUID, session UUID, session ordinal, and durable library order.
Library order controls review order across sessions. Wall-clock time and callback order do not control it.

The store persists a high-watermark reservation before returning `ReservedOrderBlock`.
The camera consumes reserved orders in memory. Exhaustion rejects admission; no disk allocation runs on the shutter path.
Recovery must consider committed metadata, recoverable staging metadata, and the persisted reservation.
Gaps are valid. Reuse and overflow must fail explicitly.

`CaptureMetadata` separates requested settings, delivered measurements, environment, durations, original validation, and recovery information.
Optional values represent unavailable measurements. T007 must encode these as explicit JSON null values.
The value model groups identity and environment for Swift callers.
T007 must flatten their fields to the section 7 wire schema and enforce schema version 1.
No persistent metadata codec is claimed here. The probe's JSON report is not `capture.json`.

`OriginalStore` defines reservation, submission, retry, confirmed discard, committed reads, and bounded reconciliation.
Submission transfers retention responsibility to the store. Identity must agree throughout the request and metadata.
A retained result keeps the slot occupied and returns a store-owned retry token.
Tokens must reject stale requests. A retry never allocates a new identity, order, or exposure.
Discard requires the confirmed capture identifier and must refuse committed items.
Only actual disposal permits the caller to release a failed slot.

A committed result means the original and metadata bundle has completed its atomic directory rename.
An index error remains a committed result with `indexRepairNeeded` set.
Capture, storage, preview, and session failures have separate result cases.
Reconciliation preserves unreadable data and returns explicit recovery outcomes.
Pages use ascending durable order; the implementation must define a stable scan cursor and prevent duplicate publication.

## Remaining implementation

T007 implements metadata validation, the versioned codec, reservation durability, and crash-boundary tests.
T008 implements storage operations and failure injection. T009 integrates admission and camera callbacks.
T006 freezes physical format, dimensions, decoder, capacity, and storage reserve from device evidence.
None of those outcomes follows from this source contract alone.
