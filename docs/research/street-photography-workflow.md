# Street photography workflow

Research and design date: October 29, 2026.
Status: Proposed workflow. No camera application or renderer was tested.
Scope: A photographic workflow and its possible application interface.
The iPhone 16 Plus is a capture example. The portable look system can accept other supported raw sources.

Interface refinement: [Simple camera interface](street-camera-interface.md).
The user prioritizes simplicity and capture speed. Preparation remains optional, and capture opens directly into the camera.
The user confirms stills-only capture with the standard rear main camera fixed at 1x.

## Inputs reviewed

- [Photographer and style research](photography-styles-moriyama-winogrand-cartier-bresson-meyerowitz.md).
- [Portable look research](portable-photographic-looks-rfc.md).
- [Portable photographic looks request for comments (RFC)](../rfcs/0001-portable-photographic-looks.md).
- [iPhone 16 Plus technical research](iphone-16-plus-camera.md).
- [Camera developer guide](iphone-16-plus-camera-development.md).
- [Apple Camera interface research](iphone-camera-ui-ux.md).

## Central proposal

Prepare briefly, observe continuously, capture with few interruptions, then select and render afterwards.
Choose a visual intention for the walk and use one look as a starting point.
The intention guides attention. The look controls rendering. Neither replaces the other.

The photographer research supports different relationships with movement, space, light, and timing.
The RFC correctly limits a look to rendering operations.
A curve cannot create a gesture that was missed, and grain cannot create a useful relationship between subjects.

This is a proposed interpretation of the research, not a reconstruction of the photographers' exact working methods.

## What the current RFC supports

The RFC defines import, comparison, adjustment, and export. It explicitly excludes capture from its minimum viable product.
The workflow that fits that draft is:

```text
Choose an intention
        |
Capture with a separate camera or raw-capable application
        |
Import supported original raw files
        |
Select photographs and compare looks
        |
Adjust a recipe
        |
Export and sequence
```

The iPhone 16 Plus stock Camera does not capture Apple ProRAW.
Its ordinary processed photographs are not supported raw inputs merely because they came from that camera.
Use an appropriate third-party raw capture path or another supported raw source for the RFC workflow.
Exact iPhone raw resolution and available lens combinations still require device testing.

A contact sheet, selection tools, session defaults, and in-app capture are proposed product extensions.
They are not existing features or requirements already agreed in the RFC.

## Before the walk

1. Choose a subject or relationship to notice, such as crossings, reflections, gestures, or warm and cool light.
2. Choose one starting look from the five profiles.
3. Choose a familiar framing and check capture readiness with a test photograph.
4. Confirm that originals and the selected rendering remain separate.
5. Put the controls away and begin observing.

For the iPhone 16 Plus capture design, use the standard rear main camera fixed at 1x.
This is a practical proposed baseline, not a historically accurate focal length for every reference photographer.
Change position when that changes the relationship you want to photograph.
Framing changes through position rather than a zoom or lens control.

Set exposure for the scene, then attend to the picture.
Use a faster shutter when motion needs to remain clear and the capture application supports manual settings.
Do not assume the stock Camera exposes a numeric shutter control on iPhone 16 Plus.
Do not deliberately underexpose every raw file to obtain a dark final look.
Black density belongs largely to rendering; exposure still determines the recorded information.

## Observation approaches and rendering choices

| Reference | Attention exercise | Starting profile | Rendering priorities |
|---|---|---|---|
| Moriyama | Notice fragments, signage, reflections, close surfaces, and unsettling juxtapositions | Dense monochrome | Deep blacks, strong tonal separation, visible texture |
| Winogrand | Watch several people and gestures at once; inspect the frame edges | Descriptive monochrome | Readable midtones and distinct figures within a busy scene |
| Cartier-Bresson | Establish a spatial arrangement, then watch how movement changes it | Balanced monochrome | Clear shapes, smooth greys, controlled highlights |
| Meyerowitz street work | Notice color relationships, overlapping activity, and changes in light | Street colour | Color separation with moderate contrast |
| Meyerowitz Cape Light | Slow down and observe atmosphere, open space, and warm/cool illumination | Coastal light | Luminous transitions without a uniform color cast |

