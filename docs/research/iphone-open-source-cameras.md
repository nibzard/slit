# Open source iPhone cameras

Research date: 2026-10-29

## Verified findings

- [Align Studio](https://github.com/emlavankhoahienma-hue/ai-smart-framing-camera) has an MIT license. Its README states RAW DNG capture with a JPEG companion. It includes an Xcode project and a link for sideload builds. Capture behavior was not tested on hardware.
- [Photodew](https://github.com/IgnacioPro/iphone-raw) describes Bayer DNG and Apple ProRAW capture, manual controls, and an iOS 17+ target. Its root listing has no license file. Build instructions use Xcode.
- [Kontax Cam](https://github.com/kxvn-lx/Kontax-Cam) has an Apache-2.0 license. It is a Swift camera with film filters. Its README says it is no longer on the App Store. RAW support was not verified.
- [RawCam](https://apps.apple.com/us/app/rawcam-raw-dng-camera/id6765531876) is free and lists Bayer RAW and Apple ProRAW capture. A cached description claimed MIT licensing at https://github.com/madebysan/rawcam, but that repository returned 404. The current App Store description does not include that claim.

## Open questions

- Does Align Studio capture RAW correctly on the user’s iPhone?
- Will Photodew add an open source license?
- Is RawCam source available at another address?

## Source inspection on 2026-10-29

All three available repositories were cloned with `git clone --depth 1` into
`/tmp/iphone-camera-review.vBnl6q`. No source files were changed.

### Local clone directories

- Align Studio: `/tmp/iphone-camera-review.vBnl6q/align-studio`
- Photodew: `/tmp/iphone-camera-review.vBnl6q/photodew`
- Kontax Cam: `/tmp/iphone-camera-review.vBnl6q/kontax-cam`

### Photodew

- Source: https://github.com/IgnacioPro/iphone-raw
- Swift 6.1 package, iOS 17+, with no external package dependencies.
- Modules separate capture, rendering, storage, app state, and shared UI.
- `Sources/CameraKit/CaptureSessionService.swift` selects Bayer RAW and Apple
  ProRAW pixel formats separately. Each capture has its own delegate processor.
- The delegate keeps original RAW bytes from `fileDataRepresentation()`.
- Bayer RAW capture resets digital zoom to 1.0 and disables flash.
- The current camera selector uses the front or rear wide-angle camera.
- `ios/PhotodewApp/PhotodewIOSApp.swift` saves Bayer RAW and its processed
  companion as separate Photos assets. ProRAW saves as a single DNG asset.
- `Sources/RenderKit/RawRenderer.swift` uses CIRAWFilter with a neutral profile
  that disables sharpening and reduces enhancement for preview/export.
- Tests cover capture state, manual controls, metadata, rendering, and storage.
  The workflow runs SwiftLint, package build, and tests on macOS.
- The repository's ProRAW validation note records an author's user confirming
  capture on a physical device in February 2026. This is not our own validation.
- No license file or license grant was found in the inspected root listing.

### Align Studio

- Source: https://github.com/emlavankhoahienma-hue/ai-smart-framing-camera
- MIT license for the main repository; models have separate provenance and
  licensing files. The full distribution needs a separate model license review.
- iOS 17 deployment target, Swift 5 language setting, and an Xcode project.
- `AISmartFramingCamera/Services/CameraService.swift:2766` implements RAW capture.
  It prefers Bayer RAW and requests DNG plus a processed JPEG companion.
- Capture callbacks retain original RAW bytes. Saving in CameraViewModel passes
  those bytes to Photos and attaches the JPEG as an alternate photo resource.
- ProRAW is explicitly disabled during session setup. Although format selection
  has a ProRAW fallback, this is not evidence of a usable ProRAW mode.
- Dual-camera still capture takes a separate path before RAW selection. Treat
  RAW support as specific to the single-camera path.
- The app includes composition guidance, tracking, film filters, video, and
  cloud AI provider support. It is much broader than a simple RAW camera.
- CameraService has 3,306 lines; CameraViewModel has 4,777 lines.
- The build workflow exports and compiles multiple machine learning models with
  Python dependencies and Apple tools. Opening the Xcode project alone does not
  reproduce the complete release workflow.
- Tests exist for capture transitions, image decoding, tracking, and composition.

### Kontax Cam

- Source: https://github.com/kxvn-lx/Kontax-Cam
- Apache-2.0 license; latest checked commit is from May 2021.
- iOS 13 deployment target and Swift 5. Uses UIKit, an internal Backend package,
  CocoaPods, and an Xcode workspace.
- `Backend/Sources/Backend/Engine/CameraEngine/CameraEngine.swift:124` creates
  default processed photo settings. Its delegate converts image bytes to UIImage.
- The shutter handler applies filters and encodes a JPEG before saving.
- No RAW capture settings were found in the app or Backend source.
- The Podfile includes Firebase Analytics, Firebase Messaging, Shake, and a GIF
  view library. AppDelegate initializes Firebase and Shake.
- The README states that the app is no longer on the App Store.

### Scope and limits

This was a static source review on Linux. No Xcode builds, iPhone capture tests,
or Apple-framework tests were run. Source code confirms implementation paths,
but does not establish hardware behavior or current build success.

### Recommendation

Photodew is the most focused codebase for a manual RAW camera, subject to its
missing license. Align Studio is the available licensed RAW candidate, but has
more code and build dependencies. Kontax Cam does not meet the RAW preference.

### Inspected revisions

- `align-studio`: `59f807bc0cd6aa785b0745ba8fb5c7e2b62db8f6`
- `photodew`: `5603070b4ab0507c1a28ae20ad6bc3d6837d1b35`
- `kontax-cam`: `55365c0cfcd00f10078f00f948da373cd1f87ce4`

## Design and reuse review on 2026-10-30

### Verdict

Treat these repositories as references for selected techniques. None earns an
unqualified recommendation as the base for a new RAW camera from this review.

| Repository | Learn from it | Adopt it as a base | Install and rely on it |
| --- | --- | --- | --- |
| Photodew | Best of these three for focused manual controls and module boundaries | Resolve the missing license first; improve iOS validation and app structure | Promising, but requires a fresh device build and capture/save checks |
| Align Studio | Useful RAW byte preservation, paired saving, and request tracking | Reuse selected parts after review; the complete app adds substantial scope | Hardware checks remain necessary; broad features add failure paths |
| Kontax Cam | Useful historical filter pipeline and Metal preview examples | Poor choice for a new RAW camera | Current build and device behavior are unverified; no RAW capture path |

These judgments apply to the pinned revisions recorded above. No new versions
were fetched during this review. They assess the source, not image quality.

### Evaluation baseline

Apple's [AVCam sample](https://developer.apple.com/documentation/avfoundation/avcam-building-a-camera-app)
is the stronger starting reference for capture ownership, asynchronous operations,
separate capture helpers, and library storage. The current sample requires iOS 26;
check its platform requirements before adopting its code. Its architecture can
still inform an app with an earlier deployment target.

Apple's [RAW capture guide](https://developer.apple.com/documentation/avfoundation/capturing-photos-in-raw-and-apple-proraw-formats?changes=la)
describes separate Bayer and ProRAW capability checks, per-capture delegates,
original DNG data, and one Photos asset with RAW as `.photo` and its processed
companion as `.alternatePhoto`.

### Photodew: strengths

- `Package.swift` separates capture, rendering, storage, app state, and shared UI.
  It declares no third-party package dependencies. This keeps the capture feature
  easier to inspect and reduces dependency maintenance.
- Exposure, focus, and white balance have explicit state models. Tests check
  invalid values and failures that must preserve the previous state. These are
  useful examples of testable control logic.
- `Sources/CameraKit/CaptureSessionService.swift:924` starts the session on its
  dedicated queue. Each photo retains a separate delegate processor until the
  completion callback. The processor separates RAW and processed callbacks.
- Bayer RAW and ProRAW have separate format selection and capability reporting.
  This is clearer than presenting all DNG captures as equivalent.
- `Sources/RenderKit/RawRenderer.swift:59` isolates mutable filter work in an actor.
  It rejects empty data and invalid image extents. Export is a separate component.
- App recovery handles interruptions and runtime errors. Capture timeout messages
  and watchdogs show attention to failure recovery.

### Photodew: weaknesses and consequences

- No license grant was found. Do not assume permission to redistribute or adapt
  its implementation. [GitHub's licensing guidance](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository)
  explains why a public repository alone does not grant those rights. Resolve
  permission before choosing this code as a base.
- The module layout overstates the separation of the complete app. The iOS
  bootstrap file has 1,525 lines, ContentView has 1,468 lines, and the capture
  service exceeds 2,000 lines. Device integration, saving, and UI still need
  smaller components if the app grows.
- The CI workflow builds and tests the Swift package on macOS. It does not build
  the iOS wrapper. macOS compilation excludes several iOS RAW code branches.
  Passing package tests therefore cannot establish that the shipped app builds
  or its RAW settings work.
- Capture tests use stub backends. Renderer tests cover invalid inputs and data
  structures, but include no successful real-DNG rendering fixture. These tests
  help with state logic; they do not establish image quality or file correctness.
- `PhotodewIOSApp.swift:1327` saves Bayer RAW and JPEG as separate Photos assets.
  This is a valid product choice, but does not provide Apple's standard paired
  RAW/processed asset behavior. Copy it only if separate library items are desired.
- The camera selector chooses front/rear wide-angle devices. It is not a model
  for a complete ultra-wide/telephoto lens selector.
- `RawRenderer.swift:105` times access to `filter.outputImage` and image transforms,
  then returns a CIImage. It does not force pixel rendering. Apple's
  [CIImage documentation](https://developer.apple.com/documentation/coreimage/ciimage?preferredLanguage=occ)
  describes lazy evaluation. Inference: the logged render duration does not
  measure the complete pixel-rendering cost. Benchmark an actual render/export.
- Backend timeout returns an error after 12 seconds without cancelling the
  capture or removing its retained delegate. The UI watchdog separately resets
  state after 15 seconds. Late callbacks, retries, and captures that never finish
  require explicit device tests. This is a risk to investigate, not a reproduced
  leak or confirmed user-visible defect.

### Align Studio: strengths

- `Services/CameraService.swift:2798` chooses a RAW format and requests the DNG and
  JPEG in one capture. It rejects unavailable RAW instead of relabeling a JPEG.
- The capture delegate saves original `fileDataRepresentation()` bytes. Preview
  decoding and photo saving are distinct. This is the right pattern for retaining
  the original RAW data.
- `ViewModels/CameraViewModel.swift:4446` uses one Photos asset with DNG as `.photo`
  and JPEG as `.alternatePhoto`. This matches Apple's RAW save example.
- Requests are matched by their unique identifier. The app rejects overlapping
  captures. A timeout reports failure but retains its hardware busy state until
  the capture completion callback. This prevents a UI timeout alone from making
  the camera look ready for another request.
- Model download hashes, conversion manifests, native regression programs, and
  an unsigned device build workflow provide useful traceability examples.
- Its portable test runner explicitly states that Python reference tests and
  source checks do not compile Swift or validate camera APIs. That distinction
  is useful and should be retained in other projects.

### Align Studio: weaknesses and consequences

- CameraService has 3,306 lines and CameraViewModel has 4,777 lines. Capturing,
  tracking, composition, video, filters, cloud providers, and storage create many
  interactions. This increases the review and maintenance burden for a simple
  RAW camera. Large files alone do not prove defects, but the mixed duties are
  a concrete reason to extract components before adopting the app.
- All inspected ProRAW enable assignments set the flag to false. Apple's guide
  says enabling ProRAW adds its format to the available formats. The apparent
  ProRAW fallback in format selection is therefore not evidence of a usable
  ProRAW mode in these session paths.
- Dual-camera still capture exits through another path before RAW selection.
  Native RAW mode must be capability-gated against dual-camera mode.
- Release builds export and compile multiple machine learning models. This adds
  Python packages, downloaded weights, conversion steps, and separate model terms
  to the cost of maintaining an app whose main requirement may only be RAW.
  The root MIT license is not a complete inventory of model distribution terms.
- Several portable tests assert exact Swift source strings or counts. These can
  fail after harmless refactoring and can pass without exercising Swift behavior.
  Numerical reference tests also need checks against the actual Swift algorithm.
- The inspected build workflow runs native standalone regressions and builds the
  app. Its build command is not an XCTest run. The presence of XCTest source
  files alone does not establish that all those files run in CI.
- A failed timeout retains the busy flag until hardware completion. This is
  conservative, but requires a verified session reset route if completion never
  arrives. Do not copy that policy without its recovery design.

### Kontax Cam: strengths

- It keeps a reusable Backend package separate from app screens.
- Preview frames use a Metal view, a separate video queue, and late-frame dropping.
  This is a useful example for live filters that should not accumulate old frames.
- Filter selection uses a factory and separate effect implementations. That is a
  reasonable starting idea for organizing visual effects.
- The repository has an Apache-2.0 license. Its source is available for examining
  the actual app, including its app clip and widget integration.

### Kontax Cam: weaknesses and consequences

- Capture requests processed photos and converts them into UIImage. The shutter
  handler applies filters and encodes JPEG. It cannot serve as a RAW capture base
  without adding a separate original-data path and RAW capability handling.
- CameraEngine mixes capture, permissions, gestures, focus indicators, preview,
  orientation, and rendering. Public start/stop methods directly call the blocking
  session methods. Unlike Apple's current capture architecture, it does not
  establish one dedicated owner for all session operations.
- The permission method starts an asynchronous request, but initialization
  immediately calls setupCaptureSession. A comment says session setup is suspended;
  the inspected code does not implement that suspension. First-launch behavior
  needs explicit correction or verification.
- `ShutterButtonViewController.swift:114` disables interaction before capture.
  A nil captured image returns before restoring interaction. Filtering and JPEG
  encoding also run on the main queue. This can freeze interaction or stall UI.
- `FilterEngine.swift` uses fatalError for filter failures. A failed effect can
  terminate the app instead of preserving the photo and reporting the error.
- `DataEngine.swift` force-unwraps the app group container URL and ignores the
  result of createFile. A missing entitlement can crash; a failed write can be
  presented as a successful capture by the caller.
- Its Backend test checks the template text `Hello, World!`. It provides no
  assurance for capture, filtering, or saving.
- Dependencies include Firebase Analytics, Messaging, and Shake. Retaining these
  adds integration work unrelated to core capture. The pinned head is from 2021.

### Checks executed

Command: `python3 scripts/run_regressions.py` in the Align Studio clone.

Result: **68 checks; 65 passed; 3 failed; no skips**. The separate synthetic patch
flow replay returned exit code 0. The aggregate command returned exit code 1.

The failures are source-contract assertions:

1. Zoom feedback expects two occurrences of a string, but finds three.
2. Reticle tracking expects a specific variable declaration that is absent.
3. Reticle layout expects a specific frame modifier that is absent.

These failures establish that the portable suite is not green at the reviewed
revision. They do not establish three runtime bugs. No tests were changed.

Artifacts remain under
`/tmp/iphone-camera-review.vBnl6q/align-studio/validation/portable-results.json`
and `portable-tests.log`. The clone ignores these generated artifacts.
No Xcode builds, Swift tests, or device tests were run. Swift and Xcode are not
available in this Linux environment.

### What to follow in a new app

1. Use Apple's capture ownership and lifecycle guidance as the baseline.
2. Follow Photodew's explicit exposure, focus, and white-balance state models.
3. Preserve original DNG bytes and separate RAW capture from preview rendering.
4. Follow Align Studio and Apple for one paired RAW/JPEG Photos asset, unless
   separate assets are an explicit product requirement.
5. Keep capture, preview, rendering, saving, and UI state in separate components.
6. Build the real iOS app in CI and test successful RAW rendering with real files.
7. Test permission denial, interruptions, lens switching, late callbacks, failed
   saves, storage pressure, and repeated captures on physical devices.

### Open questions after this review

- Can Photodew's author provide an explicit license grant?
- Do both RAW apps build from a clean checkout on the selected Xcode version?
- Do DNG bytes survive capture, save, retrieval, and export unchanged?
- Do image dimensions, orientation, color, and paired resources match the selected
  mode on each supported lens and device?
- Does recovery restore capture after a callback never arrives or saving fails?
- Which Align Studio models are required for the intended feature set, and what
  are their complete redistribution terms?
