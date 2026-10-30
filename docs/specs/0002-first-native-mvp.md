# First native MVP: Grip street camera

Date: October 30, 2026.  
Status: Implementation specification; native implementation and device validation remain outstanding.  
Primary device: iPhone 16 Plus.  
Release scope: An internal build for street testing.

## 1. Purpose and authority

Build a minimum viable product (MVP) that opens quickly, captures still photographs, and saves originals reliably.
Use the Grip interface selected by the user.
Keep the standard rear main camera at 1× throughout capture.

The essential flow is: open, frame, capture, continue walking.
Focus lock and the grid are optional aids. Neither is required before capture.
Review must provide a fast return to the camera.

This document governs the first native MVP.
It supersedes the capture requirements in [the earlier proposal](0001-street-camera-mvp.md) where they differ.
The earlier document retains the later monochrome milestone as a future proposal.
[The portable look RFC](../rfcs/0001-portable-photographic-looks.md) remains a separate import-and-render project.

### Evidence and decisions

| Category | Decision or evidence |
| --- | --- |
| Confirmed by the user | Stills only; one standard main camera; capture speed; simple controls |
| Selected direction | Grip: dark frame, larger shutter on the lower right, review access on the left |
| Approved refinement | Clear focus-lock indicator; review return at the shutter position; optional 3×3 grid |
| Specification defaults | Raw originals, app-private storage, automatic exposure, no flash, and the limits below |
| Browser evidence | Layout and simulated interactions work in tested Chromium viewports |
| Not established | Native capture speed, optical focus accuracy, outdoor readability, battery use, or sustained thermal behavior |

The specification defaults are engineering choices, not additional claims about user approval.
Change them only through a documented decision supported by implementation evidence.
Do not silently replace raw capture or change framing to meet a speed target.

## 2. Deliverable and boundaries

Deliver a native Swift application that runs on the primary physical phone.
Use SwiftUI for screens, with UIKit integration where camera preview or input requires it.
Use AVFoundation for capture and AVKit for supported hardware capture events.
Use iOS 18 as the initial deployment target. Verify API availability in the selected Xcode toolchain.
Record the exact Xcode version, software development kit (SDK), phone, and operating system build in test results.
Do not claim support for untested phone models or operating system versions.

### Included

| Capability | Required result |
| --- | --- |
| Launch and permissions | Reach capture without a setup form after camera access is granted |
| Camera | Physical rear main camera at 1×; full capture framing |
| Shutter | One photograph per accepted onscreen or supported hardware action |
| Focus | Continuous autofocus, tap focus, and confirmed prefocus lock |
| Exposure | Automatic exposure and white balance; contextual exposure compensation |
| Grid | Optional 3×3 guide, initially off, with a persistent preference |
| Storage | Original Digital Negative (DNG) file and metadata committed together |
| Review | Latest image, adjacent images, detail inspection, and original sharing |
| Return | A Camera control at the shutter position; it does not take a photograph |
| Recovery | Permission changes, interruptions, failed saves, and restart reconciliation |
| Diagnostics | Local timing and outcome records that can be shared explicitly |

### Excluded

Exclude video, audio capture, Live Photos, front camera, ultra-wide camera, zoom, and automatic lens switching.
Exclude flash, torch, burst gestures, timers, and multiple capture modes.
Exclude calibrated zone distances, focus peaking, horizon levels, and composition scoring.
Exclude styled live preview, monochrome rendering, look selection, image edits, and rendered image export.
Exclude accounts, analytics services, cloud synchronization, image import, and automatic Photos library export.
Exclude deletion of committed originals, ratings, contact sheets, and batch operations for this internal build.
Exclude Lock Screen extensions and hardware-button launch from a closed app.

Do not implement a reusable look engine, a plugin system, or a general camera settings framework in this milestone.

## 3. Native interface contract

### Grip layout

Use the [selected prototype](../../experiments/20-29%20Camera%20experience/20%20Interface/20.01%20Capture%20interface%20concepts/prototype.html) as a visual reference.
Its fake status bar, device outline, study controls, and simulated delays do not belong in the native interface.
Use the system status area and actual safe-area insets.

Arrange the capture screen in this order:

1. A quiet top bar with the app name and More.
2. The complete image frame.
3. A reserved status strip for focus lock, capture feedback, and exposure compensation.
4. A bottom area with review access on the left and the shutter on the right.

Use the prototype's dark green frame and pale green shutter as initial visual tokens.
Start with frame `#20251F`, primary text `#EFEFEB`, secondary text `#A0A996`, and shutter `#CFDFB8`.
Use the system font in the native application.
Check text contrast and increased-contrast settings on the phone before acceptance.

