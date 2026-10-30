# Decision: freeze raw capture at 4032x3024 (12 MP) for the first native MVP

Date: October 30, 2026. Owner: Nikola Balic (product owner). Work package: WP-01.
Status: Accepted.

## Problem

The rear main camera of the iPhone 16 Plus supports raw photo dimensions of 4032x3024,
5712x4284, and 8064x6048. WP-01 must freeze one baseline configuration instead of
assuming the largest option. Higher dimensions multiply original size and decode cost,
and the MVP prizes responsive capture over resolution.

## Decision

Freeze the baseline at the smallest supported raw dimensions, 4032x3024, with speed
photo-quality prioritization and all acceleration features disabled, exactly as probed.
The probe measured deterministic originals of exactly 6,391,988 bytes across three captures,
byte-exact writes, callback latencies of about 106-112 ms on screen, and clean neutral decodes.

## Alternatives and consequences

- 5712x4284 (24 MP) or 8064x6048 (48 MP): roughly 2x or 4x original size and decode cost,
  unmeasured on device, and unnecessary for the street MVP framing. A later milestone may
  revisit after the MVP ships; that change must reopen this decision with measured evidence.
- Leaving the dimension unfrozen would block WP-02 configuration and the storage reserve
  calculation in WP-08.

## Verification

Evidence: the [capability report](capability-report.md) and the two committed probe reports.
Acceptance coverage: M02 baseline, M11 size planning; the storage reserve gate in M22 will
derive from the frozen 6.1 MB-per-original figure with measured variance from WP-08 runs.
Remaining uncertainty: busy scenes may compress differently in DNG size; WP-08 measures
the distribution before the reserve gate is frozen.

## Source updates

- WP-01 probe configuration stays as the provisional-baseline record; this decision freezes it.
- WP-02 implements session configuration at these settings.
- WP-08 sizes the storage reserve from 6.1 MB originals plus measured variance.
