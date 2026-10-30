# Device capability report

Status: RUN IN PROGRESS. First physical probe session. Values below come from `probe.json`
captured on the phone; `pending` items need this or a later session. No measurement is inferred.

| Field | Value |
| --- | --- |
| Date and operator | October 30, 2026; Nikola Balic (operator) with Claude guidance |
| Source revision or handoff manifest | 4596ba3 |
| App build and bundle identifier | build 1, com.nikola.slit, free personal-team signing (installs expire in 7 days) |
| Phone model and operating system build | iPhone 16 Plus (iPhone17,4), iOS 27.0.1 (24A446) |
| Xcode / SDK / Swift / XcodeGen versions | Xcode 27.2 (27B52), iOS 27.2 SDK, Swift 6.4.2, XcodeGen 2.46.0 |
| Physical camera type and zoom | rear builtInWideAngleCamera (main 1x), zoomFactor pinned 1.0 |
| Active format and available Bayer raw formats | photo dims {4032x3024, 5712x4284, 8064x6048}, AF System 2, ISO 33.0-7392.0, SS 0.000015-1.0; one Bayer raw format, OSType 1650943796 |
| Requested maximum dimensions / delivered DNG dimensions | requested 4032x3024; delivered and container both 4032x3024 (equal); 24 MP and 48 MP dimensions are supported but were not requested |
| Autofocus / point-of-interest / lock support | continuous autofocus, autofocus, point-of-interest, locked, and custom lens position all report supported; execution and sharpness evidence still pending |
| Exposure compensation range | device bias -8.0...8.0 EV (format system range -2.0...2.0); continuous AE and AWB supported |
| Hardware input events and capture phase | Camera Control (primary) delivered `began` then `ended`; the ended phase accepted a raw request that completed with byte-exact original and no error. Secondary (volume) events were not observed this session. Pressing Camera Control while the session is not running launches the system Camera app, consistent with the API contract that events go only to apps actively using the camera. |
| Readiness observations and slot limit | readiness observed `1` (ready) before acceptance; probe slot limit 1 |
| Optional acceleration features enabled | none: responsive, fast prioritization, zero shutter lag, deferred delivery, and ProRAW all disabled; quality prioritization speed |
| Neutral decoder and tested DNG result | CIRAWFilter decoder 8.dng; neutral render 768x1024 succeeded; operator visual inspection of the neutral image in progress; original preserved byte-exact (comparison `equal`) |
| Raw file size range and storage reserve | two samples, both exactly 6,391,988 bytes; reserve decision pending more scenes (WP-08) |
| Device configuration selected for baseline | provisional: 4032x3024 raw, speed prioritization; freeze decision pending the product owner |

## Evidence

- `probe.json` in this directory is the unmodified probe report from the phone (artifact DE2981D0).
- Timings, callback-latency proxies: on-screen request to processing callback 106 ms and 112 ms;
  hardware Camera Control release 1109 ms (single sample; possible first-press pipeline wake cost —
  needs a repeat set before any gate uses it); original write plus byte comparison 10-20 ms;
  neutral decode 2200 ms cold, 544 ms warm, 1314 ms on the hardware sample. All originals measure
  exactly 6,391,988 bytes across three captures.
- The 6.1 MB `original.dng` and `neutral.jpg` stay off the repository per the no-user-photographs rule;
  they remain on the device and the operator's Mac outside git.

## Findings and open questions

- The rear main camera delivers a real Bayer DNG with exact requested dimensions at 1x; M02 has its
  first positive device sample.
- Byte-exact original persistence verified once (M11 baseline behavior, probe scope only).
- Higher raw dimensions (5712x4284, 8064x6048) exist; the product owner must freeze the baseline
  choice with speed and storage tradeoffs measured (WP-01 freeze item).
- Open: hardware input phases, focus-lock execution with sharpness evidence, a measured
  capture/save loop set, and the frozen configuration decision.
