# Passport Photo Studio — store screenshot specs

The complete, scriptable definition of the store screenshot set: which screen,
in what state, with what headline, at what size. `screenshots/screens.js` is the
machine-readable twin of this file — **change both together**.

Division of labour: the **store-publisher** agent captures the raw screenshots
from the app; this document owns *what is in them* and *how they are framed*.

---

## 1. The screenshot harness

The app ships a seeded demo state so every capture is identical between runs:

```bash
flutter run                 --dart-define=SCREENSHOT_MODE=true
flutter build ios --profile --dart-define=SCREENSHOT_MODE=true
```

**`--profile` is not optional.** Seeding grants the paid unlock, so a release
build with this define set would ship the in-app purchase free. `flutter build
ios` defaults to release, which is why the flag is spelled out here.
`AppInfo.screenshotMode` is anded with `!kReleaseMode` so such a build is inert
anyway — the two defences are deliberate, and
`test/screenshot_mode_release_guard_test.dart` fails if the constant's guard is
removed. `flutter run` and `flutter drive` are debug and unaffected.

`SCREENSHOT_MODE` seeds:

| Seeded | Value |
|---|---|
| Selected spec | **UK Passport**, 35 × 45 mm at 600 dpi — the primary market, and the default the picker opens on |
| Processed photo | A finished crop of the procedural demo portrait at the spec's exact pixel size, no camera or photo-library permission involved |
| Compliance report | All **seven** checks passing (the seventh, "Eye line within spec", landed in the 4c fix round), with the face-size figure derived from the spec so the numbers stay plausible |
| Entitlement | **Unlocked**, so the print sheet renders unwatermarked (see the exception for shot 05 below) |

`/result` and `/sheet` take the source path as a GoRouter `extra`; under
screenshot mode any non-null string works, e.g.
`context.push('/result', extra: 'demo')`.

### Two things the capture run must get right

- **Capture in light appearance.** The app follows the system setting and both
  themes are supported, but the whole set is framed as a white app screen on a
  navy field. A dark capture inside the frame loses that contrast and the set
  stops looking like one product.
- **Shot 05 needs the *locked* state.** The paywall's selling body — the
  free-vs-Pro table, the reassurance card and the priced button — only renders
  when the entitlement is not unlocked; under the seeded state it renders "Pro
  is active" instead, which sells nothing. The harness has to launch a second
  time with the entitlement overridden to locked (this is what
  `drift_sounds` does), and the price only resolves against a real store
  product, so capture on a device signed in to a sandbox / licence-test account
  once `com.froggyeye.passportphoto.pro` exists in the consoles. **If the price
  cannot be resolved, do not fake it** — `PurchaseService` correctly falls back
  to a bare "Unlock Pro", and a screenshot showing an invented figure is a Play
  rejection. Ship four shots rather than a dishonest fifth.

### The demo portrait

`lib/core/demo/demo_data.dart` draws the face procedurally — a flat
illustration, deliberately not a photograph of a real person. Do not replace it
with a real likeness without a licence; improving the illustration is fine.

The portrait is drawn directly at compliant framing and does **not** go through
`PhotoProcessor._computeCropRect`, so it never showed the chin-crop bug recorded
in `PIPELINE.md` — which also means it would have kept looking correct while the
real crop was wrong. Checked against the fix (2026-08-05): the illustration is
framed crown at 8.5% and chin at 78.5% of the height, so the face fills 70% and
the eye line sits 0.62 of the way up from the bottom. That is inside the UK
spec's 64–76% face band and inside the 0.50–0.80 ICAO eye-line envelope that
`test/crop_geometry_golden_test.dart` holds the real crop to — the screenshots
and the product now agree. **Re-check this if either the crop geometry or that
envelope changes**, because nothing fails automatically if they drift apart.

---

## 2. Canvas sizes

One size per device class is enough — both stores scale the rest down.

| Key | Store | Size | Required? |
|---|---|---|---|
| `ios69` | App Store, iPhone 6.9" | **1320 × 2868** | Required |
| `ios67` | App Store, iPhone 6.7" | 1290 × 2796 | Optional; belt-and-braces for older ASC behaviour |
| `android` | Google Play, phone | **1080 × 1920** | Required |

