# RFC 0001 Portable photographic looks for RAW images

Status: Exploratory draft  
Date: 2026-10-29  
Scope: A minimum viable product for describing and applying photographic looks across RAW formats

## 1 Purpose

Represent a photographic look as a portable, versioned description of image transformations. Apply that description after camera-specific RAW development.

The first five looks interpret the rendering associated with Daido Moriyama, Garry Winogrand, Henri Cartier-Bresson, and Joel Meyerowitz. Meyerowitz has separate street colour and coastal light profiles.

These are creative interpretations. They do not reproduce a photographer's complete practice, a particular film stock, or an authenticated print.

The central proposal is:

```text
RAW file + development settings
             |
       RAW developer
             |
   defined linear RGB image
             |
     base display rendering
             |
   look + image adjustments
             |
      texture and export
```

A look is independent of its source camera. Its appearance still depends on the source photograph and RAW developer.

## 2 Product boundary

The minimum viable product (MVP) lets you import a supported RAW file, compare five looks, adjust their strength, and export an image. It also saves an editable recipe.

The MVP includes:

- One reference renderer and one RAW decoder adapter.
- A versioned look format using JavaScript Object Notation (JSON).
- Five bundled profiles.
- Exposure and white balance adjustments before the look.
- Strength, contrast, and grain controls for the look.
- A colour-managed preview and a standard dynamic range export.
- A recipe that records the source, development settings, profile, and renderer.

The architecture accepts any RAW format through adapters. The first release supports only the formats and camera models verified for its chosen adapter. An unsupported file receives an explicit error.

The MVP excludes capture, automatic composition, synthetic motion blur, object editing, semantic masks, and high dynamic range export. It also excludes automatic scene classification and learned style transfer.

## 3 What a look can express

Separate the photographer's visual language into three categories.

| Category | Examples | MVP treatment |
| --- | --- | --- |
| Rendering | Black density, tonal transitions, colour separation, grain | Encode as transformations |
| Capture | Viewpoint, lens perspective, motion, depth of field | Preserve the source photograph |
| Selection and sequence | Choice of frame, repetition, book rhythm | Describe as context; do not execute |

This boundary prevents a Moriyama profile from adding random blur or a Winogrand profile from rotating every image.

A profile may include a human-readable description of suitable source material. The renderer does not enforce that description.

## 4 Four separate artifacts

| Artifact | Purpose | Changes when |
| --- | --- | --- |
| Look descriptor | Defines a reusable look | The look is edited |
| Image recipe | Records choices for one source image | You change an adjustment |
| Render receipt | Records the resolved execution environment | An image is rendered |
| Rendered image | Contains the final pixels | An image is exported |

The look descriptor must not contain camera-specific white balance, exposure compensation for an individual image, or an absolute source path.

The recipe identifies the source using a SHA-256 hash, where SHA means Secure Hash Algorithm. It identifies the exact look file using another SHA-256 hash.

Hash the exact file bytes. This draft does not require a JSON canonicalisation system.

## 5 Boundary between development and the look

### 5.1 RAW developer responsibilities

The adapter handles sensor decoding, black levels, linearisation, required sensor reconstruction, camera colour conversion, and white balance.

The adapter must account for the source format. A mosaiced sensor image needs demosaicing. A previously demosaiced computational RAW image must not receive that operation again.

The developer returns an opaque, floating-point RGB image with these properties:

| Property | Required value |
| --- | --- |
| Primaries | ITU-R BT.2020 |
| White point | D65 |
| Transfer function | Linear |
| Orientation | Applied once; top-left origin |
| Alpha | Opaque |
| Numeric range | Extended; values above 1 remain available |
| Precision | At least 16-bit floating point storage; 32-bit arithmetic for sensitive operations |

ITU-R is the International Telecommunication Union Radiocommunication Sector. BT.2020 supplies the working colour primaries; the MVP does not use its television transfer function.

Development settings must record the exposure scale and resolved white balance. A value of 1 is a working reference level, not a universal sensor saturation level. An exposure adjustment of one stop multiplies linear RGB by two.

The adapter must document how camera baseline exposure and embedded rendering instructions affect its output. It must not silently apply an additional creative look.

### 5.2 Computational RAW inputs