In portrait, keep the shutter center fixed while the safe area stays unchanged.
The trailing and bottom clearances start at 24 points each.
A larger safe-area inset replaces the 24-point clearance on that edge; nothing else reduces it.
Place the center so that the largest supported diameter still keeps both clearances.
Target a shutter diameter of 104 points.
Adapt the diameter before moving the center: when the trailing or bottom safe-area inset, the reserved status strip, or an adjacent touch area leaves too little room for 104 points, reduce the diameter in whole points, never below 88 or above 116 points.
Move the center only when an 88-point diameter still cannot fit.
Then move it by the smallest amount that restores the fit, and record the change.
Keep the center fixed across focus, saving, busy, exposure, and diameter changes.
The review return control must use that same center and touch area.
Apply the same precedence between diameter and center in landscape.
These are initial layout values; record any change made after testing reach on the phone.

Other controls need at least a 44-by-44-point touch area. Review access uses 52 by 52 points.
A smaller icon can sit inside a larger touch area.
Do not move the shutter when a status label appears.

Use the entire image rectangle, not a screen-filling crop.
Fit preview content inside the available area and ignore focus taps in letterbox margins.
The sample image uses a 3:4 portrait frame; native framing must match the actual configured capture geometry.
Align the grid with the image rectangle, not the device display.

### Orientation

Support portrait and both landscape orientations for capture and review.
Keep the shutter at the lower right of the displayed interface in each supported orientation.
Keep review return in the same location as the shutter for that orientation.
Reflow the image and controls without cropping or covering the shutter.
Keep the last supported orientation when the phone is flat or upside down.

Use platform preview and capture rotation support with deployment-version checks.
Convert tap coordinates through the preview layer after rotation and layout updates.
Record requested orientation separately from delivered orientation metadata.
Apply delivered orientation once during preview generation and sharing presentation.
Never rewrite the original DNG merely to rotate its display.

### Persistent and temporary state

| State | Open review | Session recreated in the same app run | Relaunch |
| --- | --- | --- | --- |
| Camera and zoom | Main, 1× | Reapply main, 1× | Main, 1× |
| Grid preference | Preserve | Preserve | Restore; off if unset |
| Verified focus lock | Preserve while session remains valid | Clear; continuous autofocus | Continuous autofocus |
| Exposure compensation | Preserve | Restore before enabling capture | Reset to zero |
| Exposure control | Close | Close | Closed |
| Saved library | Preserve | Preserve | Reconcile and load |
| Pending focus request | Cancel when leaving capture | Cancel | None |

If exposure restoration fails, show the actual value and a short explanation.
Never show a restored lock until a new lock has been confirmed.

## 4. Interaction specification

### Capture input

An onscreen shutter action fires on release inside the button.
Moving outside cancels the action. Holding does not repeat.
Use one handler for the action; do not combine tap and touch handlers that both trigger capture.

Use `AVCaptureEventInteraction` for supported physical capture buttons.
Map primary and secondary capture actions to the same still-capture operation.
Handle the `.ended` phase once. `.began` can prepare feedback but must not capture.
A cancelled interaction produces no capture.
Apple describes capture on release and separate primary and secondary handlers. [Hardware events][A1]

Enable hardware capture interaction only while the capture screen is active and can handle input.
Disable it in review, More, sharing, interruptions, and other unavailable states.
Do not intercept volume changes through undocumented observers or hidden audio controls.
Verify volume-button and Camera Control behavior on the actual phone.

### Tap focus

A tap inside the image sets the focus point and starts one autofocus operation.
After it settles, restore continuous autofocus.
Show a temporary focus marker for no longer than one second after settling.
A tap does not change the exposure metering point.
Reveal contextual exposure adjustment without changing its current value.

### Focus lock

Use a long-press threshold of 500 milliseconds with an initial movement tolerance of 12 points.
The long press suppresses the ordinary tap action.
Movement beyond the tolerance cancels the pending gesture.

1. Request autofocus at the selected image point.
2. Show Focusing in the status strip.
3. Wait for the current autofocus operation to settle.
4. Lock the current lens position through the platform API.
5. Show Focus locked only after the completion callback and state verification.
6. Fade the image marker after 700 milliseconds; retain the status indicator.

Use a two-second timeout for the complete acquisition and lock operation.
On failure or timeout, return to continuous autofocus and show Focus lock unavailable briefly.
Settling confirms focus operation state, not that the intended subject is optically sharp.

Use a session generation and focus-operation token to ignore stale callbacks.
A later gesture cancels the earlier pending operation.
Leaving capture cancels pending acquisition, but does not clear an already verified lock while the session remains valid.
A new long press while locked starts a replacement acquisition.