**No iPad set.** The app ships `TARGETED_DEVICE_FAMILY = 1` (iPhone only), so
App Store Connect does not ask for one.

Play also wants the **feature graphic, 1024 × 500** — already built at
`branding/feature_graphic.png`. Play tablet sets are optional and skipped
for 1.0.

Raw captures go in `screenshots/raw/<ios|android>/<slug>.png`. Both iPhone
canvases share the same `ios` raws; the frame crops rather than squashes, so the
exact capture resolution does not matter.

---

## 3. Framing and layout

One design, laid out on a 1080-unit-wide artboard and scaled to each canvas.

- **Background:** 160° linear gradient `#173F8E` → `#0C2350` → `#071634`, with
  the icon's own language repeated faintly: registration marks at the four
  artboard corners (Sky at 0.16) and a measuring rule of ticks across the
  bottom (0.12–0.22). No other decoration.
- **Headline:** centred, 74px/800, tracking −1.6px, `#EAF0FA`, two lines
  maximum, with exactly one phrase in Verify Green `#4ED89A` (named per shot
  below, so the accent lands on the payoff rather than on whatever word happens
  to fall last).
- **Subheadline:** centred, 32px/500, `#9FB2CE`, max width 840 units.
- **Device frame:** yes. A bezel (15-unit `#17305F` border, 76-unit top radius,
  inset `#2B4880` hairline, soft blue glow) that **bleeds off the bottom of the
  canvas**, so a tall capture is cropped from the bottom rather than squashed.
  The capture is scaled to the frame's **width**, never its height.
- **Device width is per-platform** (`device:` in `screens.js`): 940 units on
  both iPhone canvases, 830 on Play. It is the knob that decides how much of the
  screen survives. At 900 an iPhone capture ended within ~30 units of the canvas
  bottom, so a headline wrapping to a third line would have left the device
  floating instead of bleeding; 940 gives it room. Re-check the rendered set if
  a canvas size changes.

> **Do not switch to `object-fit: cover` here.** Against a fixed-height box it
> crops whichever axis overflows, and for a phone capture that is the *width* —
> it takes roughly 6% off each side, clipping the app-bar title and the edges of
> the compliance rows. Scaling by width means the only thing ever lost is the
> bottom of the screen, which is what the bleed is for.

Full implementation: `screenshots/screenshot.css` + `screenshots/screenshot.js`.

---

## 4. The set

Ordered by marketing priority. The first **three** carry the hooks — App Store
search results show three shots, and most people never swipe past them — so they
are the outcome (*it tells you before you print*), the money (*it replaces the
booth*) and the differentiator (*your photo stays on the phone*).

> Copy rule (see `BRAND.md`): lead with the outcome, one idea per shot, under
> six words, no trademarked terms, and **never promise acceptance** — not
> "approved", not "guaranteed", not "compliant". The reasoning behind every
> line below is in `docs/ASO.md` §5.

### 01 — `01_result` · Review (`/result`)

- **Headline:** Seven checks before you print *(accent: "Seven checks")*
- **Subheadline:** Pass or fail on face size, eye line and background.
- **State:** UK passport spec, the seeded crop on screen at 35 × 45 mm, the spec
  line reading `827 × 1063 px · 35 × 45 mm · Background: white`, and the
  compliance card reading **7 / 7 passed** with every row green. Scrolled so the
  photo and the whole checklist are both in frame.
- **Why first:** the reason someone pays is not the crop, it is knowing the crop
  is right. This is the only screen in the category that shows its working.
- **Care — this headline was rewritten in stage 5.** It used to read "Passport
  photos approved first time", which promises acceptance in four words on the
  most-viewed surface in the listing. `BRAND.md` bans exactly that, App Review
  can ask us to substantiate it, and `assets/specs/SOURCES.md` is candid that
  some eye-line figures are derived rather than published. Do not restore it,
  and do not reach for "approved", "guaranteed" or "compliant" as a synonym.
  Note also that the subheadline says "in plain English" rather than "against
  the official spec": the same claim without the adjective that shades toward
  government endorsement.

### 02 — `02_sheet` · Print sheet (`/sheet`)

