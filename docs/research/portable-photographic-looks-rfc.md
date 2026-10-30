# Portable photographic looks RFC research

Research date: 2026-10-29.

## Scope

The user requests an exploratory request for comments (RFC) about codifying photographic styles as looks applied to RAW images. The user clarifies that the input can be any RAW file. iPhone support is an example, not the scope boundary.

Draft location: `/home/agent/slit/docs/rfcs/0001-portable-photographic-looks.md`.

## Verified findings

- [Apple WWDC21: Capture and process ProRAW images](https://developer.apple.com/videos/play/wwdc2021/10160/) describes demosaiced, potentially fused linearizable data in DNG files. Optional tags supply the default rendering. A generic pipeline must not demosaic every RAW input or confuse a preview with developed RAW data.
- [Apple CIRAWFilter decoderVersion](https://developer.apple.com/documentation/coreimage/cirawfilter/decoderversion?changes=____5_8_2) describes supported decoder selection. It promises consistent appearance for a chosen decoder version but does not guarantee bitwise identity across environments.
- [Apple PHAssetResourceManager](https://developer.apple.com/documentation/photos/phassetresourcemanager?changes=_5_9&language=objc) distinguishes underlying original and edited resources from thumbnail or image representations. This is relevant to a future Apple import adapter, rather than the portable look format.
- [Adobe DNG resources](https://www.adobe.com/support/downloads/dng/dng_sdk.html) provides DNG specifications and a software development kit. DNG is one input family, rather than a universal RAW decoder.

## Proposed design choices

- Separate RAW development, base display rendering, creative look, and output encoding.
- Keep a look descriptor separate from the image recipe and render receipt.
- Standardise a defined image boundary before attempting cross-decoder consistency.
- Start with five profiles and one decoder adapter. Camera-agnostic architecture does not imply support for every file in the first release.
- Defer automatic exposure, masks, and learned transformations. These would introduce additional versioned decisions.
- Treat profile values as tuning hypotheses until a varied corpus is reviewed.

## Open questions

- Which base transform best preserves highlight relationships across the intended camera corpus?
- Which decoder adapter offers sufficiently documented linear output and suitable format coverage?
- Which colour operations distinguish the Meyerowitz profiles without imposing a uniform cast?
- Does local contrast add enough value to justify a spatial operator in the first release?
- What numerical tolerances are suitable for reference vectors on different hardware?

No implementation, camera corpus, or visual validation exists for this draft.

## Autonomous optimisation extension

Research date: 2026-10-29.

The user proposes an autoresearch-style hill climb with a strong multimodal language model. This remains speculative design work, rather than authorization to run experiments or spend an API budget.

Verified sources:

- [Karpathy autoresearch README](https://github.com/karpathy/autoresearch) describes an agent changing training code, running bounded experiments, evaluating a fixed metric, and retaining improvements.
- [Karpathy autoresearch program](https://github.com/karpathy/autoresearch/blob/master/program.md) separates mutable experiment code from fixed evaluation. Its instructions belong to that project and do not govern this task.
- [EditJudgeBias paper](https://arxiv.org/abs/2610.01670) audits multimodal judges for irrelevant-cue sensitivity, human agreement, and pairwise stability. Its abstract reports sensitivity to candidate order. It does not establish performance on photographic look optimisation.
- [AesBench project](https://aesbench.github.io/) introduces an expert-labelled benchmark of aesthetic understanding. Aesthetic benchmark results do not directly establish fitness for this particular style-rendering task.

Proposed extension:

- Let a model propose bounded profile mutations and explain a visual hypothesis. Keep the renderer, input development, rubric, references, and evaluation data immutable during a run.
- Render candidates on the same photographs. Use anonymous pairwise evaluation, randomised ordering, repeat checks, and full-frame plus detail views.
- Judge rendering attributes separately from composition and subject matter. Treat intentional grain and clipping according to the profile, rather than generic image-quality preferences.
- Calibrate the judge against the user's comparisons. Use a separate judge context, with no proposal rationale, candidate names, or prior scores.
- Separate search images, a promotion set, and a final lockbox set. Group related captures before splitting. Repeated promotion feedback can also cause overfitting; use the final set only after selection.
- Log every hypothesis, profile diff, seed, renderer version, judge version, prompt, score, decision, and cost. Stop at an explicit budget or plateau.
- Compare model-guided search against random search or a numerical optimiser using equal evaluation budgets.

Open questions: judge agreement with the user, suitable reference images and crops, acceptance thresholds, evaluation cost, and whether look-controlled base rendering materially improves results.
