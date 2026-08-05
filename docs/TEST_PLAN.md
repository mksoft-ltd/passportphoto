# Passport Photo Studio — test plan

Stage 3 of the ship-app pipeline. Last full run **2026-08-05**, re-run after
the stage-4 fix round the same day.

| Gate | Result |
|---|---|
| `flutter analyze` | **clean** — 0 issues |
| `flutter test` | **285 passed, 0 skipped** (was 213 before the fix round) |
| `integration_test/camera_permission_test.dart` | **passed on iPhone 15 Pro simulator**, both granted and revoked |
| `integration_test/crop_geometry_probe_test.dart` | passed on iPhone 15 Pro simulator, 20 measurements |
| `integration_test/screenshots_test.dart` via `flutter drive` | passed, 5 PNGs written |

> **Re-run the crop probe and the screenshot harness.** Both predate the
> stage-4 fix round, which changed the spec data (`assets/specs/SOURCES.md`),
> added a seventh compliance check, and moved the image pipeline onto a
> background isolate. Their last green runs measured the previous build.

---

## 1. The crop defect — verdict: CONFIRMED, then fixed and re-verified

The stage-1 finding in `PIPELINE.md` predicted that `PhotoSpec` was reading the
eye-line figures as a distance down from the **top** edge while the data in
`assets/specs/photo_specs.json` states them as a distance up from the
**bottom**, cutting the chin off for most countries. It was right.

### How it was measured

`integration_test/crop_geometry_probe_test.dart`, on a booted iPhone 15 Pro
simulator, against the real `PhotoProcessor` and real ML Kit — not arithmetic,
and not a stub.

- **Subjects.** Five StyleGAN2-generated portraits in `test_fixtures/portraits/`
  (see `PROVENANCE.md` there). Generated faces, so no real person's likeness is
  involved and none is bundled in any build of the app.
- **Framing.** Each fixture is a tight head crop, so the probe reframes it into
  a full-frame portrait canvas with 2.4 head-box-heights of headroom. Without
  that, the crop the app requests starts above the top of the source and the
  clamp in `_computeCropRect` silently rescues the framing, hiding the defect.
  All 20 runs reported `clamped=false`, so no clamp was involved either way.
