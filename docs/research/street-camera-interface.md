# Street camera interface

Design date: October 29, 2026.
Reviewed: October 30, 2026.
Status: Proposed design. No implementation or measured performance is claimed.

Implementation specification: [First native MVP: Grip street camera](../specs/0002-first-native-mvp.md).
That specification defines the initial scope, defaults, state recovery, and acceptance checks.
Optional helpers discussed below remain proposals unless the specification includes them.

Three interactive concepts are available in the [prototype notes](street-camera-interface-prototypes.md).
The user selected Grip on October 30, 2026: a dark frame with a larger shutter on the lower right.
The refined prototype adds a clear focus-lock indicator and a return control at the same thumb position.

## User priorities

Keep it simple. Prioritize capture speed.
Capture still photographs with the rear standard main camera, fixed at 1x.
This is the Fusion main camera on iPhone 16 Plus. The ultra-wide and front cameras are outside this design.
Open directly into a ready camera and preserve the user's intentional settings.
Choosing a look, starting a session, or reviewing an image must not be required before capture.

This refines the broader [street photography workflow](street-photography-workflow.md).
The current [portable looks RFC](../rfcs/0001-portable-photographic-looks.md) remains an import-and-render proposal.
This note describes a possible capture client and does not change that RFC's implementation scope.

## Earlier interface exploration

The following screen, remembered settings, and five-look controls describe the broader concept.
They are not the capture milestone requirements.
The MVP uses an ordinary preview, no look picker, and exposure compensation that resets after relaunch.
Grids, styled live previews, and rendering adjustments remain deferred.

### One main screen

```text
  Street colour                 ...



              Live view



  [last photo]    ( SHUTTER )
```

The diagram shows placement, not measured dimensions.

| Element | Behavior |
|---|---|
| Current look | Shows the remembered look; opens a compact list when tapped |
| More | Opens the small set of persistent options |
| Viewfinder | Shows the scene; supports tap focus and contextual exposure adjustment |
| Shutter | Takes a still photograph with one tap |
| Last-photo thumbnail | Opens review only when requested |

Use the main camera at 1x throughout capture.
Omit the lens selector, camera-switch button, zoom control, and mode selector.
Pinch gestures do not change framing.
Use a large shutter target and keep it in the same position.
Keep secondary controls visually quiet, with sufficient contrast over the scene.

## Default behavior

- Restore the last look and intentional capture settings.
- Begin with automatic focus and exposure.
- Let a tap choose the focus area; reveal exposure adjustment at that point.
- Support a hardware shutter through the documented platform interfaces.
- Capture one photograph per normal shutter action.
- Keep the camera visible after capture.
- Retain the original separately from its look recipe.

The capture experience is stills-only, including hardware shutter interactions.
Place detailed rendering controls in review.
Look selection is optional and is not part of every capture.
The photographer references remain in look descriptions and learning material.

## Looks

Use the RFC's descriptive names: Dense monochrome, Descriptive monochrome, Balanced monochrome, Street colour, and Coastal light.
Show the current name as a small control instead of a permanent carousel of five previews.
Switching the look changes rendering preferences while preserving exposure and focus settings.
The original remains available for another interpretation later.

## Composition helpers

Approved by the user on October 30, 2026, after reviewing Grip.
Use one optional, faint three-by-three grid. Default it to off and remember the user's setting.
Put its switch in More so it does not add another control to the capture screen.
The grid is a reference for spacing and alignment, not a requirement to place subjects at intersections.
It must not change framing, crop the capture, or delay the shutter.

Let the selected look determine whether the preview is monochrome or color.
A monochrome preview can help assess shapes and tonal separation.
Color previews remain important for the two Meyerowitz-inspired profiles, where color relationships contribute to composition.
Do not force monochrome across all looks or add a separate monochrome composition mode in the first version.

If "peeking" means focus peaking, it serves manual focusing by marking likely sharp edges.
It does not judge composition or establish that an entire moving subject will be sharp.
With automatic focus as the default, defer this overlay until manual focus demonstrates a repeated need.
Its outlines and frame analysis should earn their place through field and performance tests.

If "peeking" means seeing outside the capture frame, defer that too.
Apple's View Outside the Frame uses a wider camera view, which does not fit the selected single-camera capture design.
Do not simulate it by silently cropping the original main-camera framing.

A horizon level is a possible later option if field tests show a repeated alignment problem.
Do not add it by default: intentional tilt remains a valid compositional choice.

