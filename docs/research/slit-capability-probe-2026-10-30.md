# Slit capability probe API notes

Research date: October 30, 2026. Scope: Round 1 source preparation, T005.

## Verified API findings

- AVKit supplies separate primary and secondary handlers through `AVCaptureEventInteraction`.
  Its `phase` property uses `AVCaptureEventPhase`. Capture is mapped to the ended phase.
  Sources: [initializer](https://developer.apple.com/documentation/avkit/avcaptureeventinteraction/init(primary:secondary:)),
  [phase](https://developer.apple.com/documentation/avkit/avcaptureevent/phase),
  [Apple capture controls session](https://developer.apple.com/videos/play/wwdc2025/253/).
- The photo output exposes raw formats, Bayer-format classification, readiness, and optional acceleration flags.
  Source: [AVCapturePhotoOutput](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput).
- `CIRAWFilter` can open an image URL, select a decoder, and produce an image for actual rendering.
  `CIRAWDecoderVersion` uses a string raw value. `scaleFactor` is a Float.
  Sources: [raw filter](https://developer.apple.com/documentation/coreimage/cirawfilter),
  [decoder version](https://developer.apple.com/documentation/coreimage/cirawdecoderversion),
  [scale factor](https://developer.apple.com/documentation/coreimage/cirawfilter/scalefactor).

These are documentation findings. They do not establish compilation or hardware behavior.
The probe uses Core Image defaults without a creative filter. T006 must inspect the resulting neutral image.

## Open questions

- Does the provisional Bayer format and dimension pair work on the primary phone?
- Which decoder version and delivered dimensions occur on the installed operating system?
- Do focus lock, readiness transitions, and hardware holds and cancellations satisfy the specification?
- What are the measured file sizes, memory cost, timing, and safe storage reserve?

No physical capture, DNG decode, or timing result was produced on the Linux preparation host.
