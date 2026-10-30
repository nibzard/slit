# Performance report

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