The shutter never waits for this operation. It captures at the current focus state when otherwise ready.
Tapping the Focus locked indicator restores continuous autofocus.
Tapping the image while locked reveals exposure adjustment without moving the lens.
Keep automatic exposure and automatic white balance active while focus is locked.

Apple provides `currentLensPosition` to retain the lens position during locking.
The lock completion callback reports completion of the adjustment. [Focus locking][A2]
Never label the normalized lens position as a distance in meters.

### Exposure compensation

Use automatic exposure and white balance. Do not add shutter-speed, sensitivity, or white-balance controls.
Do not impose an untested minimum shutter speed or silently switch to manual exposure.
Moving subjects may blur in low light; evaluate this during field testing before adding exposure modes.

Expose a vertical compensation control beside the selected focus point.
Move it inward near image edges so the control remains usable.
Dragging the control changes compensation; dragging elsewhere does not.
Limit the initial control to the intersection of the device range and −2 to +2 exposure values (EV).
Use one-third-EV steps and display the actual applied value to one decimal place.
If the range does not include these endpoints, use the supported range without inventing values.

Provide Reset to return to zero and Done to dismiss the control.
Starting a capture closes the control without resetting compensation.
A nonzero value stays visible in the reserved status strip and reopens adjustment when tapped.
The control must support VoiceOver adjustment without requiring a drag.

### Grid and More

More contains Grid, Capture information, and Share diagnostics.
Use a system sheet that can be dismissed with its close action or the standard dismiss gesture.
Capture input is disabled while the sheet is presented.

Grid is a switch with no sub-menu. Default it to off.
Persist it immediately in local preferences and retain it across restarts.
Draw lines at one-third and two-thirds of the displayed image width and height.
Use thin light lines with a faint dark outline; preserve their visual weight across display scales.
The overlay ignores all touch input and has no separate accessibility focus.
Do not include it in thumbnails, review, original files, or exports.

Capture information is read-only and includes camera identity, raw dimensions, app version, and operating system version.
Do not show speculative distances, fake exposure metadata, or unsupported sensor specifications.

## 5. Camera configuration and capability gate

Create one capture session with one video device input and one photo output.
Select `.builtInWideAngleCamera` with position `.back`.
This is Apple's API name for the requested standard main camera.
Do not select `.builtInUltraWideCamera` or a virtual multi-camera device.
Set zoom to 1.0. Do not install capture pinch-to-zoom handling.

Attach input and output before inspecting raw capabilities.
The initial capability report must establish:

- Bayer raw pixel formats available from the connected photo output.
- The configured format, supported maximum dimensions, and actual DNG dimensions from a test capture.
- Continuous autofocus, point-of-interest focus, and the required focus-lock operation.
- Exposure compensation range and continuous automatic exposure and white balance support.
- Available hardware capture events and readiness behavior for the chosen configuration.

Use `AVCapturePhotoOutput.isBayerRAWPixelFormat` to identify standard Bayer raw formats.
Create fresh photo settings for every accepted request.
Do not request Apple ProRAW, a companion processed image, Live Photos, brackets, flash, or deferred photo delivery.
Use `.speed` photo quality prioritization where supported by the selected configuration.
Record actual settings. Do not claim that this setting removes exposure or readout time.

Choose the supported configuration in the capability spike and freeze it for performance testing.
Do not assume raw output is 48 or 24 megapixels.
Set compatible maximum dimensions before session startup, not on each shutter press.
Apple notes that changing output dimensions can require costly pipeline reconfiguration. [Photo dimensions][A3]

Do not enable responsive capture, zero shutter lag, or other optional acceleration blindly.
Probe support with the exact raw configuration and include any enabled option in the capability report.
Readiness and resource limits still apply when acceleration is enabled.

If required raw or focus capability is absent, present an unsupported-configuration state.
Keep access to any existing saved library.
Do not switch to a different lens or processed-only capture automatically.

## 6. Readiness, ownership, and capture pipeline

### Ownership

| Component | Owns | Must not do |
| --- | --- | --- |
| Camera controller | Session, device configuration, delegates, input, readiness, focus generation | Disk writes or full-image development on the session executor |
| Capture store | Staging, bundle commits, index, reconciliation, storage failures | Trigger exposures or mutate the session |
| Preview worker | Thumbnail and review image generation | Block capture or original commits |
| Library model | Ordered saved items, selected review item, sharing state | Treat an uncommitted preview as a saved original |
| Preferences | Grid and schema version | Persist focus actuator values as a valid lock |
| Diagnostics | Bounded local event records and summaries | Store image pixels, location, or full source paths |

