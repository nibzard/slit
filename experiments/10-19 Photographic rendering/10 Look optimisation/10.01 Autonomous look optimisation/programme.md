# 10.01 Autonomous look optimisation

Status: Proposed experiment  
Date: 2026-10-29  
Related specification: [RFC 0001](../../../../docs/rfcs/0001-portable-photographic-looks.md)

## Objective

Use a strong multimodal large language model (LLM) to propose improvements to a portable photographic look. Render each candidate, compare it with the incumbent, and retain supported improvements.

The first experiment optimises the dense monochrome profile associated with Daido Moriyama. The output is a deterministic profile that the renderer can apply without a model call.

Test whether model-guided search improves the look more effectively than random search and a numerical optimiser under equal evaluation budgets.

This programme specifies the experiment. It does not start a run or authorise external model spending.

## Visual target

Optimise these rendering characteristics:

- Dense blacks with intentional, selective loss of shadow detail.
- Strong separation between dark, middle, and bright tones.
- Expressive texture and visible grain.
- Readable important forms where the source photograph supports them.
- Consistent treatment across different scenes and cameras.

Use reference photographs and crops to define the target more precisely before the run. Record the selected period, publication, or print treatment.

Do not reward subject matter, location, composition, or resemblance to a particular scene. A photograph of Tokyo receives no preference merely because Moriyama photographs Tokyo.

Do not reward generic attractiveness when it conflicts with the agreed treatment. Grain and clipped tones can be intentional.

## Experimental boundary

Keep the RAW developer, source development settings, base rendering, and output colour management fixed during a run. RAW is the camera image format before display rendering.

The proposer changes only the profile parameters listed in the run manifest. It cannot change the renderer, evaluator, rubric, references, data split, or acceptance rules.

Changes to those fixed components require a new run identifier and a new baseline.

Do not add blur, rotate the frame, generate content, or change geometry. Preserve the source image dimensions and composition.

## Prerequisites

Before execution, establish:

- A working renderer with versioned operations and a baseline profile.
- A permissioned corpus with fixed development settings.
- Reference images and an agreed visual rubric.
- A proposer model and a calibrated judge model.
- A run manifest with evaluation limits, spending limits, and stopping rules.
- Separate writable candidate storage and read-only evaluation inputs.

If a required component is missing, record the missing component and stop before running experiments. Never invent evaluation results or substitute unapproved external services.

## Run manifest

Record the following in a machine-readable manifest. Use JavaScript Object Notation (JSON) for structured artifacts.

| Field | Required contents |
| --- | --- |
| Identity | Run identifier, date, programme revision |
| Source data | Corpus version, image hashes, split membership |
| Rendering | Decoder, base transform, renderer versions, effective development settings |
| Baseline | Profile identifier, revision, exact file hash |
| Search space | Parameter names, units, bounds, constraints |
| Models | Proposer and judge identifiers, available version identifiers, inference settings |
| Evaluation | Prompt versions, reference hashes, presentation order policy, repeat policy |
| Acceptance | Promotion threshold, uncertainty method, artifact gates |
| Limits | Maximum candidates, judge calls, elapsed time, external spending |
| Randomness | Seeds for proposals, sampling, grain, and presentation order |

Hash exact file bytes with SHA-256, the 256-bit Secure Hash Algorithm. Keep full copies of the profiles and prompts used in a run.

Stop when any configured limit is reached. If a service cannot report a fixed model version, record that limitation in the receipt.

## Corpus and data splits

Use varied photographs rather than a collection consisting only of dark street scenes. Include hard sunlight, overcast light, interiors, night scenes, skin, bright objects, and smooth gradients.

Split by capture group before running experiments. Keep bursts, near-duplicates, and closely related frames together.

| Split | Purpose | Feedback available to proposer |
| --- | --- | --- |
| Search | Guide candidate changes | Per-image criticism and aggregate results |
| Promotion | Check whether promising changes generalise | Promotion decision and a limited summary |
| Final test | Assess the selected result | None until selection ends |

Repeated promotion feedback can cause overfitting. Use the final test set only after selecting the final candidate.

Fix split sizes in the manifest. Ensure each split covers more than one lighting condition. Use the same splits for all search methods.

## Search space

Start with approximately 12–20 effective parameters. Reduce the count if the renderer does not support a parameter precisely.

| Parameter group | Candidate changes | Constraints |
| --- | --- | --- |
| Monochrome conversion | Channel weights | Nonnegative; sum to one |
| Tone curve | Interior curve points | Fixed input positions; nondecreasing outputs |
| Local contrast | Amount and radius | Bounded; reject visible halos |
| Grain | Amplitude, size, tonal weighting | Deterministic; fixed evaluation seed |

Define numerical bounds before the run. Do not increase them to rescue a failed candidate.

Each proposal states one visual hypothesis and changes a small, related parameter group. For example:

> Shadows merge too early. Raise the lower curve slightly while retaining the black endpoint.

Keep several promising candidates when the budget permits. Permit occasional bounded restarts. This helps explore alternatives when a strict hill climb reaches a local optimum.

## Model roles

### Proposer

Give the proposer the current profile, allowed parameters, experiment history, and search-set criticism.

Require a structured response containing:

- A visual hypothesis.
- The exact parameter changes.
- The expected improvement.
- The likely failure case.

Validate the response before rendering. An invalid proposal consumes its proposal attempt and receives a recorded validation failure.

### Judge