Sources: [Apple camera tools](https://support.apple.com/guide/iphone/use-camera-tools-iph3dc593597/27/ios/27),
[Apple View Outside the Frame](https://support.apple.com/en-ca/guide/iphone/-iphb362b394e/ios),
and the linked photographer research. The feature priorities are design recommendations.

## Zone focus and prefocus

Recommendation discussed on October 29, 2026; not yet a confirmed feature choice.
Zone focus sets focus in advance so that subjects within an acceptable distance range can be photographed without refocusing.
This fits the capture-speed objective more directly than a composition overlay.
It can remove autofocus acquisition from the moment of capture, but does not remove exposure, readout, storage, or processing delays.
Its usefulness depends on where subjects move and on the required sharpness.

Start with a simple prefocus lock rather than a distance dial:

1. Aim at a surface at the expected subject distance.
2. Use a long press to focus there and lock after focus settles.
3. Show a small Focus locked indicator.
4. Capture repeatedly while keeping the intended subject range in mind.
5. Tap the indicator to return to automatic focus.

This is proposed custom-app behavior. It is not a claim about the stock Camera's gestures.
Keep exposure automatic when locking focus; a focus lock should not silently become an exposure lock.
While focus is locked, ordinary viewfinder taps must not silently restart autofocus.
The visible indicator provides the explicit return to automatic focus.
Use no continuous focus peaking or extra focus slider for this first design.

A locked focus point is not a calibrated near/far sharpness zone.
The iPhone 16 Plus main camera has a fixed aperture; it cannot stop down to f/8 to extend depth of field.
Do not promise a particular range, such as two meters to infinity, without optical and capture tests.
The preview can hide focus errors that are visible in a full-resolution export.

Apple's lensPosition is a normalized actuator position, not a distance in meters.
The mapping is not consistent across devices, and a value of 1 does not guarantee infinity focus.
Do not label arbitrary actuator values as 2 m or 3 m.
Later distance presets require validated calibration and an explicit acceptable-sharpness criterion.
Until then, call this feature Focus lock rather than showing an unsupported distance scale.

For implementation, select the physical main camera and inspect focus-lock support.
Wait for focus to settle and for the locking operation to complete before showing the locked state.
Changing looks must preserve that state.
The MVP resets to continuous autofocus after session recreation. It does not restore an earlier focus lock.

Sources: [Apple lens position](https://developer.apple.com/documentation/avfoundation/avcapturedevice/lensposition),
[Apple current lens position](https://developer.apple.com/documentation/avfoundation/avcapturedevice/currentlensposition),
[Apple focus lock](https://developer.apple.com/documentation/avfoundation/avcapturedevice/setfocusmodelocked(lensposition:completionhandler:)),
and the linked iPhone hardware research.
The interaction and feature priority are design recommendations. No focus-distance calibration or timing test was performed.

## Camera implementation

Select the physical rear main camera directly.
In AVFoundation, Apple's name for this standard camera is `.builtInWideAngleCamera` with position `.back`.
That API name refers to the requested main camera; `.builtInUltraWideCamera` refers to the separate ultra-wide camera.
Use `videoZoomFactor = 1.0` and keep this camera selection fixed.
Validate raw support on this physical camera before enabling raw capture.
The naming follows the linked camera developer research; no device test is claimed.

## Capture feedback

Give prompt feedback when the camera accepts a capture.
Update the last-photo thumbnail only after the original commits. Use a placeholder until its preview is available.
Distinguish acceptance, processing, and successful storage internally.
Show failures when they require user action; do not imply that a file is saved before storage succeeds.
Review and export must not open automatically after a shot.

## Rendering and responsiveness

Prioritize capture work over expensive preview and rendering work.
Use a lightweight preview of tone and color when it meets measured performance targets.
Full-resolution grain and other expensive rendering can finish after capture.
A processed live preview is not guaranteed to match the final developed raw photograph exactly.

Keep pending work bounded. Persist captured originals and recipes before treating a capture as safely stored.
If the device cannot accept another exposure, show a brief clear readiness state.
Do not accumulate unlimited capture requests or claim zero delay without measurements.
Raw capture, preview processing, storage, and background rendering still share device resources.

## Review

Tapping the thumbnail opens the photograph with its chosen look.
Expose the look choice and a small set of adjustments there.
Keep the return-to-camera action immediate and preserve the camera's intentional state.
Contact sheets, detailed selection, and sequencing can remain later parts of the broader workflow.

## What to measure first

- Time from opening the app to its first accepted capture.
- Delay between pressing the shutter and the exposure.
- Sustainable time between captures.
- Missed, rejected, or failed captures during repeated use.
- Responsiveness while previews, storage, and rendering run.

Measure these on a named phone and operating system build before promising numerical targets.
The first success criterion is that the camera is ready when a moment happens.

## Evidence and open questions

This is a design recommendation based on the user's priorities and the linked local research.
The [camera developer notes](iphone-16-plus-camera-development.md) document platform restrictions and implementation sources.
The [photographer notes](photography-styles-moriyama-winogrand-cartier-bresson-meyerowitz.md) inform the rendering profiles.

Actual raw support on the main camera, preview cost, capture timing, storage latency, and thermal behavior remain unmeasured.
The first prototype should establish these before adding more controls.
