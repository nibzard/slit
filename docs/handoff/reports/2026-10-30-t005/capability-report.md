# Capability probe preparation

Date: October 30, 2026. Scope: Round 1, T005.
Status: SOURCE PREPARED. Device measurements: NOT RUN.

## Run the probe in T006

1. Complete the native build baseline in T003 and the signing and phone prerequisite in T004.
2. Add `--capability-probe` to the Debug scheme's launch arguments. Run on the physical iPhone 16 Plus.
3. Grant camera access and aim the physical rear main camera at a nonprivate test chart.
4. Inspect the report, then select **Capture test DNG**. Wait for the write and decode result.
5. Test primary and secondary hardware presses, holds, and cancellations. Copy the visible event log for rejected or cancelled attempts.
6. Select **Share probe files** explicitly. Store exports outside source control, or in ignored `capability-probe-output/`.
7. Complete the capability template with actual toolchain, phone, focus-lock, framing, file, and timing evidence before freezing settings.

The probe is absent from Release builds. Normal launches still use the unfinished Grip shell.
It has no simulated capture, fake file, processed-image fallback, or alternate camera.
It queries raw formats after attaching the input and output.
Its provisional choice is the first Bayer format and smallest supported maximum dimensions of the active format.
No resolution is assumed. T006 must confirm compatibility and replace this choice if device evidence requires it.

The report contains all raw formats, Bayer formats, active format, maximum dimensions, zoom, focus support,
exposure compensation range, continuous exposure and white balance support, readiness transitions, and observed hardware phases.
Hardware handlers identify primary and secondary actions; they do not invent the physical button identity.
Only ended events request capture. Readiness and one occupied probe slot still gate admission.
The event log keeps the latest 128 events. Disabled interactions cannot measure unobserved physical attempts.
Optional acceleration is disabled. The report records the configuration used.

The probe writes exact delivered bytes to Application Support under `SlitCapabilityProbe/<uuid>/original.dng`.
It compares the file bytes, checks DNG properties and dimensions, then runs `CIRAWFilter` through an actual render.
It writes `neutral.jpg` and `probe.json` beside the original. It never applies a creative filter.
The preview has a maximum requested long edge of 1,024 pixels. Full-resolution decoder memory is not established.
The decoder applies embedded orientation; the probe does not rotate the original or apply another orientation transform.
A successful render still requires visual inspection. Decoder failures retain the original.
A write failure retains the bytes in memory and permits **Retry probe write** without another exposure.
Probe exports are test artifacts, not committed library bundles or restart recovery evidence.
Do not delete app data until required evidence has been exported.

## Evidence state

| Check | Result |
| --- | --- |
| Connected raw formats and dimensions | NOT RUN |
| Actual Bayer DNG and byte comparison | NOT RUN |
| Neutral decode and visual inspection | NOT RUN |
| Focus support and verified lens lock | NOT RUN |
| Exposure range and automatic exposure/white balance | NOT RUN |
| Hardware phases, holds, cancellations, and readiness | NOT RUN |
| Phone, OS build, Xcode, SDK, Swift, XcodeGen | Pending T003 and T006 |
| Initial capture/write timing and raw file size range | NOT RUN |
| Frozen raw configuration, decoder, slots, storage reserve | Pending T006 |

Request-to-processing-callback duration is a callback proxy, not exact exposure latency.
The write duration includes byte comparison. It is not production bundle-commit latency.
Neutral decode duration is separate. No timing value is fabricated when the probe has not run.

Use the [capability template](../../templates/capability-report.md) for the device decision.
The [service decision](service-contract-decision.md) defines ownership and shared contracts.

## API references

Checked October 30, 2026. API documentation does not establish physical-phone results.

- [Apple hardware capture events](https://developer.apple.com/documentation/avkit/avcaptureeventinteraction/init(primary:secondary:)).
- [Apple event phases](https://developer.apple.com/documentation/avkit/avcaptureeventphase).
- [Apple photo output capabilities](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput).
- [Apple raw decoding](https://developer.apple.com/documentation/coreimage/cirawfilter).
