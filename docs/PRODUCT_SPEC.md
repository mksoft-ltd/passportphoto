# Passport Photo Studio — Product Spec

Owner: Froggy Eye Ltd · Bundle ID `com.froggyeye.passportphoto` (identical on both platforms)
Status: stage 1 (build) complete, 2026-08-05

## Product summary

Passport Photo Studio turns a selfie into a document photo that actually meets
the spec. You pick the country and document type, take or choose a photo, and
the app uses on-device face detection to crop and scale it to the exact
millimetre and DPI requirements, then tells you — check by check — whether the
result would pass. Pro exports the print-ready file and a 4×6" sheet you can
take to any photo counter.

The whole pipeline runs on the phone. **No photo ever leaves the device** —
face detection uses a model bundled inside the app, and there is no account, no
backend, and no network call in the app's own code. The app collects nothing
and we receive nothing.

One qualification, and it is load-bearing for the store privacy answers: the
bundled ML Kit SDK carries Google's own telemetry client and reports a
non-advertising device identifier plus performance and feature-usage data to
Google. That is Google's collection, not ours, and it never includes any part
of a photograph — but both stores require it to be declared. See the privacy
declaration below and `PRIVACY_POLICY.md`.

Positioning: the honest alternative to the £6-a-set photo booth and to the
free-trial apps that make you pay before you find out the crop was wrong.

## Target users

- **Anyone renewing a passport, visa, or ID** who does not want to find a booth
  — the single largest group, and typically a once-every-few-years need.
- **Parents photographing children**, where a booth is impractical and multiple
  attempts are the norm.
- **Frequent visa applicants** — students, contractors, people with family
  abroad — who need different specs for different countries and would otherwise
  pay per set.
- **Small travel agencies and post-office counters** doing this on behalf of
  customers.

Design consequence: the app must work first time, offline, with no sign-up, and
must be honest about failure. A user who prints a rejected photo is a user who
will never trust the app again — hence the compliance report, and hence the
free tier keeps the full report rather than hiding it behind the paywall.

## Feature list

### Shipping (MVP, v1.0.0)

- **30 document specs across 21 countries**, plus ICAO Doc 9303 and Schengen
  generic fallbacks. All free — countries are never gated.
- **Camera capture** with a live face-guide overlay sized to the selected spec.
- **Gallery import** for an existing photo.
- **On-device face detection** (Google ML Kit, bundled model) — landmarks,
  eye-open probability, head Euler angles.
- **Automatic crop and scale**: estimates chin-to-crown height, positions the
  eye line where the spec requires, and resamples to exact pixel dimensions
  (mm ÷ 25.4 × dpi).
- **Eight compliance checks**, each with a pass/fail and a plain-English reason:
  single face, eyes open, looking forward, neutral expression, face height
  within the spec's range, eye line within the spec's range, background (plain,
  light, no colour cast), and whether the required crop fitted inside the
  source photo.
- **Free on-screen preview**: the finished crop, capped at a 640 px long edge
  and labelled "Preview — Pro exports at full print resolution." Enough to see
  the crop, the framing and the background are right; below both the UK
  (600 × 750) and US (600 × 600) digital-upload minimums, so a screenshot of it
  is not a substitute for buying the file. Pro sees the full resolution.
- **Free export**: a watermarked copy downscaled to a 600 px long edge, saved to
  the gallery. Deliberately proves the app worked without being printable.
  Separate from the on-screen cap above — different number, different reason.
- **Pro export**: the full-resolution unwatermarked JPEG, plus the 4×6" print
  sheet (tiled at 300 dpi with cutting gaps), saved to the gallery.
- **Print sheet preview** — free users see the real sheet layout, watermarked,
  before deciding whether to buy.
- Light and dark theme, following the system setting.

### Added in 1.0.3

- **Spain corrected to 26 mm wide × 32 mm tall** (was bundled landscape,
  32 × 26). Head and eye-line bands re-derived from ICAO for a 32 mm frame;
  provenance in `assets/specs/SOURCES.md`. No bundled spec is wider than tall,
  and a test pins that.
- **Verdict line** at the top of the report — "All 8 checks passed for …" or
  "n of 8 checks need attention". It reports checks, never approval.
- **Failed checks first, each with a "How to fix" hint.** Hints are data on
  `CheckKind` (`lib/features/processing/processed_photo.dart`), not UI logic.
