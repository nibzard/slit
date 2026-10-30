# Street camera MVP specification

Date: October 29, 2026.
Review date: October 30, 2026.
Status: Specification created; implementation and device testing have not started in this task.

Current implementation specification: [First native MVP: Grip street camera](../specs/0002-first-native-mvp.md).
Earlier proposal: [Street camera MVP](../specs/0001-street-camera-mvp.md).

## Scope

The first milestone covers stills with the rear standard main camera at 1x, raw capture, autofocus,
prefocus lock, exposure compensation, durable original storage, review, and original sharing.
It prioritizes capture speed and a simple interface.

A second milestone adds one Dense monochrome look in review, saved recipes, and JPEG export.
The portable renderer remains a separate component described by the existing RFC.

The initial design defers focus peaking, zone-distance presets, additional cameras, video, zoom,
a live styled preview, a five-look selector, and a locked-camera extension.
The focus-lock feature uses a verified actuator state rather than an uncalibrated distance scale.

## Decisions introduced by the specification

- Proposed minimum deployment target: iOS 18; validate actual operating system support before release.
- Initial limit: two capture slots, retained through storage commit or while failed writes retain original data.
- Ordinary camera preview in the capture milestone; styled rendering happens in review later.
- Focus lock survives review when the session stays valid, but resets after session recreation or app relaunch.
- Focus acquisition has an initial two-second timeout and does not block an otherwise available shutter.
- Initial exposure compensation resets after app relaunch.
- App-private storage and system sharing avoid Photos, microphone, and location permissions in the capture milestone.
- Numerical request-overhead and feedback targets are proposed gates, not measured results.

## Verification and remaining evidence

The specification includes acceptance checks for capture, storage recovery, failed writes, focus state,
hardware events, review, exported originals, rendering, and bounded background work.
Raw dimensions, startup time, sustainable capture rate, and thermal behavior need a physical phone.
The one-look milestone still needs a selected adapter, base transform, and reviewed profile revision.

Sources and related research are linked in the specification.

## Review pass: October 30, 2026

Reviewed the specification against its interface notes and the portable look RFC.
This was a document review. No new platform claims or physical-device measurements were verified.

Verified document findings and changes:

- The original queue limit did not define when capacity becomes available. Slots now cover delivery and storage.
- Review navigation could incorrectly imply readiness. Navigation and camera readiness are now separate.
- Concurrent callbacks could reorder the library. Request order now controls navigation and the latest thumbnail.
- Focus completion could arrive after cancellation. Stale completions must now be ignored.
- Preview failures could obscure saved originals. Review now supports placeholders, retries, and original sharing independently.
- Speed targets could pass despite excessive rejected inputs. Acceptance now requires recorded rate and backlog gates.
- Earlier interface notes conflicted with MVP defaults. The broader exploration is now labeled and restart behavior corrected.

Added background recovery, staging recovery, full-frame preview, orientation, and data-discard requirements.
The specification now has 17 capture checks and six look checks.
No composition helpers or additional camera modes were added.

Sources: [MVP specification](../specs/0001-street-camera-mvp.md),
[interface notes](street-camera-interface.md),
and [portable look RFC](../rfcs/0001-portable-photographic-looks.md).

Open questions remain: physical raw capabilities, acceptable startup and capture rates, storage backlog limits,
and the cost of raw-only capture. The renderer adapter and profile still require selection and visual review.

On October 30, 2026, the user approved an optional 3×3 grid in More after selecting Grip.
It defaults to off, remembers its setting, and appears only in the viewfinder.
Acceptance check C18 now covers the grid. The current specification has 18 capture checks and six look checks.

## Detailed first native specification

Date: October 30, 2026.
Created a separate authoritative specification for the first native build at the user's request.
It uses the selected Grip direction and approved optional grid.
The monochrome milestone remains outside this build.

The document defines native geometry, portrait and landscape behavior, gesture timing, hardware release events,
focus cancellation, exposure compensation, persistent preferences, bounded capture slots, and state ownership.
It also defines original storage, metadata schema version 1, stable library ordering, commit recovery,
neutral review development, original sharing, accessibility, diagnostics, and 24 acceptance checks.

Engineering defaults include a 104-point shutter target, a two-second focus timeout, two capture slots,
a 64 MiB decoded-preview cache, and a 5 MiB diagnostic log limit.
These are specification choices to validate, not measured device results or independently confirmed user requirements.

Verified platform findings from Apple documentation:

- Hardware capture events distinguish phases; capture on release uses the ended phase.
- Focus locking accepts the current lens position and provides a completion callback.
- Maximum photo dimensions must match supported values; changing output dimensions can reconfigure the pipeline.
- Capture readiness describes timely request handling, not exact exposure timing.

Sources checked October 30, 2026:
[hardware capture events](https://developer.apple.com/videos/play/wwdc2025/253/),
[focus locking](https://developer.apple.com/documentation/avfoundation/avcapturedevice/setfocusmodelocked(lensposition:completionhandler:)),
[maximum dimensions](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/maxphotodimensions),
and [capture readiness](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/capturereadiness-swift.property).

Open evidence: actual raw dimensions, neutral decoder compatibility, focus accuracy, hardware input behavior,
startup and capture performance, storage reserve, peak memory, and thermal behavior.
The first native build is an internal field-test release. No native implementation or physical validation is claimed.