Give the judge the fixed rubric, reference images, and anonymous candidate pairs. Each pair must show two renderings of the same source photograph.

Withhold proposal explanations, candidate names, search method, previous scores, and promotion status. Use a separate context from the proposer.

Require a structured response containing:

- Preference: A, B, tie, or neither.
- Observed differences in tone, texture, and preservation of important forms.
- Any accidental artifacts and their locations.
- An explicit indication when the evidence is insufficient.

Treat model confidence as a reported opinion. Do not interpret it as a calibrated probability.

The proposer and judge can use the same underlying model in separate contexts. Compare this arrangement with a separate judge model if calibration shows correlated errors.

## Judge calibration

Select the judge by agreement with the user's blind preferences on representative comparisons. Do not select it only from general model rankings.

Include near-ties, obvious failures, and intentional grain or clipping. Check whether the judge penalises the intended treatment.

Reverse candidate order on selected pairs and repeat selected identical comparisons. Measure order sensitivity and repeat disagreement.

Set acceptable agreement and stability thresholds before the optimisation run. If calibration fails, revise the rubric or judge configuration before continuing.

## Evaluation protocol

Render candidates with identical development settings, dimensions, colour management, and grain seeds.

Show the full image and fixed detail crops. Select crop locations before rendering candidates. Do not let the proposer choose flattering crops.

Randomise presentation order using a recorded seed. Keep the reference presentation identical for both candidates.

Evaluate style preference separately from accidental artifacts. Avoid a single generic image-quality score that always rewards smoothness or retained shadow detail.

Count an image as the evaluation unit. Multiple crops and repeated judge calls are observations of that image, not independent photographs.

Record wins, losses, ties, neither outcomes, artifact findings, and disagreement. A neither outcome flags an unsatisfactory pair; it does not count as an improvement.

## Experiment loop

1. Select an incumbent or a retained alternative from the search history.
2. Request one bounded proposal with a visual hypothesis.
3. Validate the candidate and render the search images.
4. Run anonymous comparisons and artifact checks.
5. Evaluate promising candidates on the promotion set.
6. Retain or discard the candidate under the frozen acceptance rules.
7. Record all results, costs, and the next search state.

Do not modify the evaluator to make a candidate pass. Do not delete failed experiments.

## Promotion rules

Set the minimum improvement and acceptable uncertainty during calibration. Freeze both in the manifest.

Promote a candidate only when it improves the paired promotion result and passes the artifact gates. Retain the incumbent when evidence is inconclusive.

Check performance by scene group. A gain on night scenes must not hide systematic failures on faces or bright daylight.

Keep thresholds sensitive to the intended treatment. Clipped blacks are not automatically an artifact. Their position and effect matter.

The final test evaluates the selected candidate against the original baseline and relevant search baselines. Do not use its criticism to resume the same run. A new search requires a new final test set.

## Search baselines

Compare these methods:

| Method | Proposal mechanism |
| --- | --- |
| Random search | Samples the frozen parameter space |
| Numerical optimisation | Proposes parameters from previous evaluations |
| Model-guided search | Proposes changes from visual criticism and experiment history |

Use the same initial profile, corpus, evaluator, and acceptance rules. Match evaluation budgets. Report total model spending, rendering time, and wall-clock time separately.

Use independent runs or several seeds when the budget permits. One successful run does not establish a general advantage.

## Artifacts and experiment history

Keep run artifacts below this experiment folder:

```text
runs/<run-id>/
  manifest.json
  baseline.look.json
  prompts/
  candidates/<candidate-id>/
    profile.look.json
    proposal.json
    renders/
    evaluations.json
    receipt.json
  results.jsonl
  selected.look.json
  report.md
```

JSONL means JSON Lines: one JSON record per line.

Each result records the candidate, parent, hypothesis, parameter changes, render environment, judge configuration, evaluation outcomes, decision, and cost.

Preserve candidates as separate artifacts. Retaining an improvement changes a recorded incumbent identifier; it does not require destructive version-control resets.

Do not commit files, publish results, or upload photographs as part of this programme without separate authorization for those actions.

## Stopping rules

Stop at the first applicable condition:

- The candidate, call, spending, or elapsed-time limit is reached.
- The configured plateau window contains no supported improvement.
- Judge calibration checks fail during the run.
- Required inputs, services, or renderer capabilities become unavailable.
- The user stops the run.

Save the history and selected incumbent before stopping. Report the reason and any incomplete comparisons.

## Completion criteria

A completed experiment supplies:

- A selected profile and reproducible image recipes.
- Blind comparisons against the original profile on the final test set.
- Results for the random and numerical search baselines.
- Scene-specific failures and judge disagreement.
- Measured evaluation cost, render time, and total elapsed time.
- A recommendation to retain the profile, revise the experiment, or reject the hypothesis.

Model-guided search succeeds only if its improvements survive evaluation outside the search set and remain useful to the user.

## Sources

- [Karpathy autoresearch](https://github.com/karpathy/autoresearch): bounded experiments, fixed evaluation, and retention of improvements.
- [Autoresearch programme](https://github.com/karpathy/autoresearch/blob/master/program.md): separation of mutable experiment code from fixed evaluation.
- [EditJudgeBias](https://arxiv.org/abs/2610.01670): multimodal judge sensitivity to irrelevant cues and candidate ordering.
- [AesBench](https://aesbench.github.io/): expert-labelled evaluation of aesthetic understanding.

The search design is a proposal. These sources do not establish that a model can optimise these photographic profiles successfully.
