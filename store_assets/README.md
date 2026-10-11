# Passport Photo Studio — store & branding assets

Everything needed to brand the app and build the App Store / Google Play
listings. Self-contained in this folder; no design tool required.

```
store_assets/
├── README.md               ← you are here
├── BRAND.md                ← palette, type, the mark, tone of voice, a11y
├── screenshot_specs.md     ← the screenshot set: screens, states, headlines
├── branding/
│   ├── make_branding.py    generates every SVG below from one set of constants
│   ├── render.sh           rasterises the SVGs to PNG (headless Chrome + sips)
│   ├── icon_master.svg/.png            1024²  opaque app icon (iOS + legacy Android)
│   ├── icon_foreground.svg/.png        1024²  Android adaptive foreground
│   ├── splash_icon_android12.svg/.png  1152²  Android 12+ splash icon
│   ├── splash_logo.svg/.png             768²  launch-screen logo (a 4x asset)
│   ├── feature_graphic.svg/.png    1024×500   Google Play feature graphic
│   ├── play_icon_512.png                512²  Play hi-res store icon, no alpha
│   └── icon_preview_256.png / _48.png  previews, incl. a legibility check
└── screenshots/
    ├── screens.js          the set: slugs, headlines, accents, required states
    ├── frame.html          renders one frame from ?screen=&platform=
    ├── screenshot.css/.js  the frame design system
    ├── index.html          live gallery with a platform switcher
    ├── render.sh           headless-Chrome batch renderer → out/
    ├── raw/{ios,android}/  ← drop the real captures here (git-ignored)
    └── out/                ← rendered store PNGs (git-ignored)
```

---

## 1. Changing the artwork

All the icon geometry is constants at the top of `branding/make_branding.py` —
the card rectangle, the registration marks, the figure, the eye line. Edit
those, never the emitted SVG (it is overwritten).

**Nothing approval-like goes back into this art.** Play rejected the 11 Aug 2026
listing over the icon's old green tick badge; see `BRAND.md` → *The mark* for
what that rules out.

```bash
python3 store_assets/branding/make_branding.py   # constants → SVG
store_assets/branding/render.sh                  # SVG → PNG
```

`icon_preview_48.png` is there to check the mark still reads at launcher size.
It is downscaled from the 1024 master with `sips`, because headless Chrome
honours an SVG's intrinsic size and would crop rather than scale.

**Two sizes in that script are computed, not chosen.** The adaptive-icon
foreground and the Android 12 splash icon both get masked to a circle, and this
mark puts registration marks out at its extremes, so `coverage_for_round_mask()`
solves for the largest art that survives the mask. If you resize the card or
move the registration marks, those numbers follow automatically — do not
replace them with literals.

---

## 2. App icon & launch screen (already wired into both platforms)

`pubspec.yaml` holds the `flutter_launcher_icons` and `flutter_native_splash`
config. After changing the art, regenerate from the project root:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

- **iOS icon:** opaque, alpha stripped — the App Store rejects icons with alpha.
  Verify with `sips -g hasAlpha ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`.
- **Android:** legacy mipmaps plus an adaptive icon whose background plate is
  Ink Navy `#0C2350`, so whatever a launcher's mask cuts away is still on-brand.
- **Launch screen:** Paper `#F7F9FC` in light, Night `#0D1524` in dark — the
  same two values as the Flutter scaffold (`BrandColors` in `lib/app/theme.dart`),
  so there is no flash at the handover to the first frame. The splash logo
  carries its own navy plate because the mark's photo card is white and would
  vanish on Paper.

Three things the generators do that we undo or override on purpose — re-check
them after any regeneration:

- `flutter_launcher_icons` 0.14.4 overwrites the project-level
  `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` build setting
  with the string `AppIcon`. That is a package bug —
  `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` is already set correctly on the
  target. Set all three occurrences in `ios/Runner.xcodeproj/project.pbxproj`
  back to `YES`.
- `flutter_native_splash` reindents the whole of `ios/Runner/Info.plist` and adds
  `UIStatusBarHidden = false`, which is already the default. Revert it — this
  project's plist carries hand-written permission strings and the churn buries
  them in the diff.
- The generated `NormalTheme` in `android/app/src/main/res/values*/styles.xml`
  points `windowBackground` at `?android:colorBackground`, which is platform
  white in light and platform black in dark — neither is our colour, and the
  gap between the splash and Flutter's first frame shows it. All four variants
  (`values`, `values-night`, `values-v31`, `values-night-v31`) are pointed at
  `@color/passport_window_background` instead. That colour lives in
  `values*/window_background.xml` rather than `colors.xml` because
  `flutter_launcher_icons` owns `colors.xml` and rewrites it. **This edit
  survives regeneration** — the splash package only rewrites `LaunchTheme`.

---

## 3. Store screenshots

See **`screenshot_specs.md`** for the screens, the exact app state each capture
needs, and the headline copy. In short:

```bash
# 1. capture: run the harness once per device size, into raw/<platform>/
SCREENSHOT_DIR=store_assets/screenshots/raw/ios flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart \
  --dart-define=SCREENSHOT_MODE=true -d <device>

# 2. frame:
cd store_assets/screenshots && ./render.sh
#    → out/{ios69,ios67,android}/<slug>.png at exact store sizes
```

Set `SCREENSHOT_DIR` per device or one size overwrites another. Capture in
**light appearance**; the whole set is designed as a white app screen on navy.

The frames render before any captures exist — a missing raw draws a branded
"capture missing" card naming the screen and the state it needs. Open
`index.html` to review the whole set and sign off the copy first.

---

## 4. Feature graphic (Google Play)

`branding/feature_graphic.png` is the finished **1024 × 500**. Edit the
`feature_graphic()` function in `make_branding.py` and re-run the two commands
in §1.

---

## 5. Listing checklist

- [x] App icon, both platforms
- [x] Launch screen, both platforms
- [x] Play feature graphic 1024 × 500
- [ ] iPhone 6.9" screenshots — `screenshots/out/ios69/` (needs raw captures)
- [ ] Play phone screenshots — `screenshots/out/android/` (needs raw captures)
- [ ] iPad — **not applicable**, the app is iPhone-only

See `BRAND.md` for palette, typography and tone of voice.