Use one serial owner for camera configuration and requests.
Keep session setup and start/stop work off the main thread.
Publish lightweight interface state on the main actor.
Retain each photo delegate until the terminal capture callback completes.
Do not perform disk I/O, hashing, or raw development while holding the device configuration lock.

### Admission rule

Accept a request only when all of these are true:

- The app is active and the capture screen is visible.
- Permission, session, and configured output are valid.
- The output reports an acceptable capture-readiness state.
- No storage-blocking error exists.
- A capture slot is available.

Use output readiness as a signal, not a guarantee of immediate exposure.
Apple describes it as readiness to respond in a timely manner. [Capture readiness][A4]

The interim acceptable readiness level is: the capture session is running, the rear device input is attached, the configured photo output is attached, and no session interruption remains unrecovered.
Treat this interim level as a minimum for admission, not as a definition of readiness.
The T006 capability freeze sets the final level from device evidence and records it with the frozen configuration.

Start with two capture slots. Lower this limit if device evidence requires it.
A slot covers request, delivery, and saving. Release it after commit or after a failure releases its data.
A failed save with retained bytes still occupies a slot.
Reserve the slot before calling capture; release it on a synchronous setup failure.
Never queue a rejected tap for later exposure.

### Accepted request

1. Allocate a unique identifier and a monotonic request ordinal within the session.
2. Snapshot requested settings, focus state, orientation, input source, and timing.
3. Give immediate acceptance feedback and issue one raw request.
4. Receive the raw result and preserve its delivered metadata separately from requested settings.
5. Send the result to the store and commit the bundle.
6. Publish the saved item, release capacity, and schedule optional previews.

Acceptance feedback is a brief shutter press animation, with an optional supported light haptic.
Keep the viewfinder visible. Do not play an artificial shutter sound or promise control over system sound behavior.
Display Saving while accepted originals remain uncommitted.
Display Saved briefly after commit; show a saved thumbnail or placeholder.
Capture errors display Couldn't capture. Save errors display Photo not saved.

A busy shutter stays in place and looks unavailable.
A rejected onscreen attempt can display Busy briefly, without capture feedback.
Log only hardware attempts the app actually receives; disabled interactions cannot provide a complete physical-button attempt count.

### Independent states

| Model | States |
| --- | --- |
| Camera | Permission needed, denied, starting, ready, busy, suspended, unavailable |
| Navigation | Capture, More, review, system share sheet |
| Focus | Continuous, acquiring, locking, verified locked |
| Original | Requested, delivered, saving, committed, save failed, capture failed |
| Preview | Missing, generating, available, failed |

Review does not force camera readiness to Ready when it closes.
Recheck the session, output, storage, and slots before accepting another request.
A preview failure never changes a committed original to a failed capture.
A late capture callback must still be handled if the user opened review after the request was accepted.

## 7. Storage and data contract

### Directory layout

Use Application Support for originals and metadata, not a purgeable cache.
Use staging and committed directories on the same filesystem.

```text
Application Support/Slit/
  captures/<capture-id>/
    original.dng
    capture.json
  staging/<capture-id>/
    original.dng.partial
    capture.json.partial
  recovery/<capture-id>/
  library-index.json
  order-high-watermark.json
Caches/Slit/
  previews/<capture-id>/thumbnail.jpg
  previews/<capture-id>/review.jpg
  diagnostics/
```

A capture identifier is a newly generated universally unique identifier (UUID).
Never derive identity only from a timestamp or overwrite an existing bundle.
The index is a rebuildable convenience. It is not the source of truth for originals.
`order-high-watermark.json` persists the highest reserved library-order value.
The store replaces it atomically before it returns any newly reserved values.
It is not rebuildable from committed bundles alone, because reserved values can outlive them.
Cache files can be deleted and regenerated.

### Metadata schema version 1

Store metadata as JavaScript Object Notation (JSON).
Use explicit units in field names. Use `null` for unavailable measurements, not fabricated zeros.

| Field | Meaning |
| --- | --- |
| `schemaVersion` | Integer 1 |
| `captureId` | Capture UUID; matches directory name |
| `sessionId`, `requestOrdinal` | Session identity and accepted request order |
| `libraryOrder` | Durable integer that orders accepted requests across sessions |
| `requestedAtUTC`, `committedAtUTC` | Wall-clock timestamps; distinct from monotonic timing |
| `appBuild`, `osBuild`, `deviceModel` | Reproduction context |
| `cameraDeviceType`, `cameraPosition`, `zoomFactor` | Actual selected physical device type, rear position, 1.0 zoom |
| `requested` | Raw format, maximum dimensions, quality priority, compensation, orientation, and focus state |
| `delivered` | Actual dimensions, orientation, exposure time in seconds, sensitivity, aperture, and focal length when available |
| `timing` | Named monotonic duration measurements in milliseconds |
| `original` | File name, byte count, and validation result |
| `recovery` | Whether recovered; which metadata fields are unavailable |