- **Measurement.** Nothing is taken from the processor. A second,
  contour-enabled detector — contours are a reading the app never requests —
  runs on the framed source and again on the finished crop. The crop's scale is
  recovered from the ratio of the two interocular distances, and the chin
  (lowest point of ML Kit's face contour) is projected into output
  coordinates. The result is defined whether or not the chin is still in frame,
  so a value above 1.0 means it is below the bottom edge.

### The evidence

Chin position as a fraction of the output height; 1.000 is the bottom edge.
Five portraits, before and after the fix.

| Spec | Before | After |
|---|---|---|
| `uk_passport` | **1.038 – 1.070** — chin off the bottom on all five | 0.755 – 0.785 |
| `icao_generic` | **1.061 – 1.098** — cuts through the lower lip | 0.810 – 0.848 |
| `us_passport` | 0.876 – 0.895, with a third of the frame empty above the head | 0.641 – 0.672 |
| `ca_passport` | 0.780 – 0.803 | 0.608 – 0.633 |

`ca_passport`'s "after" figure moved (from 0.639–0.655) when the audit round
corrected its spec data; its eye line went with it, from 0.571 to 0.600 up from
the bottom. The other three specs are unchanged. Re-measured against the
corrected `photo_specs.json` on 2026-08-05, 20/20 green on the first attempt.

Eye line, measured up from the bottom edge as every standard states it:
`uk_passport` was **0.267** — 12 mm up a 45 mm photo, where HMPO requires
30–36 mm. That is exactly `1 - 33/45`, which is the arithmetic signature of the
from-the-top misreading. It is now 0.546 – 0.557.

Before/after crops are on disk at `build/crop_probe/` and
`build/crop_probe_after/`. Compare `synth_2__uk_passport.jpg` in each: the
first has no chin and a third of the frame is empty background above the head.

### Corroboration from the source data

`us_passport`'s `28–35 mm` is verbatim the US State Department figure, and
22 CFR 51.604 words it "eye height … from the **bottom** of the photo". The
data was from-the-bottom; the code divided it as from-the-top. 19 of the 30
bundled specs had `0.55·faceFraction + eyeFraction > 1`, including every
35 × 45 mm European/ICAO spec.

### Why nothing caught it

All six compliance checks reported green on every one of the 20 pre-fix runs,
including the photos with no chin. `Face size within spec` was the check that
should have noticed, and it could not fail: `_computeCropRect` set
`cropHeight = headHeight / targetFaceHeightFraction` and then reported
`faceHeightFraction = headHeight / cropHeight`, which is the midpoint of the
band it was being compared against. It divided the crop by itself.

The suite also contained `expect(uk.targetEyeLineFromTopFraction, closeTo(33 /
45, 0.001))` in `test/widget_test.dart` — a test that pinned the defect in
place as though it were the specification.

### What now stops it recurring

- `test/crop_geometry_golden_test.dart` — 61 tests. For all 30 specs: the crown
  and chin are both inside the frame and clear of the edges, the head height is
  inside the spec's band, and the eye line is inside ICAO 9303's 0.50–0.80
  envelope measured up from the bottom. Every assertion is a measurement of a
  finished JPEG, so none of them restates the formula, and retuning the framing
  does not require rewriting the suite.
- `test/support/crop_harness.dart` — the ruler. Three coloured stripes are
  painted across the source at the crown, eye line and chin, and located again
  in the output. A stripe that is not in the output was cropped away.
- `test/validation_checks_test.dart` — pins that `Face size within spec` now
  measures the rectangle that was actually cut, and that the percentage it puts
  on screen agrees with the stripe ruler to within 3 points.
- `test/photo_spec_test.dart` — asserts every bundled eye-line figure sits in
  the upper half of its photo when read from the bottom, so a spec added later
  with the wrong convention fails here rather than in a photo somebody has
  already had printed. It deliberately does **not** assert the arithmetic of
  any eye-line getter; that is what went wrong last time.

**Re-run the device probe after any change to the framing.** The headless
golden runs on a fabricated face and cannot tell you whether ML Kit's real
bounding box still behaves the way the crop assumes.

### Reading the probe's numbers

Three caveats, all of which matter if these figures are used as a regression
baseline rather than as a one-off verdict.

- **The crown figure carries about ±0.03 of measurement uncertainty.** The
  probe's ground-truth detector is configured differently from the app's
  (accurate mode, contours on, `minFaceSize` 0.05, against the app's faster
  settings), so the two see slightly different bounding boxes. The observed
  crown spread of 0.011–0.149 around a solver target of 0.040 is mostly that,
  not solver error — the app's own crown is deterministic given the app's own
  box. Treat a crown reading as "comfortably inside the frame", not as a value
  to pin.
- **The chin figure is the honest one, and it is the one to watch.** It is read
  from the face contour rather than modelled, so it already includes the fact
  that ML Kit's box bottom sits about 0.07 box-heights *above* the true chin
  (range 0.03–0.12 across the five fixtures). See the decision below.
- **The probe is flaky on the simulator** — roughly one run in three has died
  partway with "did not complete" on the test and its `tearDownAll`, then
  passed identically on a retry. Retry once before treating a probe failure as
  a regression. `flutter test` is not affected; only the on-device target.

### Decision: the chin offset is known and left in place

`PhotoProcessor` models the chin as `face.boundingBox.bottom`, and the probe
measured that ML Kit's box bottom sits ~0.07 box-heights above the true chin
contour. So the app under-reads the chin by roughly 3% of the output height,
which makes the bottom of the crop marginally tighter than the framing solver
intends and the reported head height marginally smaller than the real one.

Left alone, deliberately:

- The probe already measures against the **true** chin, not the modelled one,
  so the 0.755–0.848 figures in the table above are the real chin positions and
  they sit well inside the frame with the 0.08 bottom margin intact. The offset
  is already inside the measured envelope; correcting the model would move
  numbers that are currently correct.
- Modelling the offset would break the headless golden, whose
  `SyntheticSubject` paints its chin stripe exactly at `box.bottom` by
  construction. The two instruments would then disagree by 3% for no gain.
- The error is in the safe direction. Under-reading the chin crops slightly
  *less* aggressively at the bottom, and under-reading head height biases
  toward a larger crop, which is the side to err on.

Revisit if the bottom margin (`HeadFraming.chinMargin`, currently 0.08) is ever
reduced below about 0.05, at which point a 3% under-read stops being absorbed.

---

## 2. Coverage map

| Suite | Tests | What it covers |
|---|---|---|
| `test/crop_geometry_golden_test.dart` | 121 | Crown/chin/eye-line placement in the finished photo, all 30 specs, at **both** head shapes the app meets (eyes 0.45 and 0.59 down the head). Now asserts each spec's own eye-line band, not just ICAO's envelope |
| `test/screen_layout_test.dart` | 41 | Every screen at 5 phone sizes; overflow fails the build |
| `test/purchase_service_test.dart` | 26 | `in_app_purchase` wrapper: availability, product query, buy, the purchase stream, restore, disposal |
| `test/validation_checks_test.dart` | 28 | All seven compliance checks, every fail branch, and the report/photo cross-check |
| `test/photo_spec_test.dart` | 18 | Spec maths, display strings, and the integrity of the bundled asset |
| `test/entitlement_controller_test.dart` | 16 | The Pro flag: who can set it, what the paywall is told meanwhile |
| `test/head_framing_test.dart` | 15 | `HeadFraming`'s priority ordering (written in stage 1 alongside the fix), plus the guarantee that no bundled spec now forces the solver outside its own eye-line band |
| `test/export_gate_test.dart` | 12 | The paid boundary: watermark, downscale, sheet gate, provider wiring, the decode fallback |
| `test/screenshot_mode_release_guard_test.dart` | 2 | `SCREENSHOT_MODE` is inert in a normal build and gated on `!kReleaseMode` |
| `test/ios_permission_macros_test.dart` | 3 | The Podfile enables `PERMISSION_CAMERA=1` and nothing else, and the generated Pods project agrees with it (SEC-1) |
| `test/demo_fixture_test.dart` | 2 | The `SCREENSHOT_MODE` fixture reports all seven checks green for every spec, and its eye-line constant still describes the portrait it draws |
| `test/pipeline_isolate_test.dart` | 1 | The image pipeline does not block the calling isolate (PERF-1) |
| **Total** | **285** | |

### Shared test support

- `test/support/crop_harness.dart` — the stripe ruler, the `SyntheticSubject`
  whose geometry is stated up front, and `StubFaceDetector`. Use the stub in
  any `ProviderContainer` test: the real `faceDetectorServiceProvider` closes
  an ML Kit detector over a platform channel on dispose, which throws off-device.
- `test/support/specs.dart` — spec fixtures written out longhand, plus
  `bundledSpecs()` for tests that are about the shipped asset.
- `test/support/fake_store.dart` — a scriptable `InAppPurchase`. Hand-written
  rather than a mocking package, because the behaviour that matters is
  *ordering*: a purchase result arrives on a stream long after the call that
  started it returned, and a real `StreamController` expresses that directly.

No new pubspec dependencies were added for any of this except SDK-vendored
`integration_test`, which the screenshot run requires.

### Deliberately not covered

- `CaptureScreen` and `FaceOverlay` — the camera preview needs a real camera;
  the crop path they feed is covered by the golden and the device probe.
- The gallery write itself (`saver_gallery`) and `path_provider`. The export
  tests assert that execution reaches those platform channels, which is what
  distinguishes "passed the Pro gate" from "was refused".
- `url_launcher` from the paywall's privacy-policy link.

---

## 3. How to run each suite

```bash
# Unit and widget tests. ~60 s, mostly the 61-spec golden.
flutter test

# Static analysis. Must be 0 issues.
flutter analyze
```

### The crop-geometry probe (needs a booted simulator)

```bash
xcrun simctl list devices available | grep -i iphone   # pick a booted one
mkdir -p build/crop_probe

flutter test integration_test/crop_geometry_probe_test.dart \
  -d <simulator id> \
  --dart-define=REPO_ROOT=$PWD \
  --dart-define=PROBE_DIR=$PWD/build/crop_probe
```

It prints one `CROPPROBE|...` line per portrait × spec and writes the finished
crops to `PROBE_DIR`. **Look at the images**; the numbers are an argument, the
pictures are the evidence.

Each line carries the measured crown, chin and eye line, whether the crop was
clamped, the verdict of the two geometry checks (`faceSizeOk`, `eyeLineOk`) and
a `failed=` list naming any check that did not pass. The names matter: the
fixtures have pre-existing failures that have nothing to do with the crop —
`synth_1` fails `Looking forward` on every spec because that generated face is
smiling with its head slightly turned — and a bare "6/7" would read as a
regression when it is a property of the fixture.

It reads its fixtures by absolute host path, which works because an iOS
Simulator process shares the Mac's filesystem. On a physical device it skips
itself rather than failing. The fixtures are not Flutter assets, so no build of
the app carries a face photograph.

The probe asserts only that it managed to take a measurement — it is an
instrument, not a gate. The expectations live in the headless golden.

**Retry once before believing a failure.** Roughly one run in three dies partway
with "did not complete" on the test and its `tearDownAll`, then passes
identically on the next attempt. See "Reading the probe's numbers" above for
that and for the measurement uncertainty on the crown figure.

### Store screenshots

```bash
SCREENSHOT_DIR=store_assets/screenshots/raw/ios \
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart \
  --dart-define=SCREENSHOT_MODE=true \
  -d <simulator id>
```

Captures `01_result`, `02_sheet`, `03_picker`, `04_home`, `05_pro` — marketing
priority, not the order they are taken. Those five slugs are hard-coded in
`store_assets/screenshots/render.sh`, which reads them from
`raw/<ios|android>/`, so `SCREENSHOT_DIR` has to name the platform directory
and renaming a slug renders a "capture missing" placeholder instead. Set it per
device for the same reason a second run would otherwise overwrite the first.

The set is captured in light appearance on purpose (`themeMode:
ThemeMode.light` in the harness): stage 2 frames the whole set as a white app
screen on navy, and a dark capture breaks it.

It must be `flutter drive`. Running the same target under `flutter test`
produces no files at all, silently: `binding.takeScreenshot` only hands bytes
to a driver.

`--dart-define=SCREENSHOT_MODE=true` seeds the UK passport spec, a finished
crop with every compliance check green, and the unlocked state. The paywall runs
in a second launch with the entitlement overridden back to locked, or it would
photograph the thank-you panel instead of the offer.

Verified end-to-end on the iPhone 15 Pro simulator on 2026-08-05: 5/5 PNGs
written at 1179 × 2556 into `store_assets/screenshots/raw/ios/`. Re-run and
re-verified after the audit fix round, against the seven-check fixture.

The `01_result` assertion does **not** pin the number of checks. It asserts no
failing-check icon is present and that the two numbers in the tally agree —
the count has already changed once, from "6 / 6" to "7 / 7", and a harness that
pins it fails for the one reason that does not matter while staying silent
about the one that does, which is a red cross in the shot that sells the app.

---

## 4. Findings

Nothing is open. All three defects stage 3 found were fixed while stage 3 was
still running, and each is now covered by the test that found it.

### For stage 4 — one deliberate decision, not a defect

`Watermarker.preview` and `Watermarker.stampJpeg` treat "cannot decode" as
"return the input bytes untouched", which means an undecodable input comes back
**unwatermarked**. That was the pre-existing behaviour on the null path; the
error-handling fix routed the thrown case into the same place rather than
changing what the fallback does.

Assessed as not a paywall hole, and pinned as such in
`test/export_gate_test.dart`: the bytes reaching those methods were encoded by
`PhotoProcessor` seconds earlier in the same process, so "undecodable" is not a
state a user can steer into, and the entitlement gate lives in `ExportService`,
which decides whether to watermark before either method is called rather than
leaning on the watermark to enforce the tier. `savePrintSheet` — the Pro-only
artefact — is refused before any rendering happens at all.

Flagged rather than silently kept, because "decode failure degrades open" is
worth a deliberate call. If stage 4 rules that fail-closed applies regardless,
the test to invert is "hands undecodable bytes back untouched, and so degrades
open", and the closed behaviour belongs in `ExportService.savePhoto`.

### For the ui-designer's framing step

The `05_pro` capture is scrolled to bring the price and the buy button into
view, which pushes the comparison table's "Free / Pro" column headers off the
top. The two tick columns are then unlabelled. The paywall is longer than a
phone screen, so no single scroll position holds both. Either shorten the
paywall above the table, or plan to frame this shot with a headline that
carries the meaning.

### Fixed during stage 3, now regression-covered

- **The crop defect.** Section 1. Fixed in `PhotoSpec` + the new
  `HeadFraming` solver; covered by the 61-test golden and re-verified on device.
- **An empty source file surfaced a Dart error string to the user.**
  `PhotoProcessor.process` guarded on `img.decodeImage` returning null, and for
  most rubbish that is what happens — but not for a file of fewer than five
  bytes. The `image` package walks its decoders and the PSD one reads past the
  end of the buffer, throwing `RangeError` before any decoder can decline. A
  `RangeError` is not a `PhotoProcessingFailure`, so it bypassed the friendly
  "Could not decode the selected image" and reached `ResultScreen._ErrorView`,
  which renders `e.toString()` verbatim. Reachable: the gallery picker returns
  a path, and an iCloud photo that has not finished downloading is zero bytes
  on disk. Now caught in `PhotoProcessor`, `Watermarker` and `renderPrintSheet`
  — the last two run inside isolates, where an escaped error has nothing to
  attribute it to. Covered in `test/validation_checks_test.dart` and
  `test/export_gate_test.dart`.
- **`HomeScreen` overflowed its layout.** 51 px in landscape on every iPhone
  (`Info.plist` allows landscape) and 74–90 px at 320 × 568 (in scope for the
  iOS 15.5 deployment target). The body was a `Column` with a `Spacer` and
  nothing scrollable around it. Now a `SingleChildScrollView` over a
  `ConstrainedBox`/`IntrinsicHeight`, so the footer still anchors to the bottom
  where there is room and the screen scrolls where there is not. Covered at all
  five sizes in `test/screen_layout_test.dart`.

---

## 5. Notes for later stages

- **Do not replace the fixtures in `test_fixtures/portraits/` with photographs
  of real people.** They are generated faces precisely so that no likeness is
  involved. `PROVENANCE.md` records the same constraint.
- `test/widget_test.dart` was removed. It contained no widget tests, and its
  eye-line assertion pinned the crop defect. Its spec-maths coverage moved to
  `test/photo_spec_test.dart` and grew.
- The one slow test is `purchase_service_test.dart`'s restore timeout, which
  really waits the 12 seconds the service allows rather than pulling in
  `fake_async` as a dependency. It is tagged `slow`.
- `test/photo_spec_test.dart` asserts the bundled asset holds 30 specs across
  21 countries, which is the figure the paywall, README and `PRODUCT_SPEC.md`
  all use. If the spec list changes, that test is what tells the metadata stage.
