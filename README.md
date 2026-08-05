# Passport Photo Studio

On-device passport, visa, and ID photo studio for 20+ countries.
Take or pick a photo, the app uses ML Kit face detection to crop and scale to the
chosen country/document spec, validates the result, and exports a print-ready
JPEG plus a tiled 4×6" print sheet. Everything runs on-device — no photos leave
the phone.

## Run it

```bash
cd passport_photo_app
flutter pub get
flutter run            # picks the running simulator / connected device
```

To target a specific simulator:

```bash
flutter devices
flutter run -d <device-id>
```

The first launch on Android will trigger a small ML Kit model download (configured via
`com.google.mlkit.vision.DEPENDENCIES = face` in `AndroidManifest.xml`). On iOS the
ML Kit model ships with the framework.

**Apple Silicon iOS simulator note:** Google's ML Kit iOS pods only ship x86_64
slices for the simulator. Flutter automatically excludes the arm64 simulator
slice for those pods. Builds work, but you'll see a build-time warning. Use a
physical device for the smoothest dev loop on Apple Silicon, or stick with iOS
17 / x86_64-capable simulators.

## Tests

```bash
flutter analyze
flutter test
```

## Architecture

Riverpod + GoRouter, feature-first folders.

```
lib/
  app/                  router, theme, app shell
  core/models/          PhotoSpec
  features/
    specs/              JSON loader, country picker
    photo_capture/      home, camera capture (with face oval), result review
    processing/         FaceDetectorService + PhotoProcessor (crop, scale, validate)
    export/             save to gallery, build 4x6" print sheet
assets/specs/photo_specs.json
```

The processor:
1. Decodes source (`bakeOrientation` so coordinates match ML Kit).
2. Picks the largest detected face.
3. Estimates chin-to-crown height (≈1.45× the ML Kit bounding box).
4. Computes a crop rect so face height and eye-line position match the spec.
5. Resamples to exact spec pixel dimensions (mm × dpi / 25.4).
6. Runs validation: single face, eyes open, looking forward (Euler angles),
   face size within range, background uniformity (top-row luminance variance),
   crop fits within the source.

## Specs

`assets/specs/photo_specs.json` ships with 30 entries spanning 21 countries plus
ICAO and Schengen generic fallbacks. Sourced from public ICAO Doc 9303 and
government guidance. Add more by appending to the `specs` array — schema is
documented by `PhotoSpec.fromJson`.

## Monetisation

One non-consumable unlock, `com.froggyeye.passportphoto.pro` (£4.99), through
the native `in_app_purchase` plugin — no wrapper SDK. Free gives every country,
the full compliance report and a watermarked 600 px save; Pro gives the
full-resolution export and the 4×6" print sheet. The gate lives in
`ExportService`, which reads the entitlement itself so no caller can bypass it.

## Screenshot mode

```bash
flutter run --dart-define=SCREENSHOT_MODE=true
```

Seeds a UK passport photo with all checks green and Pro unlocked, using a
procedurally drawn illustration rather than the camera, so the store-screenshot
run is deterministic and needs no device permissions. The flag is conjoined
with `!kReleaseMode`, so a release build cannot give the purchase away —
enforced by `test/screenshot_mode_release_guard_test.dart`.

## Release signing

`android/upload-keystore.jks` and `android/key.properties` are generated per
app and git-ignored. `flutter build appbundle --release` picks them up via
`android/app/build.gradle.kts`. **Back the keystore up outside the repo** — it
cannot be regenerated, and Play upload keys can only be reset by support.

## Platform setup

- **iOS**: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`,
  `NSPhotoLibraryAddUsageDescription` set in `ios/Runner/Info.plist`.
- **Android**: `CAMERA`, `READ_MEDIA_IMAGES` permissions and ML Kit auto-download
  metadata in `AndroidManifest.xml`. `minSdkVersion` is forced to 21+.

## Deferred / TODO

- Background removal & replacement (currently we just check uniformity)
- Glasses / headwear detection beyond ML Kit's basics
- Country-specific extras: shadow detection, red-eye, exposure
- Localized country names
- Print-service integration (Walgreens, Boots, FedEx)
- AirPrint / Android Print export
- App icon and splash screen
- Onboarding flow
