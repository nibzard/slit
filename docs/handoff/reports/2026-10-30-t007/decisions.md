# T007 decision notes

Date: October 30, 2026. Scope: Round 1, WP-04 metadata codec and durable order allocation.
Every item below records a choice the specification section 7 appendix leaves open, or a
strict reading of it. None changes a field name, type, unit, or closed value list.

## Codec decisions

1. Absent keys are errors, including nullable keys. The appendix defines explicit null
   as the only encoding for an unavailable value, so absence is not a third encoding.
   A missing key fails with `missingField`; a null where the appendix says Never fails
   with `nullField`.
2. The flattened environment group is all null or all present. The appendix says an
   unavailable group writes null for every key of the group. A mixed group fails with
   `partiallyNullGroup` and names the null keys.
3. `recovery.unavailableFields` is validated in both directions against the closed
   appendix key list `CaptureMetadataKeys.appendixKeys`. A name outside the list fails
   with `invalidValue`, because the appendix types the array as key names from that list.
   The key list contains exactly the rows of the appendix table. The bare parents
   `original` and `recovery` are excluded because they are not table rows, so a leaf
   name such as `original.validation` is valid while the bare name `original` is not.
4. Timestamps are ISO 8601 UTC strings with second precision, written by the Foundation
   JSON encoder's `.iso8601` strategy. The appendix requires a UTC timestamp string but
   fixes no format. Sub-second precision is not needed for version 1; a later version
   would need an explicit format decision.
5. Unknown keys are ignored on decode, never written on encode, and never preserved
   through a decode-and-encode cycle. Recovery in T008 must keep a staging file's bytes
   when the specification requires its unknown keys to stay unchanged.
6. Encoded output uses sorted keys for deterministic files. The specification does not
   require this; it makes byte comparison in tests and fault injection practical.
7. The shared value contracts in `CaptureContracts.swift` were sufficient. No change was
   needed, and none was made.

## Order allocation decisions

1. Library orders start at 1 on a fresh library. The specification does not fix a first
   value. Zero is reserved as the empty floor, which keeps `max` arithmetic simple.
2. The high-watermark file content is `{"schemaVersion":1,"highestReserved":<integer>}`.
   The specification fixes the file name and purpose, not its content. The record is
   versioned so a later change can be detected instead of misread.
3. `recover` must run before any order is consumed; earlier use fails with
   `notInitialized`. This forces the launch-time recovery the specification requires and
   prevents a silent first allocation that ignores committed and recoverable values.
4. `consumeNextOrder` is synchronous and touches no store. Exhaustion throws
   `OrderReservationFailure.exhausted`, the typed rejection T009 maps to a brief
   admission rejection. `CaptureAdmission.Rejection` gained no case; adding one was not
   a defect fix, so its file stays unchanged.
5. A torn or failed high-watermark replacement hands out no value. Because the
   replacement is atomic, the failed attempt's range was never published; the retry may
   reserve the same numbers again. This is proven by the termination-boundary tests.
6. `reserve` extends from the persisted high-watermark, not from the in-memory cursor.
   Unconsumed values of an earlier block stay consumable, so gaps appear only at crash
   boundaries. Gaps are valid under the specification.
7. The default reservation block size is 64 in `SlitDefaults.orderReservationBlockSize`.
   The specification sets no size. T008 and T009 tune it from measured shutter cadence.

## Known limitations

- No Swift execution on this host. All tests are written against the swift-testing
  framework and are unverified until `make test-core` runs on the receiving Mac.
- The termination-boundary tests simulate crashes with a protocol fake. They do not
  terminate a process against a real filesystem; T008 adds file-level fault injection.
- `overflow` is reachable only near the top of the 64-bit order space. At a realistic
  cadence it cannot occur in the field; it exists so exhaustion of the space fails
  explicitly instead of wrapping.