- **Headline:** Skip the photo booth *(accent: "photo booth")*
- **Subheadline:** Print a 4×6" sheet at any counter — booths charge far more.
- **State:** The 4×6" sheet preview with Pro unlocked, so it renders
  unwatermarked: the tiled UK photos at 300 dpi with their cutting gaps, and the
  "Save print sheet" button visible.
- **Why second:** it answers "why not just go to the booth" with a picture. The
  sheet is the artefact you physically take to a counter.
- **Care:** the currency figure that used to be here ("a booth charges £10–15")
  was dropped in stage 5. One English screenshot set serves the UK, US, EU, IN
  and AU storefronts, and a £ range is wrong or meaningless in most of them —
  it was also the only price claim in the set we would have had to defend. Do
  not reintroduce a number.

### 03 — `03_home` · Home (`/`)

- **Headline:** Your photo never leaves your phone *(accent: "never leaves your phone")*
- **Subheadline:** No ads. No account. Your photo is never uploaded.
- **State:** Home with the UK passport spec selected in the document card, both
  source-photo tiles enabled, and the footer line "All processing happens on
  your device. No photos leave your phone." in frame.
- **Why it earns a shot, and why third:** the category is full of apps that
  upload a face to a server; this one does the whole pipeline on the device with
  a bundled model, verified in the release AAB. That is a differentiator worth a
  full screenshot. It sits at three rather than four because the country-count
  shot is the weaker of the two — see shot 04.
- **Care — this subheadline was rewritten in stage 5 (security finding SEC-11).**
  It used to read "No ads. No tracking. No account. Everything runs offline."
  Two of those four clauses are **false**: the bundled ML Kit SDK reports a
  device identifier and diagnostics to Google, which is what the corrected Apple
  and Play privacy labels now declare. A screenshot asserting "everything runs
  offline" beside a Data safety form declaring Device ID collection is a
  contradiction on the record. Each surviving clause was re-verified against the
  built app: no ad SDK in `pubspec.yaml`, no account or backend anywhere in the
  codebase, and no photo leaves the device. **Never restore "no tracking",
  "everything runs offline", "no network" or "No data collected" to this or any
  other shot.** The headline is precise and checkable and stays as it is.

### 04 — `04_picker` · Country & document picker (`/picker`)

- **Headline:** Every country, free *(accent: "free")*
- **Subheadline:** Passport, visa and ID specs — nothing behind the paywall.
- **State:** The picker at the top of the unfiltered list, search field empty, so
  the breadth reads at a glance and the UK row shows as selected. **No lock
  badges anywhere** — specs are never gated, and this shot is the proof.
- **Care — this headline was rewritten in stage 5.** It used to read "21
  countries, 30 documents". Rivals in this category advertise "150+ countries
  and 500+ document types", so a headline that leads with our count invites the
  one comparison we lose (`docs/ASO.md` §1). The shot's real content is that
  *nothing is locked*, which no rival in the competitive set can claim. The
  actual counts belong in the long description, next to the ICAO and Schengen
  fallbacks that cover everything else.

### 05 — `05_pro` · Paywall (`/pro`)

- **Headline:** One payment. No subscription. *(accent: "No subscription.")*
- **Subheadline:** Unlock full-resolution exports and the print sheet. Once.
- **State:** The paywall in its **pre-purchase** state — the free-vs-Pro table
  with every country and the full report sitting in the free column, the "Paid
  once, yours for good" card, and an "Unlock Pro — <price>" button showing a
  real store price. See §1 for how to capture it.
- **Care:** this shot is the honesty claim. Real price or no price; never a
  placeholder, never a struck-through "was". It is also Apple's mandatory **IAP
  review screenshot** for `com.froggyeye.passportphoto.pro`.

---

## 5. Rendering

```bash
cd store_assets/screenshots
./render.sh                      # every platform
./render.sh ios69 android        # just these
```

Output: `out/<platform>/<slug>.png` at exactly the sizes in §2, ready to upload.
Frames render before the captures exist — a missing raw draws a branded
"capture missing" card naming the screen and the state it needs, so the whole
set can be reviewed and the copy signed off before a single screenshot is taken.

`index.html` is a live gallery of the set with a platform switcher.
