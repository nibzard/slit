# Decision: Diagnostics rotation and accounting

Date: October 30, 2026. Owner: Pending. Work package: WP-08 preparation (T015).
Status: Proposed. Source rules are selected; compilation and device verification are outstanding.

## Problem

Specification 0002 section 10 requires a rotating diagnostics cache with a
total initial limit of 5 MiB, local records only, and explicit user export.
The store did not exist in any form. Before the App wires diagnostics into
the live app, the accounting rule, the rotation trigger, and the eviction
order need one definition, so that the App-side file service implements a
frozen contract instead of choosing rules during integration.

The same section forbids pixels, location, user photograph names, and
absolute photo paths in records. A free-form dictionary cannot guarantee
that exclusion over time.

## Decision

Aggregate accounting counts the sum of every segment's byte count in the
in-memory index, plus the incoming record's UTF-8 byte count including its
trailing newline. A record counts against the budget before it is written,
never after.

Rotation uses three limits, all fixed in `DiagnosticsRotationPolicy.standard`:

| Rule | Value | Source |
| --- | --- | --- |
| Total byte limit | 5 MiB | `SlitDefaults.diagnosticLimitBytes`; specification section 10 |
| Segment size trigger | 256 KiB | This decision; 20 segments fill the budget |
| File count cap | 20 | This decision; bounds directory entries even with small records |

Planning is a pure function from an index snapshot plus an incoming byte
count to a plan. Names derive from a creation ordinal, for example
`000007.jsonl`, and stay relative to the diagnostics cache directory. The
size trigger closes the active segment and opens the next ordinal. Closing
never deletes; only the limits delete.

Eviction removes the lowest creation ordinal first, and stops when both the
byte budget and the count cap hold. The active segment is never evicted
while closed segments remain. When the active segment alone still breaks the
byte budget, it is deleted and a fresh segment takes the record. A record
larger than the whole 5 MiB budget is refused and dropped; the store never
empties itself to admit one line.

The event model is a closed set of whitelisted primitive fields
(`DiagnosticsEvent.wireKeys`). It has no field for image samples, location,
photograph display names, or file paths, so those values cannot enter a
record through the API. A test encodes a fully populated event and asserts
the key set equals the allowlist. Identifiers are app-local UUIDs.
Durations are monotonic milliseconds from an injected clock. Package logic
never reads a system clock. Unavailable measurements omit their key from the
encoded record; the record never writes a fabricated zero.

Callback latency records its platform phase name and is labeled a proxy
metric in the model, the report tool output, and this record. It is not
exact exposure time.

Export starts only from `DiagnosticsExportTrigger.userSelectedShareDiagnostics`.
The package offers no other trigger, no scheduler, and no network API. The
export payload uses the fixed relative name `slit-diagnostics.jsonl` and its
byte count never exceeds the rotation budget.

## Alternatives and consequences

- One file rewritten in place: simpler accounting, but a crash can tear the
  file and rotation cannot delete only old data. Rejected for data safety.
- Time-based rotation: package logic has no clock, and boot-derived absolute
  times carry required-reason restrictions noted in the architecture
  privacy section. Ordinals give the same order without a time source.
- Byte budget without a file cap: unbounded directory entries with tiny
  records. The 20-file cap costs a small eviction and bounds the directory.
- Evict newest first: discards the most recent evidence, which the
  performance gates need most. Oldest first keeps recent runs.
- Refuse new records when full: keeps the oldest run forever and records
  nothing about current behavior. Eviction with newest-wins was chosen.
- Free-form dictionary records: flexible, but cannot structurally exclude
  forbidden values. The closed field set was chosen and tested.

Consequences: the store can lose the oldest records under sustained load,
which the specification permits and the export path mitigates by copying the
current set on request. The 5 MiB budget holds roughly a few thousand
records; if measurement runs need more, export between runs or raise the
limit through a new recorded decision, not silently.

## Verification

Acceptance coverage: M22 (recorded performance gates need bounded, complete
records), M23 (optional-work comparison uses the same event model), M24
(diagnostics stay bounded, offline, and exclude image data; export is
explicit).

Evidence prepared: swift-testing tests for exact-limit boundaries, one-byte
overflow, oldest-first eviction order, count-cap eviction with bytes to
spare, the size trigger without deletion, lone-segment rollover, refusal of
oversized records, end-to-end bounded writes over 200 records, wire-key
closure, null-for-unavailable, and export contents. The report tool ran
against the synthetic fixture; the output is in
[local checks](local-checks.md).

Remaining uncertainty: none of the Swift tests have executed. The App-side
store, clock injection, required-reason audit, and real device runs are
outstanding. Simpler or different limits need implementation evidence before
they replace these values.

## Source updates

No specification change: the 5 MiB limit already stands in section 10 and in
`SlitDefaults.diagnosticLimitBytes`, which remains the single source of that
value. The segment trigger and file cap are new constants in
`DiagnosticsRotationPolicy` inside this task's own files; `SlitDefaults.swift`
is unchanged. Backlog and status updates belong to the coordinator. Research
notes need no change; no new platform API was investigated beyond the
existing architecture privacy note.
