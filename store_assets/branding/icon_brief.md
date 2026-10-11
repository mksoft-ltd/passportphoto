# Brief for generating new store icons and screenshots — Passport Photo Studio

Paste everything below this line into the image/LLM tool.

---

You are designing the app icon and store screenshot thumbnails for **Passport Photo Studio**, an iOS and Android app by Froggy Eye Ltd.

## What the app does

The user takes or picks a photo of themselves, chooses a country document (UK passport, US passport, Schengen visa, Indian OCI, and 25 more), and the app crops it to the exact millimetre spec and runs eight compliance checks: face size, eye-line position, head tilt, eyes open, neutral expression, plain background, lighting/shadows, and glasses/headwear rules. It then saves a print-ready file at 300/600 dpi or a 6×4" print sheet. Everything runs on the phone; the photo never leaves the device. It never retouches, beautifies or replaces the background. Free for every country; one £4.99 payment unlocks the full-resolution file.

## Personality

**Precise, plain, private.** People open this app because a government form told them to, once every ten years, slightly worried about getting it wrong. The design should look like it knows the rules and then get out of the way. Three words: **measured, official-adjacent, honest.** It should feel like a document tool, not a camera app or a selfie/filter app.

## Current icon (improve on this; do not discard the idea)

A white document-photo card at the true 35:45 passport ratio, centred on a deep navy plate with a subtle diagonal gradient. Inside the card is a simple blue head-and-shoulders silhouette. A thin light-blue eye-line rule runs in from each card edge and stops at the head. Four light-blue print registration marks (corner brackets) sit at the plate's corners. It reads as "measured portrait". Weaknesses to fix: it is a little flat and generic at small sizes, the silhouette is a plain oval, and the composition could have more depth and craft while staying restrained.

## Colour palette (use these exact values)

- Passport Blue `#1E5BD8` — primary, the figure in the mark
- Ink Navy `#0C2350` — the icon plate and every store background
- Ink Top `#173F8E` → Ink Deep `#071634` — the top-left to bottom-right gradient on plates and backgrounds
- Sky `#7FB0FF` — registration marks and accents on navy
- Paper `#F7F9FC` / white `#FFFFFF` — the photo card
- Text on navy: primary `#EAF0FA`, secondary `#9FB2CE`
- Verify Green `#4ED89A` — ONLY for exactly one phrase in a screenshot headline. Never in the icon, never as a shape.

## Hard rules (the stores have already rejected this app for breaking them)

1. **No approval or award imagery anywhere in store art**: no tick/checkmark, badge, seal, rosette, laurel, ribbon, medal, star, star-rating, shield, stamp, or "verified"/"approved" chip. Google Play rejected a previous icon for a green tick badge.
2. **Nothing that implies government or official status**: no flags, crests, coats of arms, eagles, lions, passport-cover imagery, embossed emblems, or ICAO/HMPO-style logos. No words like approved, accepted, certified, guaranteed, official, government.
3. **No camera bodies, shutter buttons, photo-booth curtains, polaroid frames, lens flares, "AI" sparkles, or gradients that read as a consumer photo app.**
4. **No text in the icon.** No photographs of real faces in the icon; in screenshots, use only the supplied app captures or a clearly illustrated, non-photographic figure.
5. Keep the icon **symmetric and centred**, legible at 48 px, and do not tilt it.

## Deliverables

### A. App icon — 3 to 4 distinct concepts, each as:
- **iOS**: 1024×1024 px, PNG, no transparency, square corners (Apple applies the rounding; do not pre-round).
- **Google Play store icon**: 512×512 px, 32-bit PNG, square corners (Play applies its own mask).
- **Android adaptive icon**: separate foreground and background layers at 1080×1080 px (432 dp). All meaningful foreground content must sit inside the central 66% circle (the safe zone) because launchers mask the outer area; the background layer is a flat or gradient Ink Navy.
- Show each concept at 1024, 180, 48 and 29 px side by side so legibility at small sizes can be judged.

Concept directions to explore (keep the white card + navy plate + corner marks as the family resemblance):
1. The current spec-frame idea, refined: better silhouette proportions, a crisper card with a soft edge shadow, marks with more presence.
2. The card seen with a subtle depth cue, such as a second card edge peeking behind it (print sheet), still symmetric.
3. The eye-line rule and face-height measurement expressed as faint tabular dimension lines, like a technical drawing, so the icon reads "measured".
4. A bolder minimal version: card, figure, marks only, maximal contrast, built to survive 29 px.

### B. Store screenshots (thumbnails) — a set of 5 for each store
Each frame: Ink Navy gradient background, a phone mock-up with a dark navy bezel `#17305F` and a `#2B4880` hairline, a light-mode app screen inside it, and a two-line headline above in a heavy system sans (SF/Roboto-style, weight 800, sentence case) in `#EAF0FA`, with exactly one phrase in Verify Green `#4ED89A`. Optional one-line subhead in `#9FB2CE`. Measurements are always shown exactly as data (e.g. `35 × 45 mm`, `600 dpi`), never rounded.

Sizes:
- **iOS**: 1320×2868 px (6.9" iPhone) — also export 1290×2796 (6.7").
- **Google Play phone**: 1080×1920 px (9:16), PNG or JPEG, no alpha.
- **Google Play feature graphic**: 1024×500 px, no transparency, the mark on the left, the app name "Passport Photo Studio" and the claim line "No ads. Your photo never leaves your phone." on the right. No other claims.

Headlines for the five screens (use these; the accented phrase is in brackets):
1. "Every check [before you print]" — compliance report screen
2. "[30 document specs], every country free" — country picker
3. "Cropped to the [exact millimetre]" — crop/preview at 35:45
4. "The photo [never leaves your phone]" — privacy/on-device
5. "Print-ready at [600 dpi], paid once" — export / print sheet

If you cannot show real app screens, draw clean, plausible UI in the light theme: Paper `#F7F9FC` surfaces, `#101A2C` text, Passport Blue buttons, and compliance rows with a small green tick *inside the app UI only* (that is genuine product UI and is allowed; it just must not appear as store decoration).

## Output

For each icon concept give: the images at the sizes above, a one-sentence rationale, and a note on what survives at 29 px. For the screenshots give the full set for each store plus the feature graphic. Flag anything you were unsure complied with the hard rules rather than guessing.