- **CTAs by outcome** — see the `/result` screen map entry.
- **The save resumes after the unlock.** The paywall closes itself with `true`
  when the entitlement flips while it is open, and the result and print-sheet
  screens re-run the save the user was making.
- **Rating prompt** (`lib/core/services/review_prompter.dart`): the OS sheet
  only, after a successful save of a photo that passed every check, never in
  the first session, never in a session with a processing error, save failure,
  purchase error or a paywall closed without buying, never within 10 s of the
  paywall closing, 120-day cooldown, at most 3 asks ever. Free users qualify on
  their second distinct session with a passing preview save. No pre-prompt, no
  incentive, no button that calls it. "Rate the app" on the Pro-active card
  opens the store listing.

### Later

- Background removal and replacement (today the app only measures uniformity).
- Glasses, headwear and shadow detection beyond ML Kit's basics.
- Direct AirPrint / Android Print export.
- Localised country names and UI.
- Print-service handoff (Boots, Walgreens, FedEx).

## Screen map

```
/            Home
             ├── selected document card ──────► /picker
             ├── "Take a new photo" ──────────► /capture ──► /result
             ├── "Pick from gallery" ─────────► (system picker) ──► /result
             └── AppBar Pro button ───────────► /pro

/picker      Country & document picker — searchable list of all 30 specs

/capture     Camera with face-guide overlay; shutter ──────────► /result

/result      Review: cropped preview (640 px cap when locked), spec summary,
             compliance report
             All checks passed:
             ├── free: upsell card + "Get the print-ready photo — {store
             │   price}" ──► /pro ──(unlocked)──► full-res save, no extra tap
             ├── free: "Save watermarked preview" (text button) ► gallery
             ├── Pro: "Save full-resolution photo" ► gallery write
             ├── "View 4×6\" print sheet" ────► /sheet
             └── "Re-shoot or pick another" ──► /
             Any check failed (no upsell):
             ├── "Fix and re-shoot" ──────────► /capture (replaces /result,
             │                                   same selected spec)
             ├── "Save …" preview / full-res ► gallery write (gated)
             ├── "View 4×6\" print sheet" ────► /sheet
             └── "Pick another photo" ────────► /
             Processing error: "Try again" ► /capture, "Pick another photo" ► /

/sheet       Print-sheet preview (watermarked when locked)
             └── "Save print sheet" ──────────► gallery write, or /pro if locked
                                                 (then saves on unlock)

/pro         Paywall: free-vs-Pro comparison, price from the store, restore.
             Pops with `true` when the unlock lands while it is open.
             Already Pro: "Pro is active" card + "Rate the app" (store listing)
```

Navigation is GoRouter; `/result` and `/sheet` take the source image path as
`extra`. State is Riverpod throughout.

## Data model

Everything is either bundled at build time or transient. Nothing is
synchronised, uploaded, or associated with an identity.

| Thing | Where it lives | Lifetime |
|---|---|---|
| `PhotoSpec` (30 records: country, document, mm, dpi, face-height and eye-line ranges, background colour, notes) | `assets/specs/photo_specs.json`, read-only | Ships with the app |
| `ProcessedPhoto` (JPEG bytes, pixel dimensions, spec, list of `ValidationCheck`) | In memory only | Discarded when the screen is popped |
| `ValidationCheck` (label, passed, detail) | In memory only | As above |
| Last-used spec id (`last_used_spec_id`) | `SharedPreferences` | Until the app is uninstalled |
| Pro entitlement flag (`pro_unlocked`) | `SharedPreferences`, cache only — the store is the source of truth and `restore` re-establishes it | Until the app is uninstalled |
| Exported JPEGs | The user's own photo gallery, plus a temp-directory copy for sharing | The user's to delete |

There is no database, no user record, no device identifier, and no server.

## Permissions, and why each one is needed

This table is the merged manifest and Info.plist as actually built, verified
against `build/app/intermediates/packaged_manifests/` — not just what the app's
own manifest declares.