Do not store platform capture objects directly in JSON.
Whitelist fields and convert them to stable primitive values.
The original retains its returned bytes and embedded metadata unchanged.
A future recipe can reference the original without requiring a recipe field in version 1.

#### Field appendix for version 1

The table above names each field. This appendix fixes the exact keys, types, units, nullability, and closed values.
It is normative for every file that declares `schemaVersion` 1.
The shared contracts in `Packages/SlitCore` group identity and environment for Swift callers.
The stored form flattens both groups into the top-level keys listed below.
`requested`, `delivered`, `original`, and `recovery` remain objects.
An unavailable group writes `null` for the object key, or `null` for every key of a flattened group.

| Key | Type, unit, or closed values | Null |
| --- | --- | --- |
| `schemaVersion` | Integer; the value 1 | Never |
| `captureId` | UUID string; matches the bundle directory name | Never |
| `sessionId` | UUID string | Never |
| `requestOrdinal` | Integer; counts accepted requests within one session | Never |
| `libraryOrder` | Integer; durable across sessions; gaps allowed | Never |
| `requestedAtUTC` | UTC timestamp string | When unknown |
| `committedAtUTC` | UTC timestamp string | Until commit, or when unknown |
| `appBuild`, `osBuild`, `deviceModel` | Strings; flattened environment keys | When the environment group is unavailable |
| `cameraDeviceType` | String; actual selected device type | When the environment group is unavailable |
| `cameraPosition` | String; the rear position | When the environment group is unavailable |
| `zoomFactor` | Number; device zoom factor; 1.0 | When the environment group is unavailable |
| `requested` | Object; snapshotted request settings | When recovery lost the snapshot |
| `requested.rawPixelFormat` | Integer; packed raw pixel format code | Never |
| `requested.maximumDimensions` | Object; `width` and `height` integers in pixels | Never |
| `requested.qualityPriority` | One of `speed` | Never |
| `requested.exposureCompensationEV` | Number; exposure values | Never |
| `requested.orientation` | One of `portrait`, `landscapeLeft`, `landscapeRight` | Never |
| `requested.focusState` | One of `continuous`, `acquiring`, `locking`, `verifiedLocked` | Never |
| `requested.input` | One of `onscreen`, `hardwarePrimary`, `hardwareSecondary` | Never |
| `delivered` | Object; values reported by the platform | Never |
| `delivered.dimensions` | Object; `width` and `height` integers in pixels | When unavailable |
| `delivered.orientationEXIF` | Integer; EXIF orientation value | When unavailable |
| `delivered.exposureTimeSeconds` | Number; seconds | When unavailable |
| `delivered.sensitivityISO` | Number; ISO sensitivity | When unavailable |
| `delivered.apertureFNumber` | Number; f-number | When unavailable |
| `delivered.focalLengthMillimeters` | Number; millimeters | When unavailable |
| `timing` | Array of objects; each has `name` (string) and `milliseconds` (number) | Never; an empty array is valid |
| `original.fileName` | String; final file name inside the bundle | Never |
| `original.byteCount` | Integer; bytes | Never |
| `original.validation` | One of `readableContainer` | Never |
| `recovery.wasRecovered` | Boolean | Never |
| `recovery.unavailableFields` | Array of strings; key names from this appendix | Never; an empty array is valid |

EXIF means Exchangeable Image File format.
The snapshotted input source lives at `requested.input`.
It records the onscreen or hardware origin of the request, not the handler that processed it.
The closed value lists in this appendix are complete for version 1.
A value outside a list fails validation explicitly.

Unknown keys are not part of version 1.
A decoder accepts a file that contains them and ignores their values.
The app does not invent unknown keys for its own writes.
Recovery that completes a staging file keeps that file's unknown keys unchanged.
An unknown key never changes how a known key is read.

Order items by stable request order within each session.
Across sessions, preserve a durable library order and rebuild the index from that stored value.
Store that durable library order in `capture.json` before commit; gaps are allowed.
Allocate order at request admission so late callbacks cannot reorder captures.
Before enabling capture, reserve a block of values by atomically replacing `order-high-watermark.json`.
Consume reserved values in memory so no disk allocation runs on the shutter path.
Refill the block in the background before exhaustion.
Reject admission briefly when no safe reserved value remains.
Reserved values form an explicit third category beside committed and recoverable values.
Never reuse a value from any of the three categories.
On recovery, reserve new values above the largest committed, recoverable, or reserved value.
Wall-clock changes must not reverse the library order.

