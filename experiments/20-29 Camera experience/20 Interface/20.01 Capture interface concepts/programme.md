# 20.01 Capture interface concepts

Date: October 30, 2026.
Status: Grip selected by the user; refinement available. No native camera implementation.

## Purpose

Choose a visual direction before implementing the iPhone camera interface.
Compare the frame, control contrast, shutter position, and focus-lock feedback.
Keep the same scene and capture workflow across the three concepts.

| Concept | Design choice | Question |
| --- | --- | --- |
| Quiet | Black frame and centered shutter | Does the interface stay clear without distracting from the image? |
| Daylight | Light frame and dark, centered shutter | Does the lighter frame help controls stand out outdoors? |
| Grip | Dark green frame and a larger shutter on the right | Does the shorter right-thumb reach improve handling? |

The user selected Grip on October 30, 2026. It now opens by default.
Daylight is a visual direction, not a claim of measured sunlight readability.
Grip needs testing with different hands and grips before choosing it.

## Open the study

Open `prototype.html` directly in a browser. This file includes the image, styles, and scripts.
The editable source is `index.html`, `styles.css`, and `app.js`.
No package installation is required. Open the existing bundle directly.
After editing the source, run `python3 build.py` to update `prototype.html`.

For a local server, run this command from this directory:

```sh
python3 -m http.server 8765
```

Open `http://localhost:8765` in a browser on the same machine.
Opening the server from another device requires a reachable host address and network access.

## Try the interaction

1. Compare all three concepts, or select one using the study tabs.
2. Select **Try full screen** to judge the layout at phone size.
3. Tap the image to focus and reveal exposure compensation. Hold for 500 milliseconds to lock focus.
4. Press the shutter. Open the thumbnail after the simulated save completes.
5. Return to capture. Tap **Focus locked** to restore autofocus.
6. Select **Study** to leave full screen. Try another concept with the same scene.
7. Use **Use your photo** to choose a local image, or **Reset study** to clear the simulated captures.

Keyboard access: Enter focuses the viewfinder; L toggles its focus lock.
Space captures when the viewfinder or camera frame has keyboard focus.
Escape closes exposure or a panel, then exits full screen when no panel is open.
The information panel also provides a **Try focus lock** action.

The **More** panel includes an optional **Grid** switch. It defaults to off.
The browser remembers the preference when local storage is available. Reset study preserves it.
The grid appears only over the viewfinder image and does not block focus gestures.

## Deliberate limits

- The sample image is static. The app never requests camera access.
- Focus lock changes interface state only. It does not change optical focus.
- Exposure uses a CSS brightness approximation. It does not simulate raw development or camera metering.
- Exposure adjustment uses a horizontal slider in this study. The specification proposes a contextual vertical gesture.
- The simulated save delay is 450 milliseconds. It is not a device measurement or target.
- Each concept keeps at most 30 simulated captures in memory. Reset, reload, or changing the sample image clears them.
- Review displays the sample image and captured exposure setting. There is no raw capture, export, pinch inspection, or persistent storage.
- Phone hardware buttons and native system behavior are outside this browser study.
- The comparison controls, upload button, and full-screen exit belong to the study, not the proposed camera app.
- Choosing a local sample image does not upload its contents. The page uses a temporary browser object URL.

## Review questions

- Which frame makes the photograph easiest to read?
- Can you reach the shutter without changing your grip?
- Is focus lock visible enough without covering the scene?
- Can you return from review without searching for the control?
- Does a nonzero exposure value stay noticeable after closing its slider?

Record the chosen concept and requested changes in `/notes/street-camera-interface-prototypes.md`.
Do not treat a prototype preference as proof of native capture performance.

## Sources

- [Camera specification](../../../../docs/specs/0001-street-camera-mvp.md).
- [Interface research](../../../../docs/research/street-camera-interface.md).
- [Sample photograph](https://images.unsplash.com/photo-1449824913935-59a10b8d2000).

The local sample is a 1200 × 1600 image fetched from Unsplash on October 30, 2026.
All three concepts use the same source. The image is sample content, not original work by this project.