| Platform | Permission | Why |
|---|---|---|
| iOS | `NSCameraUsageDescription` | Taking the document photo in-app, with the face-guide overlay. Optional — the user can import from the gallery instead. |
| iOS | `NSPhotoLibraryUsageDescription` | Choosing an existing selfie to crop, when the user does not want to shoot a new one. |
| iOS | `NSPhotoLibraryAddUsageDescription` | Writing the finished photo and the print sheet back to the user's library — the only way to get the file to a printer. |
| Android | `CAMERA` | Same as iOS camera. |
| Android | `READ_EXTERNAL_STORAGE` (`maxSdkVersion="32"`) | **Not requested by app code.** The manifest merger *implies* it because `camera_android_camerax` declares `WRITE_EXTERNAL_STORAGE`; the implied form carries no version cap, so it is re-declared here capped at 32 (`tools:replace`) to keep the surface bounded. Never requested on Android 13+. |
| Android | `WRITE_EXTERNAL_STORAGE` (`maxSdkVersion="28"`) | Saving the finished photo on Android 9 and older, where MediaStore required it. Contributed by `camera_android_camerax` (not `saver_gallery`, per the merger report). |
| Android | `INTERNET`, `ACCESS_NETWORK_STATE` | Added by the Google Play Billing library, which the `in_app_purchase` plugin depends on. **The app itself makes no network calls of its own** — there is no API client and no upload path in the codebase. The bundled ML Kit SDK does use these to report its own diagnostics to Google; see the privacy declaration below. |
| Android | `com.android.vending.BILLING` | The one-time Pro purchase. |
| Android | `uses-feature android.hardware.camera` (`required="false"`) | Declares the camera as optional so the app installs on camera-less devices, where gallery import still works. |

**`RECORD_AUDIO` is explicitly removed** (`tools:node="remove"` in
`android/app/src/main/AndroidManifest.xml`). The `camera` plugin declares it for
video capture; this app only ever takes stills — `CameraController` is
constructed with `enableAudio: false` — so shipping a microphone permission
would be both unnecessary and, on a document-photo app, alarming to a reviewer.
Its absence is worth re-checking on any dependency bump.

**`READ_MEDIA_IMAGES` was removed 2026-08-05** and no media-read permission is
declared. It was ours, not a plugin's, and nothing needed it: `image_picker`
reaches the library through `ACTION_GET_CONTENT` (routed to the system photo
picker on current Android), which returns one content URI with a per-item read
grant — the only permission `image_picker_android` ever checks or requests is
`CAMERA`. `saver_gallery` writes through MediaStore, which needs no permission
from API 29 up. Declaring it would also have obliged us to file Play's **Photo
and Video Permissions** declaration, a review commitment that gates rollout,
for a permission nothing reads.

**Verified on device, not only in the manifest** (Android 16 / API 36
emulator): the installed app requests exactly `CAMERA`, `INTERNET`,
`ACCESS_NETWORK_STATE`, `BILLING` and the Flutter-generated dynamic-receiver
permission — the two storage entries fall away above their `maxSdkVersion`.
The gallery flow was then driven end to end: the system photo picker opened
(showing its own "will only have access to the photos you select" notice), the
chosen JPEG arrived intact, ML Kit detected the face and the app produced an
827 × 1063 crop with the seven-check report. No `SecurityException` and no
permission denial in logcat.

No location, contacts, microphone, background, or "all files access" permission
is requested.

### Store privacy declaration

**Not "No data collected".** That answer would be inaccurate and, on Play, an
inaccurate Data safety form is one of the few violations that leads to
suspension rather than a rejection-and-resubmit cycle.

`google_mlkit_face_detection` links `MLKitCommon`, whose own Apple privacy
manifest (`ios/Pods/MLKitCommon/Frameworks/MLKitCommon.framework/PrivacyInfo.xcprivacy`)
declares collection of Device ID, Product Interaction, Performance Data and
Other Diagnostic Data for Analytics and App Functionality. The linked binary
carries a live Clearcut client (`https://play.googleapis.com/log`). Both stores
require the developer to declare data collected by **bundled third-party SDKs**,
not only by their own code.

**Apple — App Privacy.** Under **Data Not Linked to You**:

| Category | Type | Purposes |
|---|---|---|
| Identifiers | Device ID | Analytics, App Functionality |
| Usage Data | Product Interaction | Analytics, App Functionality |
| Diagnostics | Performance Data | Analytics, App Functionality |
| Diagnostics | Other Diagnostic Data | Analytics |

**"Used for tracking" = No** for every row. Nothing is Linked to You. No
`NSUserTrackingUsageDescription` is declared and no ATT prompt is shown.