### Commit procedure

1. Create a unique staging directory and write the delivered original.
2. Validate nonempty file data and a readable image container; record delivered dimensions.
3. Write metadata, including the durable library order; finish and close both writes.
4. Rename the completed files inside staging to their final names.
5. Atomically rename the complete directory into `captures` on the same filesystem.
6. Update the rebuildable index, publish the saved state, and request a preview.

Do not run a full raw development as part of the storage commit.
Do not wait for hashing or thumbnail generation before accepting an otherwise eligible request.
If the index update fails after the bundle commits, the original remains saved; repair the index later.

The recovery guarantee covers process termination after a successful bundle commit.
It does not guarantee data delivery before the camera returns a complete file or survival of every power failure.

### Recovery and failed writes

Reconcile committed bundles and staging directories at launch using bounded background work.
Do not develop the whole library before showing the camera.
Repair missing index entries and regenerate missing previews on demand.
Validate recoverable staging originals and complete their bundles when enough information exists.
Keep unknown fields explicit. Isolate unreadable or incomplete data in recovery rather than displaying it as saved.
Repeated recovery must not create duplicate captures.

On a write failure, stop new captures if storage is blocked.
Retain delivered bytes or a recoverable staging file while possible.
Offer Retry save and Discard unsaved photo.
Retry uses the same identifier and original; it never triggers another exposure.
Discard requires confirmation and releases only that unsaved item.
If data was lost during termination, explain that recovery was unavailable; do not offer a false retry.

Do not automatically delete committed originals to make room.
Expose available storage in Capture information.
Before admission, require a conservative reserve derived from observed raw file size and occupied slots.
Set and record the exact reserve in the capability report; free-space estimates do not replace handling write failures.

This internal build deliberately has no committed-photo deletion.
State in library information that removing the app removes its local library, and that shared external copies remain.
Do not remove the camera's storage protection for convenience; test behavior when the phone locks during saving.
Do not enable app-managed cloud synchronization. Any system backup behavior is outside this app's synchronization scope.

## 8. Review, previews, and original sharing

The thumbnail opens the newest committed image by request order.
An earlier image that finishes saving later must not replace the thumbnail of a newer committed image.
If the preview is missing, use a saved-item placeholder that still opens review and permits sharing.

Review contains the full photograph, its position in the library, Share original, and Camera.
Use the same image placement and bottom-right return location as capture where the aspect ratio permits it.
Label the return action Camera and use a camera icon, not the capture shutter appearance.
Returning consumes the touch; it must not pass through to the shutter underneath.

Swipe horizontally to browse adjacent items when the image is at fit scale.
At magnified scale, pan the image instead. Do not switch photos accidentally while inspecting detail.
Pinch to inspect detail, up to the developed image's available resolution.
Provide an accessible Fit action and accessible previous/next actions.
Do not claim full-resolution inspection while showing a smaller embedded preview.

Use an embedded preview when available for quick display.
Generate an ordinary neutral review image through the platform raw decoder after the original commits.
Validate that decoder against an actual DNG from the primary device during the capability spike.
No custom look or shared portable-renderer dependency is required.
If full-resolution development fails, retain the original, show Preview unavailable, and offer Retry preview and Share original.

Keep at most one expensive preview development active.
Use small thumbnails for browsing and demand-driven detail rendering for the current image.
Cancel obsolete preview requests and stop starting new work under memory pressure.
Set an initial decoded-preview cache limit of 64 MiB; tune from measured peak memory.
A full-resolution development buffer is separate from that cache limit and must be measured explicitly.
Pause optional work when capture or saving needs resources.

Share only committed originals through the system share sheet.
Share the DNG bytes with an appropriate DNG type and filename.
Use a safe temporary copy if the sharing API requires one; retain it until the activity finishes.
Share preparation must not mutate or delete the committed original.
Cancellation returns to the same review item without a success claim.
Do not request Photos permission merely to present the share sheet.
Verify shared bytes against the stored original during acceptance testing.

## 9. Lifecycle, errors, and accessibility

| Situation | Interface and recovery |
| --- | --- |
| First launch | Request camera access when opening capture; no tutorial or account requirement |
| Permission denied | Explain that capture needs access; offer Open Settings and access to existing saved images |
| Permission changes in Settings | Recheck on foreground; configure or stop the session accordingly |
| Startup or runtime error | Preserve library access; show Camera unavailable and Retry when recoverable |
| Background or system interruption | Disable capture input; cancel pending focus; preserve delivered data and finish writes within available execution time |
| Foreground recovery | Revalidate session and storage; restart if necessary; never replay shutter input |
| Session recreation | Reset focus to continuous; restore same-run compensation; preserve grid |
| Low storage or write failure | Show Photo not saved and explicit recovery actions; block unsafe new capture |
| Memory warning | Release regenerable previews first; preserve originals and bounded pending writes |
| Thermal pressure | Defer preview work; reduce admission capacity if needed; show temporary unavailability when capture cannot continue |
| Preview error | Keep the saved item and original sharing available; offer retry |
| Unknown callback outcome after restart | Recover what exists; do not invent Saved or Captured status |