Some RAW files already contain substantial image processing. Apple ProRAW, for example, can contain fused, demosaiced data and a suggested rendering. The developer must distinguish those stored pixels from optional rendering instructions. [Apple: Capture and process ProRAW images](https://developer.apple.com/videos/play/wwdc2021/10160/)

The adapter declares any processing it cannot undo. The standard does not promise an untouched sensor image.

### 5.3 Base display rendering

The reference renderer converts the developed image into a bounded display image before applying the creative look.

This base stage provides highlight compression and gamut mapping. It is shared across all five profiles and has its own version identifier.

The base stage must retain highlight headroom until it performs its tone mapping. It must define the treatment of negative values and out-of-gamut colours.

For the prototype, choose one documented base transform and freeze its implementation and test fixtures. The choice of transform remains an open design decision in this draft.

The look input is floating-point, encoded sRGB in the range 0 to 1. The name sRGB identifies the standard RGB colour space. Every look operation declares whether it operates on this encoded representation or a linear conversion.

Strength zero returns this base rendering. It does not return the camera's embedded preview or a particular application's default rendering.

## 6 Look descriptor

Use a restricted sequence of named operations. Each operation has a versioned implementation identifier and explicit parameters.

Avoid executable scripts and platform-specific filter names in portable descriptors. A renderer must reject an operation it cannot execute.

The initial operation set is:

| Operation | Parameters | Meaning |
| --- | --- | --- |
| `monochrome` | Channel weights | Converts source colours into grey values |
| `tone_curve` | Ordered input/output points | Controls blacks, midtones, and highlights |
| `local_contrast` | Amount, radius | Separates nearby tones at a specified spatial scale |
| `colour` | Saturation, shadow tint, highlight tint | Controls colour intensity and tonal colour balance |
| `grain` | Amount, size, tonal weighting | Adds deterministic monochrome texture |

Every operation definition must specify its colour domain, parameter units, interpolation, edge handling, clipping, and identity values. Names alone are insufficient for conformance.

The descriptor format is exploratory until those operation definitions and reference vectors are published together. An early renderer must label its operation set as experimental.

### 6.1 Tone curves

Represent curves as points with input and output values from 0 to 1. Inputs must increase strictly. Outputs must be nondecreasing.

Include endpoints at input 0 and input 1. Use piecewise linear interpolation for the MVP. This avoids different spline implementations producing different looks.

The operation definition must state how it applies the curve to colour images. Applying one curve independently to RGB channels is different from modifying luminance.

### 6.2 Spatial parameters

Express radii relative to a reference image whose long edge is 2,048 pixels. Scale the radius with output dimensions.

Anchor grain coordinates to the oriented source image. Use a seed stored in the recipe. A new preview must not generate a new random pattern.

Render a full preview using the same coordinate system as the export. When downsampling changes the appearance of fine grain, provide a full-resolution detail view.

### 6.3 Strength

Treat strength as one explicitly defined operation rather than an arbitrary scaling of every parameter.

The proposed MVP rule is:

```text
B = base image converted to linear sRGB
L = clean styled image converted to linear sRGB
s = strength, between 0 and 1
mixed = (1 - s) * B + s * L
```

Convert `mixed` back to encoded sRGB. Apply grain afterwards, with its amplitude multiplied by `s`.

Intermediate monochrome strengths retain some source colour. This is expected behavior under this rule.

### 6.4 Illustrative descriptor

These values are tuning candidates. They do not define an approved visual match.

```json
{
  "format": "photographic-look",
  "format_version": "0.1",
  "id": "dense-monochrome",
  "revision": 1,
  "name": "Dense monochrome",
  "references": ["Daido Moriyama"],
  "input": "display-srgb-float-v1",
  "operations": [
    {
      "op": "monochrome",
      "implementation": "experimental-mono-encoded-v1",
      "weights": [0.28, 0.60, 0.12]
    },
    {
      "op": "tone_curve",
      "implementation": "experimental-grey-curve-v1",
      "points": [
        [0.0, 0.0],
        [0.12, 0.025],
        [0.30, 0.17],
        [0.50, 0.48],
        [0.75, 0.88],
        [1.0, 1.0]
      ]
    },
    {
      "op": "grain",
      "implementation": "experimental-grain-v1",
      "amount": 0.035,
      "size_reference_px": 1.6,
      "tonal_weighting": "midtones"
    }
  ]
}
```

Do not interpret `amount: 0.035` as portable until the grain operation defines its amplitude and distribution.

## 7 Initial profiles

The first release uses descriptive names. Photographer references remain in explanatory metadata.

| Profile | Reference | Rendering hypothesis | Avoid |
| --- | --- | --- | --- |
| Dense monochrome | Moriyama | Deep blacks, steep tonal separation, coarse grain, strong texture | Mandatory blur, universal shadow destruction |
| Descriptive monochrome | Winogrand | Readable midtones, firm contrast, restrained grain, spatial detail | Automatic tilt, halos around figures |
| Balanced monochrome | Cartier-Bresson | Smooth greys, clear dark shapes, controlled highlights, subtle grain | Flattened blacks, excessive smoothing |
| Street colour | Meyerowitz street work | Clear colour differences, moderate contrast, restrained texture | Uniform saturation boosts |
| Coastal light | Meyerowitz Cape Light | Gentle transitions, luminous highlights, preserved warm/cool relationships | A global orange tint, universal pastel colours |

These hypotheses require visual review on varied photographs. The profile values become stable only after that review.

The MVP permits different parameter values but uses the same operation vocabulary across profiles. It does not require every profile to use every operation.

## 8 Image recipe and render receipt

The recipe records:

- Format version and source hash.
- Decoder adapter identifier and requested version.
- Development exposure and white balance mode or values.
- Base transform identifier and version.
- Look identifier, revision, and exact file hash.
- Strength, supported user overrides, and grain seed.
- Export dimensions, format, colour space, and metadata policy.

Use explicit defaults. An omitted optional field receives the default defined by that format version. Reject non-finite numbers, unsupported overrides, and invalid ranges.

The receipt adds the resolved decoder version, operating system build, renderer version, effective settings, and output hash. It also records any supported fallback.

Do not silently replace an unavailable decoder or base transform when replaying a recipe. Return an incompatibility result and let the caller request a new render environment.

RAW decoding can vary across environments. Apple's decoder documentation explicitly distinguishes similar appearance from identical bits. The standard therefore separates look conformance from decoder reproducibility. [Apple: decoderVersion](https://developer.apple.com/documentation/coreimage/cirawfilter/decoderversion?changes=____5_8_2)

## 9 Adaptation and user controls

The MVP uses manual exposure and white balance, with as-shot white balance as the default. It does not normalise each image to the same histogram.

Keep a night scene dark when the source and development settings make it dark. Preserve differences between warm and cool illumination.

Provide these controls:

| Control | Range or behavior |
| --- | --- |
| Look | Five bundled profiles |
| Strength | 0 to 1; default 1 |
| Exposure | Minus 4 to plus 4 stops; default 0 |
| White balance | As shot or explicit temperature and tint |
| Contrast | A documented override of the profile's curve |
| Grain | 0 to twice the profile amount; default 1 times |

The contrast control must resolve into an explicit curve stored in the recipe. The renderer must not depend on a hidden application slider.

These controls belong to this RFC's import product. The camera milestone in [specification 0001](../specs/0001-street-camera-mvp.md) section 10 exposes none of them.

Automatic exposure, noise-aware grain, and subject masks remain future extensions. They require their own versioned analysis and resolved parameters.

## 10 Application workflow

1. Import a supported original RAW file.
2. Develop one shared base image and show the five previews.
3. Select a look and adjust exposure, white balance, or strength.
4. Inspect the full-resolution detail view when needed.
5. Export the rendered image and save the recipe.

Keep the original file unchanged. The before/after comparison uses the shared base rendering, with a separate option to view an embedded camera preview when available.

The reference renderer should expose the same operations through a callable library. A graphical editor is one client of that library.

## 11 Output and failure behavior

Require a full-resolution JPEG export with an embedded sRGB colour profile. Require a lossless PNG export for reference comparisons. JPEG means Joint Photographic Experts Group; PNG means Portable Network Graphics.

Apply orientation to the pixels and write a normal orientation tag. Preserve capture time and camera identity when available. Omit location metadata by default and record that choice.

Do not export a new RAW file. Save the recipe separately.

Return distinct errors for unsupported input, corrupt input, unavailable decoder, invalid profile, unknown operation, source hash mismatch, and insufficient resources.

If a full-resolution render cannot complete, retain the recipe and allow an explicit smaller export. Do not silently reduce dimensions.

A cache key includes the source hash, resolved development settings, base transform, look bytes, overrides, seed, output size, and renderer environment.

## 12 Validation and acceptance

### 12.1 Numerical validation

Use synthetic ramps, colour patches, edge patterns, and flat fields before testing photographs.

- Strength zero reproduces the shared base before output encoding.
- A full-strength monochrome profile produces equal RGB channels within numerical tolerance.
- Tone curves preserve their specified monotonicity.
- The same seed and coordinates produce the same grain field within numerical tolerance.
- Grain size remains visually consistent at equivalent display sizes.
- Invalid data and unknown operations produce errors.

For look conformance, supply a decoded base image and compare floating-point pixels before export encoding. Publish tolerances with each reference vector. Do not compare compressed JPEG bytes.

Test RAW adapters separately using a fixed decoder environment and documented fixtures.

### 12.2 Photographic validation

Build a corpus of at least 24 permissioned RAW files from at least three camera families. Include mosaiced and computational RAW inputs when the adapter supports them.

Cover hard sunlight, overcast light, night scenes, mixed lighting, several skin tones, bright saturated objects, and smooth gradients. Include both sparse and crowded compositions.

Review all profiles on the same sources. Record failures such as lost facial detail, colour clipping, halos, banding, and grain that obscures subjects.

Ask reviewers to describe the differences without seeing the photographer references. Check whether the five profiles remain distinguishable and useful.

### 12.3 Prototype exit criteria

- All five profiles render through one shared pipeline.
- A saved recipe reopens with the same effective settings.
- The renderer reports its actual input support.
- Preview and export use the same operations and colour management.
- The original RAW file remains unchanged.
- The reference vectors and corpus review pass their documented criteria.
- Preview latency, export latency, and peak memory are measured on named hardware before a release target is chosen.

This draft does not claim measured performance or visual validation.

## 13 Prototype sequence

1. Choose a decoder adapter and define its linear output contract.
2. Compare candidate base transforms and freeze one for the prototype.
3. Implement monochrome conversion, curves, and deterministic grain.
4. Tune the three monochrome profiles against the corpus.
5. Add colour operations and tune the two colour profiles.
6. Publish the operation definitions, reference vectors, and recipe examples.
7. Build the minimal comparison interface and test end-to-end replay.

## 14 Open decisions

| Decision | Proposed direction | Evidence needed |
| --- | --- | --- |
| Base transform | One shared, versioned transform | Highlight and colour comparisons across the corpus |
| First decoder | One maintained adapter with broad verified support | Format coverage and linear output behavior |
| Colour operations | Small explicit operator set before lookup tables | Whether the two colour looks need more selective control |
| Local contrast | Optional until it demonstrates value | Detail gains versus halos and noise amplification |
| Grain model | Deterministic monochrome field | Appearance at several output sizes |
| Cross-renderer portability | Standardise the look boundary first | Reference vector agreement from a second renderer |

A three-dimensional lookup table can become a later operation. It cannot encode grain, spatial contrast, or the entire RAW development process.

## 15 Sources and context

The architecture and parameter format are proposed design choices. The following sources establish input-format constraints and the photographic references.

- [Adobe DNG resources](https://www.adobe.com/support/downloads/dng/dng_sdk.html): Digital Negative (DNG) specifications and development resources.
- [Apple: Capture and process ProRAW images](https://developer.apple.com/videos/play/wwdc2021/10160/): computational RAW data and embedded rendering instructions.
- [Apple: decoderVersion](https://developer.apple.com/documentation/coreimage/cirawfilter/decoderversion?changes=____5_8_2): decoder selection and limits on bitwise repeatability.
- [LACMA: Fracture](https://www.lacma.org/art/exhibition/fracture-daido-moriyama): Moriyama's contrast, grain, blur, and fragmented viewpoints.
- [Denver Art Museum: Winogrand](https://www.denverartmuseum.org/en/edu/lesson/more-things-change-more-they-stay-same): tilt as composition rather than a rendering effect.
- [Fondation Henri Cartier-Bresson](https://www.henricartierbresson.org/en/hcb/): geometry, intuition, and timing.
- [Joel Meyerowitz: selected works](https://www.joelmeyerowitz.com/): separate street and Cape Light bodies of work.

Research and design date: 2026-10-29.
