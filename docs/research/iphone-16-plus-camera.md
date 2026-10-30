# iPhone 16 Plus camera: technical research

Research date: October 29, 2026.
Scope: iPhone 16 Plus, introduced in September 2024. This is not the iPhone 16 Pro or Pro Max.
Method: Public documentation and primary sources. No phone was connected or tested.
Developer notes: [Developer guide](iphone-16-plus-camera-development.md).

## Main findings

The phone has two rear cameras and a front TrueDepth camera system.
The rear hardware and advertised camera features match the standard iPhone 16.
The 2x option uses the main camera sensor; it is not a third rear lens.
The main camera supports 24 and 48 megapixel processed photographs.
A megapixel (MP) is approximately one million pixels.

The stock Camera app does not offer Apple ProRAW, Apple Log, or Apple ProRes capture on this model.
Standard Bayer raw photography through a third-party app is a separate capability from ProRAW.
An app must inspect the connected capture output to determine the raw formats it can use.
Do not infer raw resolution from the 48 MP hardware specification.

Sources: [Apple specifications][S1], [Apple launch announcement][S2], [ProRAW support][S3],
[ProRes support][S4], [Raw capture API][S5], [Raw format availability][S6].

## Physical cameras

| Camera or option | Resolution | Equivalent focal length | Aperture | Focus and stabilization |
|---|---|---|---|---|
| Rear Fusion main, 1x | 48 MP sensor; 24 and 48 MP output advertised | 26 mm | f/1.6 | 100% Focus Pixels; sensor-shift optical image stabilization |
| Rear 2x option | 12 MP | 52 mm | f/1.6 | Uses the main camera sensor and its stabilization |
| Rear ultra-wide, 0.5x | 12 MP | 13 mm | f/2.2 | Autofocus; 120-degree advertised field of view |
| Front TrueDepth color camera | 12 MP | Not specified in the cited Apple sheet | f/1.9 | Autofocus with Focus Pixels |

Focal lengths are equivalents to a 35 mm camera, not the physical lens focal lengths.
The listed apertures are fixed hardware values. Apps do not control a variable iris.
Optical image stabilization (OIS) moves the main sensor to compensate for camera movement.
Electronic stabilization instead changes image sampling and framing.

Apple specifies a sapphire lens cover and a True Tone flash.
The ultra-wide camera adds autofocus and macro photography compared with the previous standard model.

Sources: [Specifications][S1], [Launch announcement][S2].

### Interpreting zoom

The advertised 4x optical zoom range spans 0.5x through 2x: 2 / 0.5 = 4.
It does not mean a dedicated 4x telephoto camera exists.
Apple describes the 2x option as optical quality.
Cropping the central quarter of a 48 MP image gives approximately 12 MP.
The crop gives a narrower view, but does not add a longer physical lens.

The published limits are 10x digital zoom for photographs and 6x for video.
These Camera app limits are not a promise that every developer format exposes those exact ranges.
An app must inspect the active device and format.

Sources: [Specifications][S1], [Launch announcement][S2], [Device formats][S7].

## Image formation and processing

A raw sensor measurement is not a finished color photograph.
A typical processing sequence includes sensor correction, white balance, demosaicing, noise reduction,
color conversion, tone mapping, sharpening, and encoding.
This is an engineering model, not Apple's published internal processing order.

Apple advertises Photonic Engine, Deep Fusion, Smart HDR 5, and Night mode.
High dynamic range (HDR) describes retaining or displaying a wider brightness range.
Multi-frame fusion aligns and combines exposures. Movement can complicate alignment.

Apple explains 24 MP capture as a combination of a 12 MP fused image and a 48 MP image.
It is not simply the native output of a separate 24 MP sensor.
A 48 MP output has four times the pixel count of a 12 MP output, but only twice its linear dimensions.
Pixel count alone does not establish resolving power, noise, or dynamic range.
A dark scene or moving subject can favor a lower-resolution capture with different processing.

The latest Photographic Styles use local and color-specific adjustments.
Apple says the styles can appear in preview and can be applied or reversed after capture.
That product feature does not establish an equivalent public API for a third-party app.

Sources: [Apple high-resolution capture session][S8], [Launch announcement][S2].

## Photo features