Do not automatically open review, More, or a modal success message after a photograph.
Keep recoverable status messages in the reserved strip unless a data-loss decision requires explicit action.
Only one blocking error presentation can be active; consolidate repeated write errors rather than stacking alerts.

Provide VoiceOver labels and state values for the shutter, review access, focus lock, grid, exposure, share, and return.
Provide an accessible Lock focus at center action on the viewfinder for users who cannot long-press a point.
Announce confirmed lock and failures; avoid reading every preview or exposure change repeatedly.
Support larger text without covering the shutter or removing essential actions.
Respect Reduce Motion and Increased Contrast. Do not rely on color alone for locked, busy, or failed states.

## 10. Diagnostics and performance gates

Record no pixels, location, user photo names, or absolute photo paths in diagnostics.
Use app-local capture identifiers, named phases, outcome codes, and durations.
Keep logs in a rotating cache with a total initial limit of 5 MiB.
Allow explicit export from More; do not send records automatically.

Use a monotonic clock for durations.
Record device, app, operating system, format, dimensions, focus mode, thermal state, and queue limits with each run.

| Measurement | Definition |
| --- | --- |
| Cold start | Launch instrumentation to a visible preview and eligible shutter |
| Warm resume | Foreground activation to a visible preview and eligible shutter |
| Request overhead | Input handler entry to the photo capture request call |
| Acceptance feedback | Accepted input to visible feedback beginning |
| Capture callback latency | Input to the named platform callback; a proxy, not exact exposure time |
| Storage latency | Complete raw delivery to bundle commit |
| Accepted fraction | Accepted application-observed attempts divided by all application-observed attempts |
| Backlog drain | Last accepted request to all remaining successful commits or explicit failures |
| Resource use | Peak memory, preview stalls, thermal state, and pending counts |

Initial application-overhead gates are a 95th-percentile request overhead of at most 50 milliseconds and feedback within 100 milliseconds.
These are requirements to test, not measured results.
For each result, report the sample count, median, 95th percentile, rejection reasons, and failures.

Use at least 100 accepted captures for capture timing and 20 runs for each startup measurement.
Include daylight, shade, low light, locked focus, autofocus, grid on/off, and preview generation active/idle.
Run two 50-attempt onscreen sequences at one attempt per second and two attempts per second.
Report acceptance fractions rather than implying that every attempt must succeed.
Also test hardware input separately, including holds and cancelled presses.

Before release acceptance, write a device-baseline report with numerical gates for startup, resume, sustainable cadence, accepted fraction, and backlog drain.
Freeze those gates before the acceptance run. A baseline is evidence, not automatic approval of its results.
If the baseline is unsuitable for street capture, simplify optional work or record a scope decision before continuing.
Never pass the MVP by reporting fast accepted requests while hiding excessive rejected attempts.

## 11. Acceptance checklist

All checks below must pass on the primary physical phone unless marked as a development fault-injection check.
Simulator and browser results do not satisfy camera or performance checks.

