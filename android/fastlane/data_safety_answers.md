# Play Console — Data safety and app content answers (Passport Photo Studio)

Console-only forms; `supply` cannot upload them. Answer exactly as below.

Verified against the code on 2026-08-05. **This app is NOT "no data collected"** — the
bundled `google_mlkit_face_detection` SDK links Google's `MLKitCommon`, which carries a
live Clearcut telemetry client (`https://play.googleapis.com/log`) and, by its own Apple
privacy manifest, collects a non-advertising device identifier plus product-interaction,
performance and other diagnostic data. Play requires data collected by **bundled
third-party SDKs** to be declared, and an inaccurate Data safety form is a
suspension-class violation rather than a rejection-and-resubmit one.

**No photograph, and no part of one, is ever collected, transmitted or shared.** Face
detection runs against a model bundled inside the app (verified present in the release
AAB: `base/assets/models_bundled/blazeface.tfl`,
`base/lib/arm64-v8a/libface_detector_v2_jni.so`). The app's own code contains no HTTP
client and no upload path. There is no account, no backend, no analytics written by
Froggy Eye, no crash reporter and no advertising SDK.

Release merged manifest, for reference — seven permissions, verified by parsing
`build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml`
as XML on 2026-08-05: `CAMERA`, `READ_EXTERNAL_STORAGE` (maxSdk 32),
`WRITE_EXTERNAL_STORAGE` (maxSdk 28), `INTERNET`, `ACCESS_NETWORK_STATE`,
`com.android.vending.BILLING`, and Play Billing's
`…DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`. `RECORD_AUDIO` is explicitly removed, and
`READ_MEDIA_IMAGES` was dropped in stage 4d — neither appears in the release manifest.
`android:allowBackup="false"`.

---

## 1. Data safety — overview answers

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** — ML Kit's telemetry goes to `https://play.googleapis.com/log` over TLS; Play Billing likewise |
| Do you provide a way for users to request that their data is deleted? | **No** — see the wording below |
| Does your app comply with the Families policy? | Not applicable — target audience is 18+, not opted into Designed for Families |
| Privacy policy URL | `https://raw.githubusercontent.com/mksoft-ltd/passportphoto/refs/heads/main/PRIVACY_POLICY.md` |

**Deletion answer, in the free-text box if one is offered:** "The app has no account and
stores no user record. Nothing collected is linked to an identity, so there is no record
to look up or delete. The diagnostic data described here is collected by Google's ML Kit
SDK and controlled by Google under its own privacy policy; local preferences are removed
by uninstalling the app."

---

## 2. Data types — tick exactly these three, and nothing else

All three are collected by the bundled ML Kit SDK, not by app code.

### 2.1 Device or other IDs → **Device or other IDs**

| Field | Answer |
|---|---|
| Collected | **Yes** |
| Shared | **Yes** — see the sharing note below |
| Processed ephemerally | **No** |
| Required or optional | **Required** — no supported opt-out is exposed by the SDK |
| Purposes | **Analytics**, **App functionality** |
| Used for tracking / advertising | **No** |

### 2.2 App activity → **Other actions**

| Field | Answer |
|---|---|
| Collected | **Yes** (counts of which ML Kit features ran) |
| Shared | **Yes** |
| Processed ephemerally | **No** |
| Required or optional | **Required** |
| Purposes | **Analytics**, **App functionality** |
| Used for tracking / advertising | **No** |

### 2.3 App info and performance → **Diagnostics** *and* **Other app performance data**

| Field | Answer |
|---|---|
| Collected | **Yes** (SDK performance and error information) |
| Shared | **Yes** |
| Processed ephemerally | **No** |
| Required or optional | **Required** |
| Purposes | **Analytics**, **App functionality** |
| Used for tracking / advertising | **No** |

**Crash logs: No.** The app ships no crash-reporting SDK; ML Kit reports its own internal
error information, which is covered by Diagnostics.

### Sharing — read this before answering

The recipient is **Google**, via its own bundled SDK, for Google's purposes rather than as
a processor acting for Froggy Eye. Play counts a transfer to a third party as sharing, so
**Yes** is the conservative and defensible answer, and over-declaring sharing carries no
penalty while under-declaring it does.

✅ **Documentation conflict RESOLVED 2026-08-05 (stage 4d), in favour of this sheet.**
`docs/PRODUCT_SPEC.md` § Store privacy declaration said *collected, **not** shared*; it
now says **shared**, with the reasoning above restated and a pointer back to this file as
the authoritative version. Apple's label is unaffected either way — App Privacy has no
"shared" concept. Nothing else in the two documents disagrees.

---

## 3. Data types explicitly NOT collected — leave every one of these unticked

- **Photos and videos.** The single most important answer on this form. Photographs are
  read, cropped and validated entirely on the device and are never transmitted. The source
  copy handed over by the camera or picker is deleted when the app has finished with it,
  and stale files are swept on launch. The only copies that persist are the ones the user
  deliberately saves to their own gallery.
- Personal info (name, email, address, user IDs), Financial info, Health and fitness,
  Messages, Audio, Files and docs, Calendar, Contacts, Location (neither precise nor
  approximate), Search history, Web browsing history, Installed apps, In-app search
  history, Purchase history, Sensitive info.

**Purchases:** the one-time Pro unlock is processed by Google Play Billing. Play's own
billing transaction is not developer data collection and is not declared here; the app
never sees or stores payment details.

---

## 4. Advertising ID declaration

| Question | Answer |
|---|---|
| Does your app use an advertising ID? | **No** |