The stock Camera feature list includes portraits with focus and depth controls, six portrait-lighting effects,
Night mode, macro photographs, spatial photographs, Live Photos, and panoramas up to 63 MP.
Photo formats include High Efficiency Image File Format (HEIF) and JPEG.
HEIC is the common file extension for HEIF images encoded with HEVC.
Exporting a JPEG does not preserve raw sensor samples or every auxiliary image.

Sources: [Specifications][S1], [Raw capture guide][S5].

### Three capture paths to distinguish

| Path | Data and processing | Implication |
|---|---|---|
| Processed HEIF or JPEG | Apple renders the image before delivery | Convenient finished photograph; limited ability to reverse processing |
| Bayer raw, usually packaged as Digital Negative (DNG) | Minimally processed sensor data | An app can choose its own rendering; resolution and camera support require inspection |
| Apple ProRAW | Raw editing flexibility with Apple computational processing | Not supported on iPhone 16 Plus |

Apple's developer documentation explicitly distinguishes Bayer raw from ProRAW.
Neither the word raw nor a DNG extension proves that no processing occurred.
Raw file precision, sensor precision, and useful dynamic range are different measurements.
Do not convert a file's nominal bit depth directly into a measured number of usable stops.

Sources: [Raw capture guide][S5], [ProRAW support][S3].

## Video and audio

| Mode | Advertised maximum or options |
|---|---|
| Normal rear video | 4K Dolby Vision at 24, 25, 30, or 60 frames per second |
| Normal front video | 4K Dolby Vision at 24, 25, 30, or 60 frames per second |
| Rear slow motion | 1080p at 120 or 240 frames per second |
| Front slow motion | 1080p at 120 frames per second |
| Cinematic mode | Up to 4K Dolby Vision at 30 frames per second |
| Action mode | Up to 2.8K Dolby Vision at 60 frames per second |
| Spatial video | 1080p at 30 frames per second |
| Other modes | Macro video, stabilized time-lapse, Night mode time-lapse, QuickTake |
| Standard codecs | High Efficiency Video Coding (HEVC) and H.264 |
| Audio features | Spatial Audio, stereo, wind noise reduction, Audio Mix |

These are stock Camera features, not a list of all combinations supported by an app.
A frame rate, codec, HDR mode, stabilization mode, depth output, and camera selection must work together.
The phone does not provide the Pro model's advertised 4K 120 mode.
Its published camera features do not include ProRes, Apple Log, or raw sensor video capture.
An app that offers a custom flat curve does not thereby enable native Apple Log.

Sources: [Specifications][S1], [ProRes support][S4], [Device formats][S7], [Final Cut Camera format support][S16].

### HDR engineering

Apple documents iPhone Dolby Vision workflows using 10-bit HEVC and HLG-compatible Dolby Vision Profile 8.4.
Hybrid Log-Gamma (HLG) is a transfer function; HEVC is a codec. They solve different problems.
A 10-bit HEVC file is not necessarily HDR. HDR is not necessarily raw or logarithmic capture.

An app that edits or exports HDR must preserve color-space and HDR metadata.
Apple warns that losing ambient-viewing metadata can make the result appear too bright.
Converting HDR into standard dynamic range (SDR) requires tone mapping, not just an 8-bit file conversion.

Sources: [Apple Dolby Vision engineering guide][S9], [HDR metadata technical note][S10].

## Depth, spatial capture, and computer vision

The phone has no rear Light Detection and Ranging (LiDAR) scanner.
Front TrueDepth provides a color camera plus depth capabilities.
The rear dual-wide virtual camera can calculate depth from disparity between camera images.
Rear stereo disparity and front TrueDepth are different measurement systems.

Depth delivery depends on the selected device, format, and outputs.
A portrait depth map is not a guarantee of survey-grade measurements.
ARKit's LiDAR scene-depth feature requires supported hardware and is not unlocked by a camera app.

Spatial video uses both rear cameras. A supported format and output setting are required.
The 2024 spatial-capture presentation predates the iPhone 16.
Its model restriction reflects that date; inspect current runtime support rather than copying the old restriction.

Sources: [Dual-wide device][S11], [Depth capture][S12], [ARKit scene depth][S13], [Spatial capture][S14].

## Device resources and transfer

