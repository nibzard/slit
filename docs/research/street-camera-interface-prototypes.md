# Street camera interface prototypes

Date: October 30, 2026.
Status: The user selected Grip. The Grip refinement is now the default prototype.

## Deliverables

- [Standalone prototype](../../experiments/20-29%20Camera%20experience/20%20Interface/20.01%20Capture%20interface%20concepts/prototype.html).
- [Programme and instructions](../../experiments/20-29%20Camera%20experience/20%20Interface/20.01%20Capture%20interface%20concepts/programme.md).
- [Comparison screenshot](../../experiments/20-29%20Camera%20experience/20%20Interface/20.01%20Capture%20interface%20concepts/screenshots/comparison.png).
- [Quiet phone screenshot](../../experiments/20-29%20Camera%20experience/20%20Interface/20.01%20Capture%20interface%20concepts/screenshots/quiet-phone.png).

## Concepts

| Concept | Difference | Hypothesis |
| --- | --- | --- |
| Quiet | Black frame, centered shutter | The photograph receives most of the attention. |
| Daylight | Light frame, dark controls | The controls remain easy to distinguish against the frame. |
| Grip | Dark green frame, larger shutter on the right | The shutter requires less right-thumb movement. |

The user selected Grip after viewing the prototype. Outdoor contrast and prolonged grip comfort remain unverified.
All concepts retain one camera, fixed framing, stills, and a stable shutter position within that concept.
The first study omitted composition helpers. The user later approved an optional grid.
Mode selection, zoom, and look selection remain excluded.

## Verified findings

These findings come from local Chromium browser checks, not iPhone testing.

- All three concepts simulate capture, a bounded save queue, thumbnail review, and navigation between simulated captures.
- A third simultaneous request receives a busy state. Two accepted requests produce two simulated captures.
- Focus lock remains active after returning from review. The lock control restores autofocus state.
- Exposure compensation updates the image approximation and remains visible when nonzero.
- Review blocks keyboard capture. Returning to the camera restores interaction.
- More, reset, and full-screen entry and exit work.
- The full-screen layout fits 430 × 932 and 375 × 812 browser viewports without horizontal overflow.
- The centered shutter remains centered. The viewfinder retains its 3:4 frame.
- The standalone HTML includes the image, styles, and script. It has no external runtime dependency.
- Source JavaScript passes the Node syntax check.

The study uses a static sample. Its 450-millisecond save delay is arbitrary.
Focus lock is a visual state. Exposure is a CSS brightness approximation, not raw processing.
Captures exist only in memory and disappear on reset or reload.
The horizontal exposure slider is a study simplification; the native specification proposes a contextual vertical gesture.

## Open questions

- Does the refined Grip layout remain comfortable during repeated use?
- Does a centered or right-side shutter work better with the user's grip?
- Is focus lock easy to notice without distracting from the scene?
- Does the light frame help outdoors, or compete with the photograph?
- Should the chosen concept change before native implementation begins?

## Sources

- [MVP specification](../specs/0001-street-camera-mvp.md).
- [Interface research](street-camera-interface.md).
- [Sample image source](https://images.unsplash.com/photo-1449824913935-59a10b8d2000), retrieved October 30, 2026.

The prototype follows the current capture scope. It does not change the implementation specification or prove its performance targets.

## Grip refinement

Decision date: October 30, 2026.
User feedback: “grip rocks”, followed by approval to refine it.

- Grip now opens by default. Earlier concepts remain available for reference.
- The lower-right shutter keeps its size and position.
- Focus lock uses a distinct indicator below the image. The temporary focus marker fades after confirmation.
- The review return button occupies the shutter position and explicitly says Camera.
- Returning from review does not capture a photograph and retains focus lock.
- Review supports horizontal swipes as well as the existing arrow controls.
- Removed decorative text beside the shutter.

The new indicator and return placement remain refinements to validate with the user.
They do not establish measured capture speed or native focus behavior.
The browser prototype still simulates all camera operations.

Preview: [Grip over Tailscale](http://100.103.215.44:8765/prototype.html?view=phone&v=2).
The preview requires the local server to remain running and the viewing device to have Tailscale access.

Refinement checks passed in Chromium at 430 × 932 and 375 × 812.
The shutter and review return button have matching positions and dimensions at both sizes.
Checked focus-lock retention, fading focus markers, swipe navigation, and return without an extra capture.
The bundled preview loads through the Tailscale address and defaults to Grip.

## Optional composition grid

Decision and implementation date: October 30, 2026.
The user approved trying an optional 3×3 grid in Grip.

- Added a Grid switch to More. It defaults to off.
- Remember the preference in browser local storage when available.
- Thin light lines have a dark outline so they remain visible across varied tones.
- The grid follows the displayed image bounds, including letterboxed user photos.
- It ignores pointer events and does not appear in review or simulated captures.
- Reset study clears simulated captures but preserves the grid preference.

Source: the user's approval in this conversation and the updated [MVP specification](../specs/0001-street-camera-mvp.md).
Preview: [Grip with optional grid](http://100.103.215.44:8765/prototype.html?view=phone&v=3).
Open question: is this line contrast useful outdoors without becoming distracting?
Focus peaking and a horizon level remain deferred.

Browser checks passed for the default-off state, toggling, reload persistence, capture, and return from review.
Confirmed that the overlay ignores pointer events and review contains no grid.

The [first native MVP specification](../specs/0002-first-native-mvp.md) now governs implementation.
The browser study remains a visual reference; its simulated timing and storage do not define native behavior.
