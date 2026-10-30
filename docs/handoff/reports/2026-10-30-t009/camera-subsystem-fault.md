# Device camera-subsystem fault during WP-02 verification

Date: October 30, 2026. Owner: Nikola Balic (device operator) with Claude.
Scope: WP-02 first device runs, iPhone 16 Plus (iPhone17,4), iOS 27.0.1 (24A446), Xcode 27.2, free personal-team build.

## What works on device (verified while the subsystem was healthy)

- Live preview appeared after a force restart with production build v2 (queue-side preview attach).
- One-shot capture on the on-screen shutter: press flash, raw bytes delivered, terminal callback,
  honest `Photo not saved. Storage is not connected in this build.` feedback. No repeat on hold observed.
- States: permission flow granted; `ready run=true int=false ready=true slots=0` debug readout;
  preview connection reported active and enabled.

## The fault

After the WP-02 app ran, the whole camera subsystem died system-wide: our preview went black,
and the system Camera app also showed a black preview. A probe capture attempt in this state
wrote no artifacts (capture failed). A force restart (Volume Up, Volume Down, hold Side)
recovered the subsystem every time.

Reproducible sequence, observed twice:

1. Force restart the phone. System Camera is healthy.
2. Launch Slit (production build v2/v3). The camera subsystem dies during or shortly after the
   session comes up (once after a brief period of working live preview; once immediately).
3. System Camera is black afterwards.

## Builds involved

| Build | Preview attach | Observed |
| --- | --- | --- |
| Probe (no preview layer, raw output only) | none | Healthy through many captures and hardware presses over ~30 minutes |
| v1 (plain main-thread attach after start) | main, after start | First run black; subsystem was already wedged (system Camera black) — not a clean data point |
| v2/v3 (attach on camera queue inside begin/commit before start + main-thread nil/set re-kick on ready) | background queue + re-kick | Killed the subsystem in both clean post-restart tests (n=2) |
| v4 (plain main-thread attach, no re-kick; plus this report's hardening) | main, after start | Installed; untested — the device operator left before re-trust and re-test |

## Known matching OS issue

Public reports describe a camera freeze/black-screen bug on iPhone 15/16/17 models spanning
iOS 26.x into iOS 27, recovered by a restart. Whether iOS 27.0.2/27.1 fixes it is being
researched; see the research digest appended below when available.

## Hardening applied while the device is unavailable

- Scene-phase handling no longer stops the session on transient `.inactive` states; input is
  disabled instead, and the session stops only on real backgrounding. This removes the
  startRunning/stopRunning churn that all production builds had and the probe never had.
- A debug launch-argument bisect matrix (`--camera-mode=preview-only|raw-only|no-churn|churn|full`)
  is prepared to isolate the trigger in a few launches when the device returns. The `churn` mode
  restores the v1-v4 stop-on-inactive lifecycle to test hypothesis H3 in isolation.
- Off-main `AVCaptureVideoPreviewLayer` mutation and the nil/set re-kick were removed (v4).
- The preview layer now receives the session before the session runs: `PreviewView` reports the
  main-thread attachment and `CameraOwner` starts only after it (canon AVCam order).
- Canonical recovery observers were added: `runtimeErrorNotification` (restart after
  `mediaServicesWereReset`), `wasInterrupted`, and `interruptionEnded`.
- Lifecycle telemetry now survives a force restart: `os_log` plus a capped
  `Documents/camera-diagnostics.log` ring buffer (last lines shown in More, debug builds).
  Read this file right after any future wedge and restart.
- Configuration now happens exactly once per process (a `configured` flag replaces the
  `rawFormat` nil check), so `preview-only` mode no longer re-adds the input after a restart.
- The hardware capture-event interaction now sits on a full-screen view (canon responder chain),
  not a zero-size view.
- Verified as far as a host allows: `make check`, `make test-core` (all 79 core tests),
  simulator build, and simulator UI tests pass. The simulator cannot exercise the real
  capture pipeline.

## Research digest (adversarially verified, October 31)

Version facts: there is no iOS 27.0.2 or 27.1 for the iPhone 16 Plus; Apple's lineup is
27.0.1 then 27.2 (October 26, 2026). iOS 27.2's notes contain no camera fixes, and users on
this bug family report 27.2 did not fix theirs. Keep the test phone on 27.0.1 until the root
cause is isolated, then retest on 27.2.

The failure family is real and documented: system-wide camera black-out affecting all camera
consumers until a force restart, spanning iOS 26.x-27.x, with third-party camera apps as the
usual trigger (Apple Discussions threads 256222848, 256182778, 256369098). Apple has not
acknowledged it publicly. On the iOS 27 beta 4 a cousin bug broke third-party raw-shooting
apps (PhotonCam, Mood); Apple privately gave one developer an app-side workaround, which
proves at least one such bug is dodgeable by session/preview configuration choices.

Ranked causes for our wedge (surviving three-lens adversarial review):

1. ~45%: off-main `AVCaptureVideoPreviewLayer.session` mutation inside begin/commit plus the
   main-thread nil/re-set re-kick - the only code unique to both clean kills (v2/v3) and the
   only code this project shipped that violates AVFoundation's explicit threading rule.
2. ~25%: scenePhase start/stop churn (stop on every transient `.inactive`), present in every
   production build and absent from the healthy probe.
3. ~12%: Bayer raw output plus preview layer tripping an OS bug; canonical topology in
   shipping apps, no public corroboration as a wedge.
4. ~10%: the documented OS daemon fragility as precondition; our app as the efficient trigger.
5. Refuted 3-0: the zero-size interaction host view, the backgrounded system Camera app as
   cause, and pure coincidence.

## Return protocol (device owner, ~15 minutes)

Per launch: force restart; open system Camera and verify it is live, then swipe it away;
launch Slit in the mode below; use it 2-3 minutes (preview, 3-4 captures, one background
cycle); then check system Camera again. A KILL is decisive immediately; a SURVIVE needs the
run repeated once (the trigger is racy) before the mode is called safe.

1. `full` (hardened tree). Survives twice: ship confidence for WP-02 device checks; stop here.
   Kills: v2/v3 deltas and churn are both exonerated as necessary causes; go to 2.
2. `preview-only` (no raw output). Kills: raw is exonerated; run `raw-only` - if that survives,
   the preview-layer path alone is the trigger. 
3. `full` survived only: `churn` (isolates the old lifecycle). Kills: churn confirmed as
   sufficient cause; the hardened tree already removes it.
4. Optional last: a throwaway v2/v3-revival build to confirm cause 1 by reproduction.

On the next wedge, before force restarting: capture a sysdiagnose (hold Volume Up + Volume
Down + Side about one second, or Settings > Privacy & Security > Analytics > Analytics Data)
and copy `Documents/camera-diagnostics.log` out of the app container. File a Feedback
Assistant report referencing Apple Discussions threads 256222848 and 256182778.

## Open

- Whether the hardened tree (full mode) kills from a clean restart: the single most decisive
  unknown; one launch splits the hypothesis space in half.
- What the session reports at the wedge moment (runtime error, media services reset, silent
  death): now observable via the diagnostics ring buffer.
- Which daemon dies and why (JetsamEvent memory kill vs assert): needs the sysdiagnose above.