The A18 includes a 6-core central processing unit, a 5-core graphics processing unit, and a 16-core Neural Engine.
These resources do not provide an app with unrestricted access to Apple's private camera algorithms.
USB-C runs at USB 2 speeds, advertised up to 480 megabits per second.
That equals 60 megabytes per second before protocol overhead; real transfer rates are lower.
An external drive cannot add unsupported capture formats.

Memory calculations explain why high-resolution processing needs care:

- A nominal 48-million-pixel RGBA8 image needs about 192 MB for pixel storage alone.
- The same image in RGBA half-float needs about 384 MB.
- A 3840 x 2160 RGBA8 frame needs about 33.2 MB. At 60 frames per second, that is about 1.99 GB/s.

These are derived decimal-byte estimates. They exclude padding, extra textures, and intermediate buffers.
They are not measurements of this phone's memory use or processing speed.

Sources: [Specifications][S1], [Pixel-format technical note][S15].

## Relevance to Chromagraph

The useful connection is the Bayer raw route, not Apple ProRAW.
A custom camera can retain originals and apply its own color, tone, grain, and halation during rendering.
That does not guarantee the same resolution, noise, preview, or timing as Apple's processed capture.
Raw capture support must be tested separately for each lens and mode on the actual phone.

The Chromagraph website does not document exact raw resolution or lens coverage for iPhone 16 Plus.
No such measurement was obtained in this research.

Sources: [Raw capture guide][S5], [Chromagraph product page](https://www.chromaticapplications.com/chromagraph/chromagraph).

## Unverified details

The cited Apple documents do not provide these engineering measurements:

- Exact sensor part numbers, manufacturers, active areas, and pixel pitch for every camera.
- Full sensor readout timing, rolling-shutter measurements, quantum efficiency, and full-well capacity.
- A complete matrix of raw sizes, bit packing, lenses, and capture modes.
- The internal processing order and complete algorithms for Apple's camera pipeline.
- Measured dynamic range, signal-to-noise ratio, focus distance, and sustained thermal limits for this particular phone.

Some review sites publish sensor sizes. They were not treated as verified component identification here.
Use a physical device, original files, calibration targets, and a repeatable test setup to resolve these questions.

## Sources

[S1]: https://support.apple.com/en-us/121030 "Apple: iPhone 16 Plus specifications"
[S2]: https://www.apple.com/newsroom/2024/09/apple-introduces-iphone-16-and-iphone-16-plus/ "Apple: iPhone 16 launch"
[S3]: https://support.apple.com/en-ie/119916 "Apple: ProRAW support"
[S4]: https://support.apple.com/en-us/109041 "Apple: ProRes support"
[S5]: https://developer.apple.com/documentation/avfoundation/capturing-photos-in-raw-and-apple-proraw-formats "Apple: Raw capture"
[S6]: https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/availablerawphotopixelformattypes-5fatm "Apple: Raw format availability"
[S7]: https://developer.apple.com/documentation/avfoundation/avcapturedevice/format "Apple: Device formats"
[S8]: https://developer.apple.com/videos/play/wwdc2026/304/ "Apple: High-resolution capture"
[S9]: https://developer.apple.com/av-foundation/Incorporating-HDR-video-with-Dolby-Vision-into-your-apps.pdf "Apple: Dolby Vision engineering guide"
[S10]: https://developer.apple.com/documentation/technotes/tn3145-hdr-video-metadata "Apple: HDR metadata"
[S11]: https://developer.apple.com/documentation/avfoundation/avcapturedevice/devicetype-swift.struct/builtindualwidecamera "Apple: Dual-wide device"
[S12]: https://developer.apple.com/documentation/avfoundation/capturing-photos-with-depth "Apple: Depth capture"
[S13]: https://developer.apple.com/documentation/arkit/arframe/scenedepth "Apple: ARKit scene depth"
[S14]: https://developer.apple.com/videos/play/wwdc2024/10166/ "Apple: Spatial capture"
[S15]: https://developer.apple.com/documentation/technotes/tn3121-selecting-a-pixel-format-for-an-avcapturevideodataoutput "Apple: Pixel format selection"
[S16]: https://support.apple.com/guide/final-cut-camera/about-standard-log-and-raw-video-dev8637f6692/2.4/ios/26.6 "Apple: Standard, log, and raw video"
