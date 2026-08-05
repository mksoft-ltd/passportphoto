# Passport Photo Studio — brand guide

The source of truth for how this app looks, in the product and in the stores.
The palette is taken from the app's own theme (`lib/app/theme.dart`), not
invented alongside it — `BrandColors` there and the tables here are the same
numbers, and if you change one you change the other.

Publisher: Froggy Eye Ltd · © 2026 Froggy Eye Ltd · froggyeye.com

---

## Personality

**Precise, plain, private.** Someone opens this app because a government form
told them to, usually once every ten years, usually slightly anxious about
getting it wrong. The design's job is to look like it knows the rules and to
get out of the way.

Three words: **measured**, **official**, **honest**.

- *Measured* — the product is millimetres, eye lines and DPI. The visual
  language repeats that: registration marks, rules that meet an edge, tabular
  numbers, and photo cards drawn at the real 35:45 aspect.
- *Official* — deep blue, high contrast, no decoration that a passport office
  would not print. It should feel adjacent to a document, not to a filter app.
- *Honest* — the app tells you when the photo will fail, keeps every country
  free, and charges once. The design never manufactures urgency to compensate.

**Deliberately avoided:** camera bodies, shutter buttons, photo-booth curtains,
polaroid frames, flags, passport-crest imagery or anything that could be read
as a government endorsement, "AI"-sparkle gradients, before/after sliders,
countdowns on the paywall, and stock photography of real faces.

**Never imply official status.** No crowns, coats of arms, HMPO/ICAO logos, or
wording that suggests government approval. The app checks a photo against a
published spec; it does not certify anything, and the creative must not claim
otherwise.

---

## Colour palette

The app follows the system light/dark setting, and both are first-class. All
store creative uses the **Ink Navy** family, with light-mode captures inside the
device frame — a white app screen on a navy field is the highest-contrast way to
present a document tool.

### Core

| Role | Hex | Where it is used |
|---|---|---|
| **Passport Blue** | `#1E5BD8` | Primary. Buttons, selection, the figure in the mark, links |
| **Ink Navy** | `#0C2350` | The icon plate, adaptive-icon background, every store background |
| **Ink Top** | `#173F8E` | Top-left of the plate and store gradients |
| **Ink Deep** | `#071634` | Bottom-right of the same gradients |
| **Sky** | `#7FB0FF` | Passport Blue lifted onto navy: registration marks, dark-mode accents |
| **Verify Green** | `#0F7A50` light / `#4ED89A` dark | A compliance check that **passed**, and nothing else |

Verify Green is the one semantic colour in the app: it means *this check
passed*. It is never used for a button, a link, or decoration. Failures use the
Material `error` role. Colour is never the only signal — every check row also
carries its own icon and a written reason.

### Light theme (`buildLightTheme`)

| Role | Hex |
|---|---|
| Surface / scaffold — "Paper" | `#F7F9FC` |
| Surface container lowest | `#FFFFFF` |
| Surface container low | `#F2F5FA` |
| Surface container | `#ECF1F8` |
| Surface container high | `#E5ECF6` |
| Surface container highest | `#DEE6F2` |
| On surface | `#101A2C` |
| On surface variant | `#48566E` |
| Outline | `#7B8AA3` |
| Outline variant | `#C9D4E4` |
| Primary container / on | `#DCE6FF` / `#062A6B` |

### Dark theme (`buildDarkTheme`)

| Role | Hex |
|---|---|
| Surface / scaffold — "Night" | `#0D1524` |
| Surface container lowest | `#070C17` |
| Surface container low | `#121B2C` |
| Surface container | `#172236` |
| Surface container high | `#1E2B42` |
| Surface container highest | `#26354F` |
| On surface | `#E5ECF8` |
| On surface variant | `#A9B7CD` |
| Outline | `#6D7C94` |
| Outline variant | `#2E3D55` |
| Primary / on | `#A9C6FF` / `#062A6B` |

Material's own neutrals off a blue seed run warm violet, which reads as a
consumer app. Both surface families above are cool and near-neutral on purpose,
so the only saturated things on screen are the photo and the checks.

**Paper and Night are load-bearing beyond the theme:** they are also the launch
screen colours in `pubspec.yaml` and the Android `NormalTheme` window
background. All three must match or the app flashes on cold start.

### Store-creative extras

| Role | Hex | Notes |
|---|---|---|
| Text primary | `#EAF0FA` | Headlines on navy |
| Text secondary | `#9FB2CE` | Subheads |
| Device bezel | `#17305F` | Screenshot frame, with a `#2B4880` hairline |
| Accent word | `#4ED89A` | Exactly one phrase per screenshot headline |

---

## Typography

- **Product UI:** the Flutter Material 3 default — SF on iOS, Roboto on
  Android. Keep it. It is what a form-filling utility should look like and it
  carries no licensing baggage.