These are exercises derived from the research, not universal rules for the artists.
Winogrand also worked in color. Moriyama and Cartier-Bresson cannot be defined by monochrome alone.
Meyerowitz's early street work should remain distinct from the later Cape Light references.
Coastal light is an optional slower approach, not a replacement for the street color profile.

Do not add automatic tilt to Winogrand's profile or mandatory blur to Moriyama's profile.
Tilt, movement, viewpoint, and loss of focus can arise during capture, but a renderer should not invent them here.

Sources: [Moriyama exhibition][S1], [Winogrand retrospective][S2], [Cartier-Bresson's statement][S3],
[Meyerowitz street work][S4], [Meyerowitz Cape Light][S5].

## During a scene

Use a short loop: notice, position, anticipate, capture, and continue observing.
Watch for changes in gesture, separation, background, and the frame edges.
Make another exposure when something meaningful changes.
Avoid treating every shutter press as a reason to inspect the gallery.
Review when light changes substantially, when capture seems wrong, or when the scene has ended.

Example: a pedestrian approaches a bright shop entrance.

- A fragment-led approach might use the reflection, lettering, and partial figure as the picture.
- A gesture-led approach might wait for an interaction between the pedestrian and other people near the entrance.
- A geometry-led approach might wait for the figure to separate cleanly within the doorway.
- A color-led approach might use a red coat against the shop's green interior.

These choices change the source photograph. Applying four profiles to one exposure cannot reproduce all four choices.

Keep deliberate motion blur as a capture decision. Preserve a sharp option when it is useful.
Grain and dark tones should not conceal whether the important gesture or relationship is actually present.

## After the walk: selection first

A proposed selection flow uses a contact sheet with temporary picks and rejects.
Keep nearby frames grouped so that you can compare changes in timing.

1. Remove only obvious failures from the initial viewing set.
2. Mark frames with an interesting event, relationship, light, or structure.
3. Compare similar frames side by side and choose the strongest moment.
4. Inspect important details in those candidates.
5. Begin detailed rendering on the selected photographs.

Review with one consistent rendering first, either the shared base or the selected session look.
Use the base when aggressive rendering makes it hard to judge what was captured.
Avoid choosing each frame by whichever profile makes it look most dramatic.

A technically imperfect photograph can remain useful if the event and visual structure justify it.
Technical quality and photographic interest are separate selection questions.
Do not discard the original immediately when rejecting a preview.

Selection and contact-sheet behavior are proposed extensions. The current RFC only specifies look comparison.

## Rendering the selected photographs

Start with the chosen profile and as-shot white balance.
Adjust development exposure when necessary, then assess how the profile treats the image.
Preserve warm and cool illumination when that relationship contributes to the picture.
Use white balance deliberately rather than neutralizing every scene.

Use a short sequence:

1. Apply the starting profile.
2. Correct development exposure and white balance when needed.
3. Adjust strength and contrast.
4. Inspect grain and edge detail at full resolution.
5. Compare against the shared base rendering.
6. Save the recipe and export.

In the RFC, strength zero means the shared base rendering.
It does not mean the camera's embedded preview or an entirely unprocessed sensor image.
Keep those comparisons clearly labeled in the interface.

For Dense monochrome, ask whether dark areas help the photograph or conceal its subject.
For Descriptive monochrome, ask whether several figures remain distinct.
For Balanced monochrome, check the shape and continuity of middle tones.
For Street colour, check whether colors separate without a uniform saturation increase.
For Coastal light, check whether luminous highlights retain the intended warm/cool relationship.

These are proposed review questions. No approved profile values or visual matches exist yet.

## Sequence and export

Choose a small sequence rather than exporting every selected frame as a separate isolated success.
Alternate scale, density, gesture, and quieter images when that helps the sequence.
Avoid a run of nearly identical pictures unless repetition is intentional.

A starting exercise is to select five photographs from one walk and explain their order.
The number is an exercise, not a product requirement.

Apply a common starting look across the set, with explicit per-image adjustments.
Retain raw originals and editable recipes.
Follow the RFC's color-managed export and metadata policy, including its default omission of location metadata.
Export failures must retain the selection and recipe.

## Proposed application experience

The current product begins in an import workspace.
It can later gain a capture client that uses the same look definitions and recipe format.
A native camera client need not become part of the portable renderer.

### Capture client, if added later

Keep a stable shutter, exposure adjustment, current-look label, and review entry point.
The main camera remains fixed; the capture screen has no camera or lens selector.
Put detailed look controls in a sheet, away from the normal shutter path.
Choose the starting look before the walk; do not require a profile choice before each capture.
Remember intentional session settings rather than silently resetting them.

The look descriptor should remain separate from capture preferences.
Changing from Dense monochrome to Street colour must not silently change focus, shutter, or lens selection.
A session can reference both a look and capture preferences without embedding one inside the other.

If a processed video preview approximates the final raw rendering, label it as an approximation.
Do not promise that a preview and a developed raw file are identical.
If the final look appears only after capture, keep that behavior explicit and consistent.

Suggested visible states are ready, capturing, processing, saved, and failed.
Let processing continue without an intrusive review screen when the device supports the workload.
Do not claim continuous raw bursts or zero delay before measuring the actual phone.

### Review workspace

Show the contact sheet first, then comparable candidates, then detailed adjustments.
Keep the chosen look visible, but keep selection actions more prominent than effect controls.
Offer full-frame and full-resolution detail views.
Use the same renderer and saved settings for previews and export.

### Optional learning aid

A session can show one short attention prompt before shooting, such as "Watch the frame edges."
Hide it during capture unless requested.
Keep it separate from the look descriptor and from automatic composition scoring.
The current RFC excludes automatic composition and scene classification.

## iPhone development constraints

The virtual dual-wide camera restricts custom exposure, arbitrary locked focus positions, and arbitrary white-balance gains.
A physical camera may be needed for precise manual capture.
Apple also documents that balanced photo processing can override manual exposure for image fusion.
Use the documented speed priority when honoring explicit exposure is required, then measure the tradeoff.

These details matter to implementation, but should not become user-facing workflow steps.
Choose supported capture behavior in the client and expose only meaningful controls.

Sources: [Dual-wide device contract][S6], [Manual exposure contract][S7].

## Open questions and validation

- Does the first product remain import-only, or is a native capture client a later priority?
- Does the user prefer a live approximate look or a neutral preview followed by the finished look?
- Which raw dimensions and lens choices work reliably on an actual iPhone 16 Plus?
- How many photographs can be captured while processing continues without losing responsiveness?
- Does a consistent session look help selection, or does it hide useful information for some profiles?
- Do the five profiles remain distinct and useful on the same varied set of street photographs?

Test one walk from each of several lighting conditions before fixing interface defaults.
Record missed moments, changes of control, time spent reviewing during capture, and later selection quality.
Use the user's choices to evaluate the workflow. No optimization run or external model spending is authorized by this note.

## Sources

[S1]: https://www.lacma.org/art/exhibition/fracture-daido-moriyama "LACMA: Moriyama"
[S2]: https://www.sfmoma.org/press/release/first-major-touring-exhibition-of-garry-winogrand/ "SFMOMA: Winogrand"
[S3]: https://www.henricartierbresson.org/en/hcb/ "Fondation Henri Cartier-Bresson"
[S4]: https://www.joelmeyerowitz.com/street-photography "Joel Meyerowitz: Street photography"
[S5]: https://www.joelmeyerowitz.com/cape-light/ "Joel Meyerowitz: Cape Light"
[S6]: https://developer.apple.com/documentation/avfoundation/avcapturedevice/devicetype-swift.struct/builtindualwidecamera "Apple: Dual-wide device"
[S7]: https://developer.apple.com/documentation/avfoundation/avcapturedevice/setexposuremodecustom(duration:iso:completionhandler:) "Apple: Manual exposure"