| ID | Check | Required evidence |
| --- | --- | --- |
| M01 | First launch, grant, deny, and later permission change | Correct state and library access; no setup form or hidden capture |
| M02 | Capability configuration | Physical rear main, 1×, Bayer raw, dimensions and supported focus operations recorded |
| M03 | Grip in portrait and both landscapes | Full framing; reachable controls; matching shutter/return position; no overlap. Overlaid touch-area frames in all three orientations show every control at or above its minimum size, inside the display, and clear of the safe areas, the image rectangle, and every other control |
| M04 | Onscreen and hardware shutter | One accepted action has one identifier and at most one original; hold and cancel do not repeat |
| M05 | Busy input and queue pressure | No delayed replay; two-slot maximum includes saving and retained failed writes |
| M06 | Tap focus | Correct rotated image coordinates; margins ignored; continuous autofocus resumes |
| M07 | Focus lock and replacement | Indicator follows verified lock; stale completions ignored; exposure remains automatic |
| M08 | Timeout, interruption, review, and restart | No stale lock; valid review return preserves lock; recreation resets it |
| M09 | Exposure control | Supported range, reset, persistent nonzero indicator, same-run restoration, relaunch zero |
| M10 | Grid | Initially off; setting survives relaunch; touches pass through; no grid in review or shared originals |
| M11 | Raw validity | Every committed DNG opens; dimensions and delivered metadata agree |
| M12 | Commit and termination | After-commit termination loses no committed bundles; index rebuild and preview regeneration work |
| M13 | Fault injection during each write and rename | No false saved state or overwrite; retry preserves identity; discard requires confirmation |
| M14 | Incomplete staging and corrupt cache | Recovery is repeatable; valid originals remain; unreadable files are isolated |
| M15 | Delayed and reordered callbacks | Request order controls library and thumbnail; late callbacks remain handled |
| M16 | Review and detail | Swipes navigate at fit scale; zoom pans without changing items; detail resolution is honest. At maximum magnification the inspected image reports the pixel dimensions of the developed review image, never the dimensions of a smaller embedded preview |
| M17 | Return from review | Same thumb position; no pass-through capture; readiness rechecked; focus and compensation preserved when valid |
| M18 | Sharing and cancellation | Exported DNG bytes match; cancellation leaves library and selection unchanged |
| M19 | Background, screen lock, and runtime recovery | No replay or hidden capture; complete delivered data recovers where available |
| M20 | Low storage, memory, and thermal pressure | Bounded queues; optional work reduced first; no deletion of committed originals. Under induced pressure, diagnostics record preview work pausing or cancelling before admission capacity falls, and the count of committed bundles never decreases |
| M21 | Accessibility | VoiceOver workflow, center lock action, larger text, contrast, and motion preferences work. A VoiceOver user completes capture, focus lock through the center action, review, return, and share without sighted assistance. At the largest text size every labeled control stays on screen and reachable |
| M22 | Sustained capture and startup | Recorded performance gates pass; full counts, rejections, failures, and thermal context included |
| M23 | Grid and preview workload comparison | No framing change or capture dependency; optional work does not break the performance gates |
| M24 | Offline operation and diagnostics | Capture/review/share preparation work offline; no automatic network traffic; diagnostics stay bounded and exclude image data |

## 12. Implementation sequence and handoff

1. Build the physical-device capability probe, capture one DNG, and validate neutral review decoding.
2. Implement Grip, preview geometry, permissions, readiness, and one-shot input without simulated delays.
3. Implement focus, exposure, the grid preference, and lifecycle cancellation.
4. Implement bounded original storage, recovery, metadata, and the ordered library.
5. Implement review, detail inspection, original sharing, and the matching return control.
6. Run fault injection, accessibility checks, and physical-device measurements; freeze the remaining performance gates.
7. Complete the acceptance checklist and a street session; record defects and the next scope decision.

Provide the native source and an installable development build using the user's available signing setup.
Include a capability report, performance report, acceptance results, and a short list of known limitations.
Do not publish an App Store release as part of this task.

A successful internal MVP lets the user capture, continue shooting, review, and recover their originals without a rendering dependency.
The next decision is whether real capture performance and field use justify adding the monochrome review milestone.

## 13. Evidence, open items, and sources

The following items require implementation evidence before acceptance:

- Actual raw format, dimensions, and compatibility with the selected neutral decoder.
- Reliable focus acquisition and sharpness for expected subject distances and moving subjects.
- Hardware capture event behavior with the deployment target and phone operating system.
- Portrait and landscape geometry on the physical phone, including safe areas.
- Startup, sustained capture, acceptance fraction, backlog limits, and storage reserve values.
- Memory cost of full-resolution review and behavior under prolonged thermal pressure.
- Whether raw-only capture meets the speed priority; no processed-only fallback is authorized by this specification.

### Local sources

- [Selected Grip interface and grid decisions](../research/street-camera-interface-prototypes.md).
- [Interface research](../research/street-camera-interface.md).
- [Street photography workflow](../research/street-photography-workflow.md).
- [iPhone development research](../research/iphone-16-plus-camera-development.md).
- [Earlier camera proposal](0001-street-camera-mvp.md).

### Platform sources

Apple documentation was checked on October 30, 2026 for hardware event phases, focus-lock completion, dimensions, and readiness.
These sources establish API behavior; they do not establish performance on this phone.

[A1]: https://developer.apple.com/videos/play/wwdc2025/253/ "Apple: Enhancing your camera experience with capture controls"
[A2]: https://developer.apple.com/documentation/avfoundation/avcapturedevice/setfocusmodelocked(lensposition:completionhandler:) "Apple: Focus locking"
[A3]: https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/maxphotodimensions "Apple: Maximum photo dimensions"
[A4]: https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/capturereadiness-swift.property "Apple: Capture readiness"