No advertising SDK, no `com.google.android.gms.permission.AD_ID` permission, no
`google_mobile_ads` dependency. Answering this correctly is what lets Play's pre-review
checks pass without a query.

---

## 5. App access (login) declaration

| Question | Answer |
|---|---|
| Is any functionality restricted by a login? | **No — all functionality is available without special access** |
| Demo credentials needed | None |

There is no sign-in, registration or backend anywhere in the app. The Pro unlock is an
in-app purchase, not an account.

---

## 6. Content rating (IARC questionnaire)

| Question | Answer |
|---|---|
| App category | **All other app types** (**not** "Game") |
| Violence, blood, or scary content | **No** |
| Sexual content or nudity | **No** |
| Profanity or crude humour | **No** |
| Controlled substances (drugs, alcohol, tobacco) | **No** |
| Real-money gambling, or simulated gambling | **No** |
| User-generated content, sharing, or user interaction | **No** — nothing is uploaded, shared or published, and there is no chat, comments or profile |
| Does the app share the user's location with other users? | **No** |
| Does the app allow users to purchase digital goods? | **Yes** — one non-consumable unlock |
| Does the app contain ads? | **No** |
| Miscellaneous: does the app collect/transmit personal or sensitive user data? | Answer per §2 — device identifier and diagnostics only, never photos |

Expected outcome: **Everyone / PEGI 3 / USK 0 / ESRB Everyone.** Nothing here should
branch the questionnaire.

---

## 7. Target audience and content

| Question | Answer |
|---|---|
| Target age groups | **18 and over** only |
| Does the app appeal to children? | **No** |
| Designed for Families | **Do not opt in** |
| Ads shown to children | Not applicable — no ads |

Rationale: the app's job is government paperwork, done by the adult who is applying, and
parents photographing a child are still the adult user. Selecting any under-18 band would
pull the listing into the Families policy — including its stricter SDK rules — for an
audience that does not exist. This is separate from the content rating, which remains
Everyone.

---

## 8. Other app content declarations

| Declaration | Answer |
|---|---|
| Ads | **No, my app does not contain ads** |
| In-app purchases | **Yes** — one non-consumable, `com.froggyeye.passportphoto.pro`, £4.99, Google Play Billing |
| Government app | **No** — Froggy Eye Ltd is a private publisher with no government affiliation, and the listing claims none |
| Financial features | **No** |
| Health apps | **No** |
| News app | **No** |
| COVID-19 contact tracing or status | **No** |
| Data safety | See §1–§3 |
| Photo and video permissions | **Not applicable — do not file the declaration** |

### Photo and Video Permissions declaration — not applicable

The release manifest declares **no broad photo or video permission**. `READ_MEDIA_IMAGES`
was removed in stage 4d and is absent from the merged release manifest; the only media
permission left is `READ_EXTERNAL_STORAGE` capped at `maxSdk 32`, which the manifest
merger implies from `camera_android_camerax` for pre-Android-13 devices and which is not a
broad photo permission on any currently supported API level.

`image_picker` reaches the user's photos through the **system photo picker**, which returns
a per-item URI grant for the single image the user selected. That is exactly the access
model Play's Photo and Video Permissions policy asks apps to move to, so the declaration
does not apply and **must not be filed** — filing it would create a standing review
commitment, and gate rollout, for a permission the app does not request.

If the console asks the question at all, answer: **"My app does not access photos or
videos"** in the broad-permission sense, or select the system-photo-picker option where one
is offered.

---

## 9. Play Console reviewer notes (optional "review notes" field)

```
Passport Photo Studio crops a photo the user takes or picks to the published
size, face-height and eye-line requirements of a specific document (UK passport,
US visa, and so on), then runs seven compliance checks and shows a pass or fail
with a plain-English reason for each.

• No account, no sign-in, no backend. Every feature is reachable from a fresh
  install. All 30 document specs across 21 countries are free; countries are
  never gated.
• One in-app purchase: com.froggyeye.passportphoto.pro, £4.99 non-consumable,
  Google Play Billing. It unlocks the full-resolution unwatermarked export and
  the 4x6 inch print sheet. The free tier keeps capture, the automatic crop, the
  complete compliance report, the print-sheet preview and a watermarked save.
  The price shown in the app comes from Play Billing; no price is hardcoded.
• Photos are processed entirely on the device. Face detection uses Google ML Kit
  with the model bundled inside the app, so no photograph is uploaded anywhere,
  and the app's own code has no network client. The source copy is deleted once
  processing finishes.
• The Data safety form declares what the bundled ML Kit SDK sends Google — a
  non-advertising device identifier, feature-usage counts and diagnostics. No
  photo data is included in it. No advertising SDK, no advertising ID, no crash
  reporter, no analytics written by us.
• No user-generated content, sharing, social features or ads.
• Permissions: CAMERA for the in-app capture (optional — gallery import works
  without it); no broad photo permission is requested, because gallery import
  goes through the system photo picker, which grants access to the one image
  the user selects; legacy storage permissions capped at maxSdk 32/28 for older
  devices; INTERNET, ACCESS_NETWORK_STATE and BILLING are merged in by Play
  Billing. RECORD_AUDIO is explicitly removed from the merged manifest.
• The listing makes no claim that any authority will accept a photo. Where an
  authority publishes a figure the app uses it; where none is published the
  figure is derived from ICAO Doc 9303 portrait geometry, and the app ships a
  per-spec source list recording which is which.

Contact: Froggy Eye Ltd — info@froggyeye.com
```