**Google Play — Data safety.** *Device or other IDs*, *App activity → Other
actions*, and *App info and performance → Diagnostics / Other app performance
data* → **collected, shared, not used for tracking.** Purpose: Analytics and
App functionality.

**"Shared" is Yes, and that is deliberate** — this line said "not shared" until
2026-08-05 and was wrong. The data does not go to a Froggy Eye server; it goes
from the user's device to **Google**, via ML Kit's bundled Clearcut client.
Play counts a transfer to a third party as sharing, and Google is a third party
from the user's point of view rather than a processor acting for us — we do not
receive the data, cannot see it and cannot switch it off. Over-declaring
sharing costs nothing; under-declaring it is the kind of Data safety
inaccuracy that leads to suspension rather than a rejection.

The authoritative per-field answers are in
`android/fastlane/data_safety_answers.md`, which is what gets typed into the
console. **This section must agree with that file** — it is the same
declaration written twice, and a reviewer comparing them is the reason both
exist. Apple's label is unaffected: App Privacy has no "shared" concept, so the
Data Not Linked to You table above stands as written.

**What stays true and should be said in the listing:** photos are processed
entirely on-device and are never uploaded. The model is bundled — verified in
the release AAB (`base/assets/models_bundled/blazeface.tfl`,
`base/lib/arm64-v8a/libface_detector_v2_jni.so`). No advertising SDK, no
advertising identifier, no crash reporter, no tracking, and no analytics
written by Froggy Eye.

**Do not** try to silence ML Kit's logging instead of declaring it. No
supported opt-out is exposed through the Flutter plugin; the only lever found
was an undocumented private UserDefaults key, which is not a control a legal
claim can rest on.

**Re-check on every dependency bump:** `find ios/Pods -name PrivacyInfo.xcprivacy`
and read each `NSPrivacyCollectedDataTypes`. That five-minute check is what
decides whether these answers are still honest.

## Monetisation

One non-consumable in-app purchase, via the native `in_app_purchase` plugin —
no billing wrapper SDK.

- Product ID: `com.froggyeye.passportphoto.pro` on Google Play; `com.froggyeye.passportphoto.pro2` on iOS (the original ID was retired with the deleted App Store Connect record, see PIPELINE.md 7f)
- Display name: **Passport Photo Studio Pro**
- Price: £4.99 (Tier equivalent), one-time
- Type: non-consumable, restorable

**Free tier** — every country and document spec, camera capture with the guide
overlay, automatic crop, the complete compliance report, the print-sheet
preview, and a watermarked 600 px save to the gallery. The free tier is a
working product, not a demo: a user can verify the app got their photo right
before spending anything.

The on-screen review preview is capped at a 640 px long edge for the free tier
(full resolution once Pro is unlocked). Until 2026-08-05 it rendered the
finished crop at full print resolution, which handed the majority use case —
digital passport uploads, where nothing is printed and nothing is measured — the
entire paid artefact one screenshot away, while the paywall offered a *smaller*
600 px watermarked file in exchange. The compliance report, not the preview's
sharpness, is what the free tier sells.

**Pro** — the full-resolution unwatermarked export, the 4×6" print sheet, and
gallery saves without the watermark.

Countries are never gated. The paywall shows the price only as reported by
`ProductDetails.price`; no currency string is ever hardcoded. "Restore
purchase" is reachable from the Home app bar on every launch.

The gate lives in one place: `ExportService`, which reads the entitlement
itself rather than trusting its caller
(`lib/features/export/export_service.dart`).

## Screenshot harness

`--dart-define=SCREENSHOT_MODE=true` seeds a deterministic, permission-free
state: the UK passport spec selected, a finished crop with all seven checks
green, the print sheet renderable, and Pro unlocked. The portrait is drawn
procedurally as a flat illustration — deliberately not a photograph of a real
person. See `lib/core/demo/demo_data.dart`.

The flag is `!kReleaseMode && bool.fromEnvironment(...)`, so a release build
cannot be tricked into giving the purchase away; that is enforced by
`test/screenshot_mode_release_guard_test.dart`.

## Architecture

Flutter (stable), Riverpod for state, GoRouter for navigation, feature-first
folders under `lib/features/`. No backend, no code generation, no Freezed —
the model layer is small enough that hand-written immutable classes are
clearer.

Heavy image work (the 1800×1200 print-sheet composite, the watermark render)
runs in a background isolate via `Isolate.run` so the UI does not drop frames.