- **Store creative:** the system UI stack (`-apple-system,
  BlinkMacSystemFont, 'Segoe UI', Roboto`) at **800** for headlines, **500–600**
  for subheads.
- **Headlines:** 74px, tracking −1.6px, `text-wrap: balance`, two lines
  maximum, sentence case. Exactly one phrase per headline set in Verify Green.
- **Measurements are data, not prose.** Sizes, DPI and pixel counts
  (`35 × 45 mm`, `827 × 1063 px`, `600 dpi`) always render in the same style as
  each other and never get rounded for looks.
- **Weight discipline:** headings w600, body regular. Nothing in the product UI
  is heavier than w700.

---

## The mark

**The spec frame.** A document photo card at the true 35:45 passport ratio,
with print registration marks at its corners, a head-and-shoulders figure
positioned on the spec's eye line, and a green approval tick overlapping the
bottom-right corner. It says *measured portrait, approved* without a camera, a
booth or a shutter — none of which is what the app does.

- The card is white on Ink Navy; the figure is Passport Blue; the registration
  marks are Sky; the tick is Verify Green with a navy separating ring.
- The eye-line rule runs in from both card edges and **stops at the head**, so
  it reads as a measurement meeting the eyes rather than a line struck through
  a face.
- The tick is what survives at 48 px, which is why it is large and why it sits
  outside the card's silhouette rather than inside it.

Geometry lives in `branding/make_branding.py` — edit the constants there, never
the emitted SVG. Two coverage values are **computed, not chosen**
(`coverage_for_round_mask`): the registration marks sit at the mark's extremes,
so a hand-picked size gets them clipped by a round launcher mask or by the
Android 12 splash circle.

**Do:** keep the tick, keep the corner marks, keep the card white.
**Don't:** add text to the icon, add a flag or crest, tilt it, replace the
figure with a photograph, or recolour the tick to blue.

---

## Tone of voice

Write like a competent clerk who is on your side: tell people what will happen,
what it costs, and what could go wrong.

- **Lead with the outcome.** "Passport photos approved first time" beats
  "ICAO-compliant cropping engine".
- **Short sentences. Plain words.** No "AI-powered", "instantly", "magically",
  "professional-grade", "studio quality".
- **Never promise acceptance.** The app checks a photo against a published
  spec — say *"checked against the official spec"*, never *"guaranteed to be
  accepted"*. No government body has approved this app.
- **Be plain about money.** "One payment. No subscription." Always say what the
  free version keeps: every country, the crop, and the full report.
- **Name the privacy claim precisely.** "Photos never leave your phone" is true
  and checkable — there is no network code in the app. Do not stretch it into
  "military-grade" or "encrypted".
- **Second person, present tense.** "Pick the country, take the photo, print
  the sheet."

### Words we use

spec · check · crop · eye line · millimetres · print-ready · offline ·
one-time · free

### Words we don't

guaranteed · approved by · official partner · AI-powered · instantly ·
professional · limited time · subscribe · trial · unlock your

---

## Accessibility

- Contrast: `#101A2C` on `#F7F9FC` ≈ 15:1; `#48566E` on `#ECF1F8` ≈ 6.4:1;
  `#E5ECF8` on `#0D1524` ≈ 14:1. Any new text colour must clear 4.5:1 on the
  surface it actually sits on, in both themes.
- Verify Green is a *reinforcement*, never the message: a passed check shows a
  tick icon, a label and a written reason, so the report survives being read in
  greyscale or by someone with deuteranopia.
- Touch targets ≥ 48×48. The primary export buttons are 56 tall — this app is
  used one-handed while holding a phone at arm's length.
- Text scaling honoured to 1.4×; no screen assumes a fixed line count, and the
  compliance rows wrap rather than truncate.
- Every screen must be usable without the camera: gallery import is a
  first-class path, not a fallback, because permission-denied is a normal state
  here rather than an error.

---

## Asset inventory

Everything is generated from source in `branding/`; see `README.md` in this
folder for the commands.

| Asset | Size | Source |
|---|---|---|
| App icon (iOS, legacy Android) | 1024² opaque, no alpha | `branding/icon_master.svg` |
| Adaptive icon foreground | 1024² transparent | `branding/icon_foreground.svg` |
| Adaptive icon background | `#0C2350` flat | `pubspec.yaml` |
| Android 12+ splash icon | 1152² transparent on `#0C2350` | `branding/splash_icon_android12.svg` |
| Splash logo (plated) | 768² transparent | `branding/splash_logo.svg` |
| Play feature graphic | 1024 × 500 | `branding/feature_graphic.svg` |
| Store screenshots | see `screenshot_specs.md` | `screenshots/` |
