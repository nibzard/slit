# Architecture and integration contracts

The [native specification](../specs/0002-first-native-mvp.md) governs behavior.
This document assigns implementation ownership without creating more runtime modules than needed.

## Boundaries

| Owner | Location | Responsibilities |
| --- | --- | --- |
| App and interface | `App/Sources` | Grip, navigation, accessibility, view state, and platform view bridges |
| Capture | `App/Sources/Camera`; debug capability probe prepared | One serial session owner, configuration, readiness, focus, input, and delegate lifetime |
| Persistence | Add `App/Sources/Storage` | Order allocation, staging, metadata, atomic commit, recovery, and index |
| Review | Add `App/Sources/Review` | Preview work, image navigation, detail, and original sharing |
| Diagnostics | Add `App/Sources/Diagnostics` | Bounded phase records, report export, and performance instrumentation |
| Shared rules | `Packages/SlitCore` | Platform-independent state transitions, identifiers, and stable data contracts |

Do not add a Swift package per feature. Keep platform services together until there is a concrete reason to split them.
Do not introduce a third-party camera library or copy code from research repositories without a separate decision.

## Concurrency

Use one serial executor for session configuration and capture admission.
Choose an actor with a suitable executor or a dedicated serial queue after testing the deployment target.
Record that choice in the decision log before camera and focus implementations diverge.
A MainActor view model can publish interface state but must not run session startup or image development.

CaptureAdmission is a value type, not an actor. Only its owning executor may mutate the authoritative instance.
FocusOperation only rejects stale logical completions. It does not acquire or verify optical focus.
The camera owner verifies the platform completion before calling `confirmLock`.
Avoid unchecked Sendable annotations unless a reviewed ownership rule demonstrates why they are safe.

## Admission and data lifetime

1. Check session, visibility, output readiness, and storage status on the capture owner.
2. Reserve a slot and assign capture identity before submitting photo settings.
3. Track the platform request identifier to the app capture identifier.
4. On delivery, move the same request through Delivered and Saving without releasing the slot.
5. Release the slot only after commit, or after a terminal failure has actually released its data.

`releaseFailedRequest` cannot verify memory or file ownership. Its caller must release or preserve the data correctly first.
A failed save with retained data stays in `saveFailed`; retry transitions the same identifier to `saving`.
Use the configured slot limit to bound original data retention, not only the number of exposure requests.
Do not wire the shell's disabled buttons to fabricated success while integration is incomplete.

## Storage contract to agree in WP-01

Expose a small interface to the camera owner with these operations:

| Operation | Result |
| --- | --- |
| Reserve identity and order | Capture UUID, session ordinal, durable library order |
| Submit delivered original | Asynchronous commit result for the same identity; failure retains retry information |
| Retry retained save | Commit or explicit failure; never another exposure |
| Discard unsaved data | Explicit disposal after user confirmation |
| Read committed item | Original location, metadata, and optional preview location |
| Reconcile | Ordered committed items plus explicit recovery outcomes |

Freeze a typed metadata codec in SlitCore before creating persistent files.
Use the fields in specification section 7, including `libraryOrder`.
Add a checked-in synthetic fixture and round-trip, unknown-field, missing-field, and unsupported-version tests in WP-04.
Do not use real user photographs as repository fixtures.

### Durable order reservation

The specification requires admission order to survive reordering callbacks and restarts.
Do not put a synchronous disk allocation on the shutter path.
Before enabling capture, reserve a block of library-order values through an atomically replaced high-watermark file.
Use values from that reserved block in memory. Gaps after a crash are valid.
Refill before exhaustion in the background; briefly reject new admission if no safe value is available.
Recover the high-watermark from committed metadata, recoverable staging metadata, and its persisted reservation.
Never reuse an order already present in recoverable data.

This is the initial integration design. Validate termination at each reservation write boundary in WP-04.
An alternative requires equivalent evidence and a recorded decision.

## Preview and review contract

A committed original is independent from its preview.
The store publishes committed identity and metadata; the preview worker later publishes preview availability by that identity.
Ignore obsolete preview completions when review selection changes.
The library orders by durable request order, not commit time or callback order.
Keep the current review item stable if another capture finishes in the background.

The return control consumes its own touch and only changes navigation.
Attach hardware capture interaction only when the current screen can handle capture.
Preserve a verified focus lock during review only while the underlying session remains valid.

## Error contract

Distinguish capture failure, save failure, preview failure, and session unavailability.
Do not collapse them into a single Failed flag on a photo.
A bundle committed before an index error is still saved.
A failed preview must not remove a saved item or prevent original sharing.

## Privacy manifest

The current manifest declares only app-local UserDefaults access.
Storage, free-space checks, and timing instrumentation may introduce additional required-reason API usage.
Update declarations from the implemented API inventory during WP-04 and WP-08.
Do not add blanket reasons for APIs the app does not use.
Do not place absolute times derived from system boot or disk-space values into exported diagnostics without checking the relevant reason restrictions.

## Sources of truth

- `project.yml`: project structure and application property list.
- `Config/Base.xcconfig`: shared build identity defaults.
- `Packages/SlitCore`: tested logical rules; not hardware capability evidence.
- Specification 0002: product behavior and acceptance checks.
- `docs/handoff/BACKLOG.md`: implementation progress and dependencies.
- `/notes/`: live research; `docs/research`: dated portable snapshots.

## WP-01 source decision

T005 selects a dedicated serial camera queue and defines shared value contracts.
See the [ownership and service decision](reports/2026-10-30-t005/service-contract-decision.md)
and [probe procedure](reports/2026-10-30-t005/capability-report.md).
The debug probe does not replace production storage or the physical configuration decision in T006.
