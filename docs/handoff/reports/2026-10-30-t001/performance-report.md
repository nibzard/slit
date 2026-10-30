# Performance report

Date: 2026-10-30. Operator: coding agent. Run: T001-local-01.
Source base: `10dcec51c20b44f38d7317e817b2f84f09e952cf` plus the T001 preparation changes.
Round 1 local preparation only. No app build, phone, operating system build, or capture configuration is available.

Status: NOT RUN. Proposed gates are not measured results.

## Conditions

Date, operator, source revision, app build, phone, operating system, camera configuration, available storage,
thermal state, illumination, focus mode, grid state, and preview workload: pending.

## Frozen acceptance gates

Record numerical gates before the acceptance run. Record the decision reference and rationale for each device-dependent value.

| Metric | Gate | Decision reference |
| --- | --- | --- |
| Request overhead, 95th percentile | At most 50 ms | Specification |
| Acceptance feedback, 95th percentile | At most 100 ms | Specification |
| Cold start | Pending baseline decision | Pending |
| Warm resume | Pending baseline decision | Pending |
| Sustainable cadence and accepted fraction | Pending baseline decision | Pending |
| Backlog drain | Pending baseline decision | Pending |
| Storage reserve | Pending device evidence | Pending |

## Results

| Workload | Attempts | Accepted | Rejected | Capture failures | Save failures | Committed | Median | 95th percentile |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 20 cold launches | Pending | — | — | — | — | — | Pending | Pending |
| 20 warm resumes | Pending | — | — | — | — | — | Pending | Pending |
| 50 attempts at 1 per second | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| 50 attempts at 2 per second | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Pending |

Collect at least 100 accepted captures for capture percentiles.
Name the metric used in each timing column. Add separate tables rather than mixing callback, storage, and handler durations.
Record raw events, rejection reasons, peak memory, preview stalls, and thermal transitions.
Compare grid on/off and preview active/idle using the same conditions.

## Conclusion

Pending. Do not call platform callback timing exact shutter-to-exposure latency.

## Preparation limits

See [local checks](local-checks.md) for executed commands and prerequisites.
T002 provides Mac access; T003 establishes the native build baseline.
T004 provides signing and phone access; T006 records physical capability.
T017 freezes performance gates; T018 runs final acceptance.
No physical acceptance result or performance measurement is claimed.
