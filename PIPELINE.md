# Passport Photo Studio — ship-app pipeline tracker

App: on-device passport/visa/ID photo studio (ML Kit face detection, 30 specs / 21 countries, print-ready export + 4×6" sheet). Photos never leave the device. **Privacy label is NOT "No data collected"** — the bundled ML Kit SDK reports Device ID + diagnostics to Google; see the corrected instruction in the stage-1 facts block below.
Bundle: `com.froggyeye.passportphoto` (rename from `com.kcyconsulting.*` owed in stage 1; iOS bundle ID registered 2026-08-05, ASC id `FQDJK2W53W`).
Monetization: free + one-time non-consumable **£4.99** `com.froggyeye.passportphoto.pro`. Free = all countries, capture, auto-crop, full validation report, watermarked low-res save. Pro = unwatermarked full-res export, 4×6" print sheet, save-to-gallery. Never gate countries.
iPhone-only (`TARGETED_DEVICE_FAMILY = 1`), house precedent lucky_numbers.
Name fallbacks if "Passport Photo Studio" is taken on a store: "Passport & ID Photo Studio", then "ID & Passport Photo Studio" (bundle ID stays either way).

| # | Stage | Agent | Status | Date |
|---|-------|-------|--------|------|
| 0 | store records | conductor | Play record CREATED (app id 4972341008668638772, "Passport Photo Studio", App/Free, declarations accepted). iOS bundle ID registered (FQDJK2W53W). ASC app record BLOCKED: no live appstoreconnect.apple.com session in Chrome (authResult=FAILED, needs founder 2FA login) — deferred with founder warning; create ASC record (New App → iOS, "Passport Photo Studio", bundle com.froggyeye.passportphoto, SKU passportphoto) as soon as a session exists. Name fallback if taken: "Passport & ID Photo Studio". | 2026-08-05 |
| 1 | build | flutter-architect | **done** — bundle ID renamed to `com.froggyeye.passportphoto` on both platforms; iPhone-only; native `in_app_purchase` Pro unlock + paywall; release signing wired; SCREENSHOT_MODE seeded; `docs/PRODUCT_SPEC.md` + `PRIVACY_POLICY.md` written. **Crop-geometry blocker fixed 2026-08-05** — eye line was read from the wrong edge, cutting the chin off on 19 of 30 specs; see the resolved finding below. See stage-1 notes below. | 2026-08-05 |
| 2 | design | ui-designer | **done** — brand ("the spec frame" mark, Ink Navy + Passport Blue + Verify Green) in `store_assets/BRAND.md`; icon wired into both platforms via `flutter_launcher_icons` (iOS 1024 alpha-stripped, Android adaptive on `#0C2350`); light/dark launch screens via `flutter_native_splash` + the Android `NormalTheme` flash fix; Play feature graphic built; 5-shot screenshot set specced and the framing renderer working. See stage-2 notes below. | 2026-08-05 |
| 3 | test | mobile-qa-architect | **done** — crop blocker CONFIRMED on device against real ML Kit, then re-measured after the fix (chin 1.04–1.10 → 0.64–0.85 of frame height, five faces, 20/20 probe measurements green). **213 tests pass, 0 skipped; `flutter analyze` clean.** Suite grew from 11 tests to 213: crop-geometry golden over all 30 specs, all six compliance checks including every failure branch, the `in_app_purchase` layer, the Pro export gate, screen layout at 5 phone sizes. `integration_test/screenshots_test.dart` + `test_driver/` verified end-to-end on the iPhone 15 Pro simulator — 5/5 PNGs in `store_assets/screenshots/raw/ios/`, using stage 2's slugs. Two further blockers found and fixed in flight (HomeScreen layout overflow; empty source file surfacing a raw RangeError). No open findings; one deliberate decision left for stage 4 (Watermarker degrades open on a decode failure — assessed as not a paywall hole, pinned by test). `docs/TEST_PLAN.md` has the evidence, the coverage map, how to re-run each suite, and the caveats on reading the probe's numbers. | 2026-08-05 |
| 4a | code-review | mobile-code-reviewer | **done — Verdict: PASS (re-review 2026-08-05)** — 0 Critical, 0 Major, 10 Minor. Round 1 was FAIL (6 Major); the fix round closed all six and the re-review verified each independently at its cited location rather than from the resolution table. Baseline re-run from scratch: `flutter analyze` clean · `flutter test` **285 passed, 0 skipped** (was 213). **PERF-1** image pipeline now in `Isolate.run` via top-level `renderProcessedPhoto` with a `FaceMeasurement` of plain doubles — verified the closure captures only sendable data, the file read moved inside the isolate, and that `test/pipeline_isolate_test.dart` is a genuine property test (it drives the real `process()`, not the helper). **CQ-2** `assets/specs/SOURCES.md` is the strongest artefact of the round: per-spec provenance with URLs, an explicit derive-vs-published rule, 16 authorities checked and confirmed not to publish an eye-line figure, and candour about its own weak citations. Data verified to match. **CQ-1** seventh check "Eye line within spec" wired to the measurement, `honoursSpecEyeLine` selecting the wording; `DemoData` grows the same check *computed* from the portrait, so screenshots cannot photograph a red check. **CQ-3** goldens sweep 0.45 and 0.59 across all 30 specs (61→121) and now assert each spec's own band, not just ICAO's envelope. **CQ-4/CQ-5** `CaptureScreen` has a single owner with a re-entrancy guard, and `_CaptureError` makes an error without a recovery unconstructible. **Second opinion on the judgement call: AGREE — report the conflict, do not suppress it.** Suppressing would recreate the stage-1 defect class (a check that cannot fail). My own sweep found *more* margin than the fix note claimed: **0/30 specs report red across eye-in-head 0.45–0.62**; `honoursSpecEyeLine` flips at e≈0.609 but the check still passes to e≈0.650 because the solver shrinks the head to hold the band edge, giving ~0.06 of headroom over the probe's 0.576–0.590. Filed one Minor dissent (**RR-2**): the behaviour is right but `ValidationCheck` is binary, so a conflict the user cannot fix renders identically to a tilted head — wants a third "advisory" state so "6/7 passed" stops implying an action. **RR-1 (hand-off to stage 7):** `store_assets/screenshots/raw/ios/*.png` are timestamped 14:49, before the spec data (17:28) and the report (18:03) changed — all five show the SIX-check report and must be recaptured. **RR-3:** stale "six checks" wording in `demo_data.dart:45` (doc comment also detached from its member), `docs/TEST_PLAN.md`, `store_assets/screenshot_specs.md`. **Not re-verified:** the device probe has not been re-run since the spec-data change — headless verification covers the arithmetic, not real ML Kit boxes; stage 3 should re-run once (flaky 1-in-3, retry before believing a failure). Minors still open by agreement: ~~CQ-7~~ (**closed in stage 4d**), CQ-8, CQ-10, PERF-2, PERF-3, plus the non-blocking watermark fail-closed note. Score 7.5→**8.5/10**, performance risk High→**Low**. | 2026-08-05 |
| 4b | security | mobile-security-auditor | **PASS (re-audit 2026-08-05)** — 0 Critical, 0 High. Both blockers closed at the root and verified independently, not from the diff. **SEC-1 closed:** Podfile carries `PERMISSION_CAMERA=1`, `pod install` was run (84 configs in `Pods.xcodeproj`), and both frameworks were genuinely rebuilt — `otool -oV` now shows `AudioVideoPermissionStrategy` with all 3 protocol methods (was `baseMethods 0x0`) and `nm -u` shows `AVCaptureDevice` linked with **no** Contacts/Location/ATT/Speech/MediaLibrary/Sensors/Bluetooth class pulled in, so the privacy surface the store answers depend on is real and checkable. Pinned by `test/ios_permission_macros_test.dart`, which also asserts camera is the *only* enabled macro and that the generated Pods project agrees with the Podfile — the Podfile-edited-but-`pod install`-forgotten state that shipped. Keeping `permission_handler` with the macro was the right call; the test addresses the risk that made me prefer removal. **SEC-2 closed:** `PRIVACY_POLICY.md` rewritten with a "What uses the network" section disclosing ML Kit's diagnostics honestly and no attempt to silence them; corrected Apple/Play label answers recorded in `docs/PRODUCT_SPEC.md` and in three places in this file; accurate claims preserved ("no photos leave your phone" is untouched and still true). **SEC-3 closed:** temp export duplicate gone, `PhotoFiles.discardSource` on provider dispose, launch sweep. Gates re-run by me: `flutter analyze` clean · `flutter test` **285 passed, 0 skipped**. **Open and non-blocking:** 2 Medium — ~~SEC-4~~ and ~~SEC-5~~, **both closed in stage 4d** (SEC-4 preview capped at 640 px on the locked path; SEC-5 `allowBackup="false"` + `dataExtractionRules`, verified in the release merged manifest); 6 Low, of which **SEC-8 is also closed in 4d**, incl. **new SEC-11 → for stage 5: `store_assets/screenshot_specs.md` still sells "No data collected" and "Everything runs offline" as shot `04_home` copy — the label warnings elsewhere point at the label, not at the screenshot copy, so this is the sentence most likely to slip through.** SEC-8 (`.gitignore` gaps) is still free to fix because the repo is still not a git repo. Full detail + re-audit section in `docs/audits/security.md`. --- ORIGINAL FAIL (superseded): **SEC-1 (Critical): the iOS camera flow crashes.** `permission_handler_apple` gates all 19 permission strategies behind macros that default to `0`, and `ios/Podfile`'s `post_install` never sets `PERMISSION_CAMERA=1`, so `AudioVideoPermissionStrategy` compiles to an empty class — confirmed in this repo's own built frameworks (`otool -oV` reports `baseMethods 0x0`). `Permission.camera.request()` therefore sends an unrecognized selector → uncaught ObjC exception → SIGABRT. Root cause of stage 4a's CQ-5 on iOS; CQ-5's recovery-path fix does not address it. Invisible to analyze/test/build and to the screenshot harness (SCREENSHOT_MODE never opens the camera). **SEC-2 (High): "No data collected" is not accurate.** ML Kit links a live Clearcut telemetry client (`play.googleapis.com/log`) and `MLKitCommon`'s own `PrivacyInfo.xcprivacy` declares collection of Device ID, Product Interaction, Performance and Diagnostic data for Analytics — so both store labels and `PRIVACY_POLICY.md`'s "the IAP library is the only component that uses the network" must change. **Photos are not affected: the model is bundled (verified in the release AAB) and no image leaves the device — "no photos leave your phone" stays true.** Mediums: photo copies persist in the app cache vs the policy's never-saved promise (house lucky_numbers precedent, overlaps CQ-9); `/result` shows the free tier the unwatermarked crop above print resolution; Android Auto Backup on by default carries `pro_unlocked`. Watermarker fail-open ruled **Low, not blocking** — agreed unexploitable, still recommend inverting to fail closed. Verified clean: no hardcoded secrets, keystore + `key.properties` genuinely git-ignored (tested, not assumed), `RECORD_AUDIO` absent from the release merged manifest, SCREENSHOT_MODE cannot unlock a release build, export gate holds. | 2026-08-05 |
| 4c | fix round | flutter-architect | **done** — all 6 Major code-review findings + both blocking security findings fixed; see the fix-round section below. **Gate: `flutter analyze` clean · `flutter test` 285 passed, 0 skipped (was 213) · `flutter build ios --debug --no-codesign` OK · `flutter build apk --debug` OK · SEC-1 verified by running the capture flow on a booted iPhone 15 Pro simulator, camera prompt confirmed on screen.** Stages 4a/4b are ready to re-run. | 2026-08-05 |
| 4d | pre-submission fixes | flutter-architect | **done** — the four findings both auditors left open that are cheaper to take before submission than after. **SEC-4 closed**: the locked `/result` preview is capped at a 640 px long edge (`AppInfo.lockedPreviewLongEdgePx`), per growth-monetization's call in `docs/ASO.md` §7.1 — Pro still decodes full resolution, and the free tier's watermarked **600 px save is unchanged**, they are separate constants. **SEC-5 closed**: `android:allowBackup="false"` + `android:dataExtractionRules` excluding both cloud-backup and device-transfer, confirmed in the *release* merged manifest and in the compiled APK resource. **SEC-8 closed**: `.gitignore` gaps closed while the repo still has no history (one deliberate deviation — `Debug/Release.xcconfig` stay tracked, they carry no local path and a fresh clone needs them). **CQ-7 closed**: `EntitlementController.build()` resets `_disposed`. Both new behaviours are pinned by tests **verified against the bug** (forced off, they fail). **Gate: `flutter analyze` clean · `flutter test` 293 passed, 0 failed, 0 skipped (was 285) · `flutter build apk --debug` OK · `flutter build appbundle` OK.** No git commit. **READ_MEDIA_IMAGES REMOVED** — it was ours, no plugin contributed it, and nothing needs it (the picker gets a per-item URI grant); this drops Play's **Photo and Video Permissions** declaration, which gates rollout. Verified on an API 36 emulator by driving the real gallery flow end to end. **PRODUCT_SPEC's Play "not shared" line corrected to "shared"** to match `android/fastlane/data_safety_answers.md`. **`docs/audits/` is now gitignored** (founder call) — files stay on disk, archive them outside the repo. Detail in the stage-4d section below, and resolutions appended to both audit files. | 2026-08-05 |
| 5 | metadata | growth-monetization → release-manager | **done — 5a (growth/ASO) and 5b (release metadata) both complete**. `docs/ASO.md` and `docs/MONETIZATION.md` written; `store_assets/screenshot_specs.md`, `screenshots/screens.js`, `screenshots/render.sh` and `integration_test/screenshots_test.dart` updated to match. **Store text must come from `docs/ASO.md` §9 verbatim** — Apple name `Passport Photo Studio` / subtitle `ID & visa photos. One payment.` / two 95-char keyword fields (en-GB and en-US are separate localisations, set both) / Photo & Video + Utilities; Play title same / short description `Skip the booth. Passport, visa and ID photos checked against the spec.` / Photography. §9 also carries the cleared-claims and forbidden-claims lists — the forbidden list includes every acceptance promise **and** "no tracking" / "everything runs offline" / "No data collected". **SEC-11 closed:** shot `04_home`'s subheadline is gone, replaced by `03_home` "No ads. No account. Your photo is never uploaded." **Screenshot set reordered and rewritten:** shots 3 and 4 swapped (slugs renamed `03_home` / `04_picker` — privacy outranks the country count, which is the comparison this app loses against rivals advertising "150+ countries"), shot 01's headline "Passport photos approved first time" **withdrawn as an acceptance promise**, shot 02's "£10–15" currency claim dropped, stale "six checks" → seven everywhere incl. `demo_data.dart`'s detached doc comment (RR-3). Stale `out/*.png` renders deleted; raws renamed, and all five still need recapture per RR-1. **SEC-4 call: CAP the locked preview at a 640 px long edge** — the digital-upload path (now the majority for UK renewals) makes the free preview a usable substitute for the £4.99 file; one downscale on the locked path, owed before submission — **implemented and pinned in stage 4d**. Pricing £4.99 confirmed unchanged. **Two in-app copy findings:** the paywall's hardcoded "A photo booth charges around £6" shipped one £ figure to every storefront and was a price claim about a third party — **fixed** in `paywall_screen.dart:100` ("charges several times more"); and the paywall screenshot's "£4.99" comes from `screenshots_test.dart`'s `_harnessPrice`, not a store, so **stage 7 must confirm the IAP is created at the £4.99 price point and renders as `£4.99` in en-GB before upload**. Gates re-run after the edits: `flutter analyze` clean · `flutter test` **285 passed, 0 skipped**. Raws were recaptured at 18:26 and now show 7/7, so RR-1 looks closed for iOS; `raw/android/` is still empty by design and the Play set renders "capture missing" until stage 7 shoots it. All 15 frames re-rendered and reviewed. **5b (release-manager, 2026-08-05):** full fastlane metadata written for **both** English localisations — `ios/fastlane/metadata/{en-GB,en-US}/` (name 21, subtitle 30/30, keywords 95/100 each and locale-specific per ASO §9, promotional_text 168/170, description 3216/3217 of 4000, release_notes, support/marketing `https://froggyeye.com`, privacy_url), `metadata/copyright.txt` + `primary_category.txt` (`PHOTO_AND_VIDEO`) + `secondary_category.txt` (`UTILITIES`), `review_information/` (Kevin Lam · info@froggyeye.com · **+447415533188** · demo_account_required=false · notes 3998/4000), and `android/fastlane/metadata/android/{en-GB,en-US}/` (title, short_description 70/80 verbatim, full_description 3656/3658, empty `video.txt`, `changelogs/1.txt` + `default.txt` 403/500). Every field character-counted and within cap; grepped clean against ASO §9's forbidden-claims list (no acceptance promise, no "no tracking"/"offline"/"No data collected", no agency names). **Apple privacy answers are the CORRECTED ones** in `ios/fastlane/app_privacy_details.json`: Data Not Linked to You → Device ID, Product Interaction, Performance Data, Other Diagnostic Data; tracking No on every row; photos explicitly not collected. `android/fastlane/data_safety_answers.md` written with the matching Play answers plus Advertising ID = No, App access = No login, IARC "All other app types", target audience 18+. **Three items for stage 6/7, in priority order: (1) `READ_MEDIA_IMAGES` in the release manifest means Play's separate Photo and Video Permissions declaration is required before rollout — or drop the permission if `image_picker` already routes through the system photo picker; (2) `docs/PRODUCT_SPEC.md` says ML Kit data is "not shared" while the data-safety sheet declares it shared with Google — reconcile before submitting; (3) stage 7 must push the repo to `mksoft-ltd/passportphoto` and confirm the privacy URL returns 200, since the metadata already points at it.** | 2026-08-05 |
| 6 | compliance | app-store-review-auditor | **FAIL — 3 Blocker · 3 High · 3 Medium · 5 Low.** Full report: `docs/audits/store-compliance.md`. **C-1 (Blocker):** the privacy URL in both iOS localisations and in `data_safety_answers.md` §1 returns **404** — `mksoft-ltd/passportphoto` does not exist yet. **C-2 (Blocker, NEW — not on any hand-off list):** `AppInfo.privacyPolicyUrl` (`lib/core/constants/app_info.dart:14`) points at `mksoft-ltd/**passport_photo_app**` while the store metadata points at `mksoft-ltd/**passportphoto**` — two different repos. Stage 5's instruction to "push to `mksoft-ltd/passportphoto`" closes C-1 and leaves the **in-app** link permanently dead; it is the "Privacy policy" button at `paywall_screen.dart:349`, visible in screenshot `05_pro` which is also Apple's IAP review screenshot. Needs a code change + rebuild, not a console fix. **C-3 (Blocker):** all five `store_assets/screenshots/out/android/*.png` are **"CAPTURE MISSING" placeholders** — correct 1080×1920, correct names, ~790KB, rendered *after* the iOS set, and every one shows a branded card naming the screen and printing `raw/android/01_result.png`. `raw/android/` holds only `.gitkeep`. I opened them; `ls` cannot tell. The **iOS set is genuinely fine** — opened `ios69/01_result`, `03_home`, `05_pro`: real captures, light appearance, "7 / 7 passed", paywall correctly in its locked pre-purchase state. **H-1:** `ITSAppUsesNonExemptEncryption` is absent from `ios/Runner/Info.plist` (grepped all of `ios/`) → "Missing Compliance" blocks *every* upload until answered by hand; correct answer is `false` (no bundled crypto lib — Pods are ML Kit/Google standard-TLS consumers only). **H-2:** `android/fastlane/data_safety_answers.md` still describes `READ_MEDIA_IMAGES` in three places (preamble manifest list, §8 "Photo and video permissions: Required", §9 reviewer notes) though stage 4d removed it — verified off the **release merged manifest parsed as XML**: 7 permissions, no `READ_MEDIA_IMAGES`, no `RECORD_AUDIO`, no `AD_ID`, targetSdk 36, allowBackup=false. Nothing uploads that sheet, so a human would type it in and file an unnecessary Photo & Video Permissions declaration (gates rollout) plus a reviewer note that contradicts the APK. **H-3:** `05_pro` shows "Unlock Pro — £4.99" injected by `screenshots_test.dart:233` `_harnessPrice`, and line 227 records that en-GB and en-US **share one screenshot set** — so the US listing would advertise a GBP price. The *app* is right (`displayPrice` has no literal fallback, falls back to a bare "Unlock Pro"); only the screenshot is not. Fix: create the IAP first, then capture per-storefront, or ship en-US four shots per stage 2's standing rule. **Mediums:** raw-markdown privacy URL (`text/plain`, Apple 5.1.1 risk — prefer GitHub Pages); store art absent from the paths `deliver`/`supply` read and **no 512×512 Play icon exists** (feature graphic is correct at 1024×500 opaque); Android capture never run. **Verified clean, tested not assumed:** spec claim is exact (30 specs / 21 real countries + ICAO + Schengen, doc types match "passport, visa, ID card or driving licence"); zero forbidden claims in shipped store text (only hits are `screenshot_specs.md`'s own guidance prose); every character count within cap measured in Python; IAP is native `in_app_purchase` non-consumable with restore reachable from the home app bar on every launch and `completePurchase` always called; **no subscriptions so 3.1.2(c) is N/A**; no account → deletion + Sign in with Apple both N/A; no UGC; Apple label ↔ Play sheet ↔ code all agree and the ML Kit disclosure is adequate under 5.1.2; no ATT/ad-ID/ads/analytics SDK; no `http://`, no secrets; `screenshotMode` is `!kReleaseMode`-folded; `TARGETED_DEVICE_FAMILY = 1` on all three configs so no empty iPad slot; review_information/ complete incl. phone. **Apple 4+ / Play Everyone / Play target audience 18+ are all supportable and not in conflict.** | 2026-08-05 |
| 6b | compliance fix round | flutter-architect | **done — C-2, H-1 and H-2 resolved.** **C-2:** `AppInfo.privacyPolicyUrl` now reads `https://raw.githubusercontent.com/mksoft-ltd/passportphoto/refs/heads/main/PRIVACY_POLICY.md`, matching both iOS localisations and `data_safety_answers.md` §1 — one repo name across all four places. New `test/privacy_url_consistency_test.dart` reads the fastlane files off disk and pins the constant against them, so the drift cannot recur silently. **H-1:** `ITSAppUsesNonExemptEncryption</key><false/>` added to `ios/Runner/Info.plist`; `plutil -lint` OK and `PlistBuddy` confirms the key is `false` in the **built** `Runner.app/Info.plist`, not just the source. **H-2:** all three `READ_MEDIA_IMAGES` references in `android/fastlane/data_safety_answers.md` corrected — the preamble now lists the real 7-permission release manifest, §8 answers **"Photo and video permissions: Not applicable — do not file the declaration"** with the system-photo-picker per-item URI grant as the reason, and §9's reviewer bullet no longer names the permission. **Gate: `flutter analyze` clean · `flutter test` 297 passed, 0 failed, 0 skipped (293 + 4 new) · `flutter build ios --debug --no-codesign` OK.** No git commit. **Still owned by stage 7: C-1** (create/push `mksoft-ltd/passportphoto` public and confirm the URL serves the policy body), **C-3/M-3** (capture the Android screenshot set, re-render, open one output), **H-3** (do not ship the £4.99 `05_pro` shot to en-US). | 2026-08-05 |
| 7 | publish | store-publisher | **DONE — BOTH STORES SUBMITTED FOR REVIEW. Apple: version 1.0.0 + Pro IAP both `WAITING_FOR_REVIEW` (2026-08-07, app id 6798892716, submission `d44e5cab`, 2 items, states read back from the API). Play: "Changes in review" since 2026-08-05.** Apple detail, including the four things that bit (version string `1.0` vs `1.0.0`, en-US-only name collision, `deliver` double-uploading every screenshot, content-rights gate) is in the ✅ block in the Apple section below. Nothing left for the founder on Apple. Historical pre-submission state follows: **Play: UPLOADED (production track, draft) — Apple: BUILT AND STAGED, blocked on the ASC app record.** All three stage-6 leftovers closed: **C-1** — `mksoft-ltd/passportphoto` created public and pushed (244 files; no keystore, `key.properties`, `.p8`, `local.properties` or `docs/audits/` in the tree, and no committed file carries a home path), privacy URL returns **200 with a body byte-identical to `PRIVACY_POLICY.md`** (`diff` clean, not just a status check). **C-3** — Android raws captured on an API 36.1 emulator, `render.sh` re-run for all 15 frames, and **two outputs opened and eyeballed** (`01_result` shows the real Review screen at "7 / 7 passed"; `05_pro` shows the real paywall reading "Google Play account"). **H-3** — took option (b): **en-GB ships 5 shots, en-US ships 4** with `05_pro` omitted, so no GBP price reaches the US listing and no price was invented. Verified server-side after upload: en-GB 5, en-US 4. Also done: keystore + `key.properties` backed up to `~/.app-keystores/passportphoto/` (dir 700, files 600, md5 matched); fastlane scaffolded both platforms; **512×512 Play icon generated** (M-2) and store art synced into the paths `deliver`/`supply` actually read. **Play:** AAB 72.4 MB versionCode 1 signed `CN=Froggy Eye Ltd` (SHA-1 `53:FA:02:54:1F:AF:7C:86:60:53:33:D9:6D:81:91:9E:84:4E:E0:98`) uploaded to **production as a draft**, both listings + icon + feature graphic + changelogs live; **IAP `com.froggyeye.passportphoto.pro` created via API and ACTIVE** — 173 regions, GB exactly **£4.99**, `legacyCompatible: true`. **Apple:** IPA 40.6 MB built and verified (`Apple Distribution: Froggy Eye Ltd`, profile `Passport Photo Studio App Store`, `get-task-allow=false`, `ITSAppUsesNonExemptEncryption=false` and `UIDeviceFamily=[1]` read out of the **built** binary), metadata and screenshots staged. Upload is genuinely blocked, confirmed not assumed: `altool --validate-app` returns `Cannot determine the Apple ID from Bundle ID 'com.froggyeye.passportphoto'` because `GET /v1/apps` still returns 0 records. **UPDATE 2026-08-05 (conductor, founder-approved): Play SUBMITTED for review.** All console declarations completed in the founder's browser: privacy policy URL, Ads No, Sign-in details No, Target audience 18+, Data safety (collected+shared: Device or other IDs, App activity>Other actions, App info>Diagnostics+Other performance data; encrypted in transit; no deletion mechanism; purposes App functionality+Analytics; not for tracking), Advertising ID No, Government/Financial/Health none, Store settings App/Photography + info@froggyeye.com + https://froggyeye.com, IARC questionnaire completed with founder-approved terms acceptance (All other app types, digital goods Yes, everything else No) -> PEGI 3 / ESRB Everyone family, countries/regions UK + US (founder choice), release 1.0.0 previewed and confirmed ("Ready to release", 17.5 MB), "Send 11 changes for review" confirmed. Status: **Changes in review** — transmits to Google when Play's quick checks complete (~14 min); check Publishing overview later for any quick-check failure. Typical review <=7 days; app goes live in UK+US automatically on approval (managed publishing off). Post-2FA Apple runbook and the Play console checklist are in the stage-7 section below. **UPDATE 2026-08-07 (store-publisher, Apple runbook attempt): still blocked at step 0, but for a NEW reason — the ASC web session was alive and 2FA-free, the New App dialog opened, and the run was stopped by the local Claude Code permission classifier refusing all form entry (`computer:type` and `form_input` both DENIED; clicks, screenshots and `read_page` allowed). `POST /v1/apps` re-confirmed 403 `does not allow 'CREATE'`, so there is no API escape. Console left clean, nothing created, no app record exists. Runbook steps 1–9 all gate on the record so none ran; every staged artefact re-verified intact (IPA 40.4 MB, en-GB/en-US metadata, review phone +447415533188, screenshots en-GB 5 / en-US 4, IAP review screenshot, product ID). See the ⚠️ attempt block in the Apple section for the exact allowed/denied table.** | 2026-08-07 |
| 7b | Play rejection fix | conductor + ui-designer | **done — RESUBMITTED 2026-08-12, "Changes in review" ("11 changes sent for review" toast confirmed).** Play REJECTED the app 11 Aug 2026 (never live, so nothing was unpublished): **Metadata policy**, evidence = the **hi-res store icon (en-GB)** — the brand mark's green circular tick badge reads as approval/award imagery ("claims about store performance, ranking, or awards"; console policy-issue 4988125441629232961, email attachment HI_RES_ICON-1119.png). Apple was checked FIRST via the API and is **unaffected** — version 1.0.0, Pro IAP and submission `d44e5cab` all still `WAITING_FOR_REVIEW`; Apple was deliberately left in the queue (its icon still carries the tick; the reworked mark rides the next iOS release — do NOT pull the submission for this). **Fix (ui-designer):** tick badge removed from the brand mark at the source (`store_assets/branding/make_branding.py`), all artifacts regenerated (icon_master, adaptive foreground, play_icon_512, feature graphic, splash, previews), launcher icons re-run on both platforms (iOS 1024 re-verified opaque), 512s synced byte-identical into both locales' fastlane `images/`, and the feature graphic's pill line fixed from the overclaiming "Nothing leaves your phone" to the cleared "No ads. Your photo never leaves your phone." `store_assets/BRAND.md` carries a dated rule: **no tick/badge/seal/star/laurel imagery may return to store art** (in-app compliance-report ticks are genuine functionality and are fine). **Ship:** pubspec → `1.0.0+2`, changelogs/2.txt added (both locales), AAB rebuilt (72.4 MB, versionCode 2 verified in-bundle, cert SHA-1 matches the v1 upload key exactly), uploaded via the raw androidpublisher edit (house §28 path) together with new icon+featureGraphic for en-GB and en-US, committed with `changesNotSentForReview=true` (required while an app sits rejected — the first commit 400s without it; the SAME edit can then be re-committed with the flag, nothing is lost), then console "Send changes for review" clicked and confirmed. Gates before build: `flutter analyze` clean · `flutter test` 297 passed · new PNGs opened and eyeballed. **NOT committed to git** (icon assets + pubspec bump are uncommitted working-tree changes, same as the pre-existing en-US rename edits). If Play rejects again, start at Policy status, not the API. | 2026-08-12 |
| 7c | Apple rejection fix | conductor | **done — RESUBMITTED 2026-08-28, submission `d44e5cab` + version 1.0.0 + Pro IAP all `WAITING_FOR_REVIEW` (read back from the API).** Apple rejected 2026-08-19 (both items, same message): **Guideline 2.1 — Information Needed about face data** — the standard six-question face-data questionnaire triggered by ML Kit face detection, plus a demand to *quote the privacy policy's face-data text*. This is an information request, not a defect; no binary or metadata change was needed. **Fix:** (1) `PRIVACY_POLICY.md` gained a dedicated **"Face data"** section (detection-not-recognition, RAM-only during processing, zero retention/storage/sharing, ML Kit diagnostics carry no face data) — committed `b521b9d`, pushed to `mksoft-ltd/passportphoto`, live URL verified serving the new text; the app's in-app link and store metadata point at the same raw URL so **no rebuild was needed**. (2) Replied in the Resolution Center answering all six questions and quoting the new section verbatim (reply visible in the thread, "Kevin Lam, 2026-08-28 12:56 PM"). (3) Resubmission mechanics for a REJECTED submission where nothing else changed: the submission page's "Resubmit to App Review" is DISABLED while items sit Rejected — click **"Update Review" on the version page AND on the IAP's own page** (no edits required; each click flips its item to "Ready for Review"), and only then does Resubmit enable. Clicked it; state confirmed `WAITING_FOR_REVIEW` in console and API. **Play checked the same day: the 7b resubmission was APPROVED — "Last published 17 August 2026", no pending changes, and the store listing returns 200 (LIVE in UK+US).** Follow-up owed: stage-8 website refresh now that Play is live (`fetch_store_assets.py` / `refresh_store_urls.py` + `postprocess.py` + `deploy.py`), and the Apple privacy-label state is unchanged (published pre-submission). | 2026-08-28 |
| 7d | Apple rejection #2 (closed — diagnosis superseded by 7e) | conductor | **REJECTED AGAIN 2026-08-29 03:40 — Guideline 4.3(a) Design: Spam** ("shares a similar binary, metadata, and/or concept as apps submitted to the App Store by other developers, with only minor differences"). The 2.1 face-data information request was NOT re-raised — the 7c answers stood; this is a fresh ground. States read from API + console: submission `d44e5cab` `UNRESOLVED_ISSUES`, version 1.0.0 item **Rejected — 4.3.0 Design: Spam**, Pro IAP item still **Ready for Review**. Play is unaffected (live in UK+US since 17 Aug). Message is boilerplate — no specific app named, no specific similarity cited. Assessment: the passport-photo category is spam-saturated and the 4.3(a) form letter is routinely fired at it; the codebase is original (public repo `mksoft-ltd/passportphoto`, full history, generated-in-repo assets, no purchased template), so the response path is (1) Resolution Center reply asserting originality with evidence + asking what specifically matched, (2) if refused, formal App Review Board appeal, (3) only then metadata/concept differentiation. **RESOLVED SAME DAY (founder-approved): Resolution Center reply posted ("Kevin Lam, Today 8:08 AM", visible in thread) making the originality case with verifiable evidence — public repo URL, generated-in-repo store art, the measured seven-check compliance report + `assets/specs/SOURCES.md` citations as the distinct functionality, on-device/no-SDK architecture, one-app-one-account — and asking Apple to name the specific app/element considered similar. All three evidence URLs curl-verified 200 before sending. Then the 7c resubmission mechanics re-run: "Update Review" on the version page flipped the rejected item to Ready for Review (IAP was already there), "Resubmit to App Review" clicked. Verified from the API: submission `d44e5cab` **`WAITING_FOR_REVIEW`, submittedDate 2026-08-29T07:08:55Z, both items `READY_FOR_REVIEW`**. Binary and metadata unchanged — this is a contest-and-resubmit, not a rework. **If 4.3(a) comes back again: file a formal App Review Board appeal (link is in the Reply dialog), do NOT resubmit a third time unchanged; after an upheld appeal failure, consider metadata differentiation (lead with the compliance-checking angle) as the last resort since it costs the ASO keyword work.** | 2026-08-29 |
| 7e | Apple rejection #3 (superseded by 7f) | conductor | **SUPERSEDED 2026-10-11 — the old record was deleted and a fresh one submitted (row 7f); the ids, submission and "do not resubmit" instructions below refer to the deleted record. Do not act on them.** **UPDATE 2026-09-23: App Review Board appeal SENT for Passport Photo Studio only (Apple confirmation page read back); the other two apps were dropped from it at the founder's call. Privacy policy moved to https://passportphoto.froggyeye.com/privacy.html and set on both ASC localisations (PATCH 200, read back); app repo repointed (uncommitted). Play Console privacy URL not yet changed. Duplicate/dead drafts deleted by Kevin 2026-09-23: account now 27 app records (was 32), FuelWatcher + FuelWatch + Heart Piece gone (API read-back). Do NOT resubmit while the appeal is open — wait for the Board.** **REJECTED A THIRD TIME 2026-09-02 00:33 — Guideline 4.3(a) Design: Spam, the form letter repeated word for word.** The 29 Aug Resolution Center originality reply was never engaged with. Submission `d44e5cab` `UNRESOLVED_ISSUES`, version 1.0.0 `REJECTED`, Pro IAP still `Ready for Review` (read from the API + console 2026-09-18). **7d's diagnosis was WRONG and its remedy would have been wasted.** 7d read this as the spam-saturated passport-photo category firing a form letter at a lone app, and queued renaming + ASO differentiation as the fallback. Evidence that kills that reading: **Sleepy Clock: Bedside Sky** (app `6798893264`, sub `9af604e8`) and **AI CLI Coach: Agent Lessons** (app `6801330248`, sub `e5a6410d`) received the **identical 4.3(a) text at the identical timestamp, 2026-09-02 00:33**. A passport-photo tool, a bedside clock and a CLI lesson app share no concept, category or metadata, so **this is an account-level determination, not an app-level one** — and renaming this app cannot fix it, because Sleepy Clock already has a different name, category and metadata and drew the same verdict. Note the guideline text says "by **you** or other developers"; the 29 Aug reply argued only the *other developers* half. **Actual trigger, portfolio shape:** 32 app records under Froggy Eye Ltd; five new apps (3–7 Aug: Lucky Numbers, Drift, Sleepy Clock, Passport Photo, Honest Signal) plus eight same-day updates (7 Aug) in one week; near-duplicate records sitting in the account, **FuelWatcher `com.froggyeye.fuelwatcher` and FuelWatch `com.froggyeye.fulewise`, both PREPARE_FOR_SUBMISSION, both created 2026-03-29**, plus Love Score / LoveMeNot / Heart Piece. **"Same source code" is defensible as false, and was measured:** passport_photo_app vs sleepy_clock share exactly one `lib/` path, `main.dart` (universal to Flutter), whose whitespace-insensitive diff is 38 differing lines across files of 24 and 26; the real shared surface is the dependency stack (`in_app_purchase`, `shared_preferences`, `url_launcher`) and house architecture (purchase service + entitlement provider + paywall screen) — one developer's style, not a template. **Secondary provenance defect, likely aggravating:** both store listings give the privacy policy as `raw.githubusercontent.com/mksoft-ltd/passportphoto/...` — raw markdown, `text/plain`, under an org named **mksoft-ltd** while the seller and copyright holder is **Froggy Eye Ltd**. The 29 Aug reply volunteered that same repo as proof of originality, i.e. handed Apple a provenance trail pointing at a differently-named company, which corroborates the "purchased template from a third party" factor it was meant to rebut. `froggyeye.com` is live (200) but has no `/privacy` (404). **NEXT, in order: (1) do NOT resubmit any of the three unchanged — repeat resubmission after 4.3(a) escalates toward account-level action; (2) one App Review Board appeal at portfolio level covering all three apps, **founder-approved 2026-09-18 and the appeal form is FILLED AND VERIFIED at `developer.apple.com/contact/request/app-review/appeal/`, covering all three apps in one submission (Passport Photo Studio / Sleepy Clock / AI CLI Coach, each with 4.3-Spam ticked, topic App Rejection, and its own reason text of 1993/1256/1289 chars against a 2000-char cap) — BLOCKED, NOT SENT: the form's Phone Number field is `required` and was left empty rather than invented.** Both `[CONFIRM]` items resolved: the mksoft-ltd ownership claim was REMOVED (Kevin confirmed only that the company is Froggy Eye Ltd, so the letter states the name mismatch and calls the URL legacy without asserting who owns the org), and both clean-up commitments were kept in at his instruction — which binds him to deleting the duplicate draft records and spacing submissions out. Full text and DOM-verified field readback in `docs/audits/apple_43a_appeal.md`. Also surfaced while filling the form: **two other open grounds not being appealed** — Sleepy Clock offers a `2.3.8 - Accurate Metadata` checkbox and AI CLI Coach a `5 - Legal` one, so both carry a second unresolved issue behind the spam one; (3) move the privacy policy onto froggyeye.com and repoint `AppInfo.privacyPolicyUrl`, both fastlane `privacy_url.txt` files, `android/fastlane/data_safety_answers.md` and `test/privacy_url_consistency_test.dart`; (4) delete one of FuelWatcher/FuelWatch and the other dead drafts — destructive, founder's call. **The rename + ASO rewrite queued in 7d is withdrawn as a remedy** — it costs the keyword work and the Sleepy Clock evidence shows it would not have changed the outcome.** | 2026-09-18 |
| 7f | Apple fresh-record submission | store-publisher | **SUBMITTED 2026-10-11 — new ASC record, version 1.0.2 + Pro IAP in one submission, all `WAITING_FOR_REVIEW` (read back from the API).** The old record (6798892716) had been deleted by the founder. **New ids:** app `6821667025` "Passport Photo Studio" (en-GB primary), SKU `passportphoto2`; **bundle `com.froggyeye.passportphotostudio`** (bundleId `SQQ2V5T2N4`, registered via API — FALLBACK: the deleted app's `com.froggyeye.passportphoto` is not offered in the New App dialog, Apple retires it); version `fb2077d7-ce2e-49cb-b3b7-0cb62b155763` (record arrived as `1.0`, PATCHed to `1.0.2`, AFTER_APPROVAL); build `df7defa3-9207-4c4b-a096-4f99acc0314c` = 1.0.2 (4), 40.7 MB, VALID, attached; **IAP `6821667321` product `com.froggyeye.passportphoto.pro2`** (FALLBACK: `.pro` 409 "This product ID has already been used"), £4.99 GBR base, 175 territories, en-GB+en-US localisations, review screenshot = `store_assets/screenshots/raw/ios/05_pro.png`; submission `48ef3492-82c2-4260-9eb2-c48931629e66`, 2 items, submitted 2026-10-11T16:55:11Z. Provisioning profile `46KPCSV465` "Passport Photo Studio iOS App Store" (API-created, installed). **Code:** iOS-only bundle id switched in `project.pbxproj` (Runner + RunnerTests), `ios/fastlane/{Appfile,Fastfile}`, `ios/ExportOptions.plist` (also the profile name), `integration_test/camera_permission_test.dart` comment; Android stays `com.froggyeye.passportphoto`. `AppInfo.proProductId` is now a getter — `.pro2` on iOS, `.pro` elsewhere (`lib/core/constants/app_info.dart`); `test/purchase_service_test.dart` pins both, `test/support/fake_store.dart` follows the getter. `flutter analyze` clean, `flutter test` 331 passed. Fastfile `build_ipa` now passes `--export-options-plist`. **Store config via API:** content rights DOES_NOT_USE_THIRD_PARTY_CONTENT, price free (read back 0.0), availability 175/175, age rating 4+ (`FOUR_PLUS`), categories PHOTO_AND_VIDEO + UTILITIES, review contact Kevin Lam / info@froggyeye.com / +447415533188. en-US name again collided → created the en-US appInfoLocalization as "Passport & ID Photo Studio" first (201), then `deliver` metadata_only ran clean. Screenshots counted server-side: en-GB 5 / en-US 4, no duplicates. **Privacy label** published in the console (4 types, Data Not Linked to You, no tracking, Photos unticked — checkbox state read from the DOM AND screenshots); publishing did not auto-submit. **Metadata fixes:** promotional text said "Seven checks ... four more" in both locales → "Eight checks ... five more"; review notes rewritten (3702 chars) with the face-data 2.1 answers + a quote of the live policy, and an honest paragraph saying 1.0.0 went in under a removed record, listing the 1.0.2 changes, original work by Froggy Eye Ltd (no repo cited). Screenshot `01_result` headline "Seven checks before you print" → "Every check before you print" (`screens.js`, re-rendered, both locales). **Open:** the `01_result` raw still shows the 1.0.0 report ("7 / 7 passed") — not false, but recapture it when an iOS 18-or-older simulator runtime is available (Xcode here only offers 26+, where ML Kit has no arm64-simulator slice, and the iOS 17.0 sim is no longer a valid destination). Play Console privacy URL is still the 7e leftover. Nothing committed. | 2026-10-11 |
| 8 | 1.0.3 build | flutter-architect | **done 2026-10-11, uncommitted, nothing built for release or uploaded.** `1.0.3+5`. **Spain** `es_passport` was bundled landscape (32 W × 26 H); now 26 × 32 mm, head 22.4–25.6 mm / eye line 16–22.4 mm (ICAO-derived; Spain publishes neither) — RD 255/2025 art. 6.2.d) and the Policía passport page both say only "32 por/x 26 milímetros", orientation is a recorded inference (SOURCES.md "Spain"); data version 4; a test now pins that no spec is wider than tall. **Result screen:** verdict line, failed checks first with `CheckKind.fixHint`, CTAs by outcome (passing+free → "Get the print-ready photo — {store price}"; any failure → no upsell, "Fix and re-shoot" → `/capture` via pushReplacement, spec kept). **Resume after purchase:** paywall pops `true` on unlock; result + print-sheet saves re-run (print sheet needed `skipLoadingOnReload: true` or the unlock rebuild unmounted the saver — revert-verified). **Rating prompt:** new dep `in_app_review` 2.0.12 behind `ReviewPrompter` (no new Android permissions in the merged manifest; iOS needs `pod install` on next build). Paywall row "Saved straight to your gallery" → "Unlimited photos for the whole family, every renewal". Release notes `changelogs/5.txt` + iOS `release_notes.txt` (both locales). **Gate: `flutter analyze` clean · `flutter test` 366 passed (was 331) · `flutter build apk --debug` OK.** iOS not built. | 2026-10-11 |
| 8b | 1.0.3 release | store-publisher | **Play: 1.0.3 (5) in production, `status: completed` (100%), en-GB+en-US notes — read back from the API; Console shows "Changes in review" = Production 1.0.3 + privacy policy. Apple: build 5 VALID and attached, 1.0.2 pulled from review, version renamed 1.0.3 and sitting in a NEW DRAFT submission — NOT SUBMITTED: the Pro IAP still has to be added from its own page (console click blocked by the local permission classifier, see below).** **Play:** AAB 72.8 MB, versionCode 5 / versionName 1.0.3 read from the bundle manifest, signer `CN=Froggy Eye Ltd` SHA-1 `53:FA:02:…:E0:98` (the upload key). Uploaded with `fastlane run supply` (production, `release_status:completed`, metadata/images/screenshots skipped, changelogs from `changelogs/5.txt`) — DEVIATION: not via the `release` lane, which still hard-codes `draft` from the new-app days and would have left the release unrolled; same method as the 1.0.2 release (e66ec75). Privacy policy URL changed in Play Console (App content → Privacy policy) from the raw.githubusercontent address to `https://passportphoto.froggyeye.com/privacy.html` (curl 200 first; value re-read after a page reload). Submitting it restarted the in-progress review (Google's dialog: "adds to your waiting time") so it rides with 1.0.3. Play Console app id `4972341008668638772`, developer `7290847462815639528` (Google account u/2). `data_safety_answers.md` already carried the new URL — no edit. **Data safety: no change needed** — `in_app_review` adds the Play review library only; the 1.0.3 AAB manifest has no new permissions (CAMERA, INTERNET, ACCESS_NETWORK_STATE, legacy storage as before) and the review flow sends nothing the form doesn't already declare. **Apple:** `pod install` OK; `flutter build ipa` archived then FAILED at export (exit 0, stale 1.0.2 IPA left in build/ios/ipa): the keychain now holds TWO "Apple Distribution: Froggy Eye Ltd" identities (`5C23BB…3349`, in profile `46KPCSV465`, and a newer `535BD1…A2C5`, not in it) and the name-only `signingCertificate` picked the wrong one. Exported the same archive with a scratch ExportOptions pinning SHA-1 `5C23BBAF99FD8146B4BC440B03934A60FF303349` — repo `ios/ExportOptions.plist` NOT changed; pin it (or add the new cert to the profile) before the next release. IPA verified: `com.froggyeye.passportphotostudio` 1.0.3 (5), Apple Distribution 696939LPWV, get-task-allow false, `ITSAppUsesNonExemptEncryption` false, `in_app_review.framework` present. altool upload OK (delivery `2618eaec-603d-42cb-9673-e04185bf8a17`); build `2618eaec-603d-42cb-9673-e04185bf8a17` = 1.0.3 (5) VALID. Before removal, 1.0.2 was re-read still `WAITING_FOR_REVIEW` (undecided). Submission `48ef3492` cancelled via API → `COMPLETE`, both items `REMOVED`, version `DEVELOPER_REJECTED`, IAP `READY_TO_SUBMIT`. Version `fb2077d7-ce2e-49cb-b3b7-0cb62b155763` PATCHed to `1.0.3` (200), AFTER_APPROVAL, build 5 attached (204). DEVIATION: "What's New" PATCH → 409 `Attribute 'whatsNew' cannot be edited at this time` in both locales — this is still the record's first version, which has no What's New; the release notes will apply from the next update. Description/promo/keywords/URLs identical to repo → no metadata push, no screenshots touched. Review notes rewritten (3988 chars; header v1.0.3, 1.0.2-withdrawn sentence, "NEW IN 1.0.3" list incl. SKStoreReviewController gating) and PATCHed to reviewDetail `c72d6432-d773-40aa-8b43-274a0651e1a3` (200); repo `review_information/notes.txt` updated to match. New draft submission **`954b3cbc-f146-47bd-a720-562b3ff675bb`** holds the version item (201, no blockers). `POST /inAppPurchaseSubmissions` → 409 "has no pending version for submission" (as 7f). **FOUNDER TO DO:** ASC → Passport Photo Studio → In-App Purchases → Passport Photo Studio Pro → **Add for Review → choose the existing draft** (never "Create New Submission", never the Draft Submissions flyout), then confirm the draft shows 2 items and submit (or ask store-publisher to submit `954b3cbc` via API and read back version + IAP `WAITING_FOR_REVIEW`). Nothing committed. | 2026-10-11 |

## ✅ Stage 1 finding — RESOLVED 2026-08-05 (was: crop cut the chin off)

Confirmed on device by stage 3, then fixed and re-measured. **Resolution summary
and the before/after numbers are at the end of this section**; the original
report is kept below because the reasoning in it is still the best description
of what went wrong.

---

**The crop appears to cut the chin off for most countries, including the UK.**
Found while checking the screenshot fixture's framing; not part of the stage-1
brief, and deliberately left unchanged because fixing it means changing the core
algorithm and that needs validating against real photographs, not arithmetic.

`PhotoSpec.targetEyeLineFromTopFraction` treats `eyeLineFromTopMinMm/MaxMm` as a
distance down from the **top** edge. Every government source these numbers come
from (ICAO Doc 9303, US 22 CFR, UK HMPO) states the eye line as a distance **up
from the bottom** edge, and the data in `assets/specs/photo_specs.json` is the
from-the-bottom figure.

The consequence, from `PhotoProcessor._computeCropRect`: the chin stays inside
the crop only when `0.55 × faceFraction + eyeFraction ≤ 1`. As shipped:

| Spec | 0.55·faceFrac + eyeFrac | Result |
|---|---|---|
| `uk_passport` | 1.118 | chin cropped off |
| `icao_generic` | 1.149 | chin cropped off |
| `it_passport` | 1.230 | chin cropped off |
| `us_passport` | 0.941 | just inside, almost no shoulder |
| `ca_passport` | 0.834 | acceptable |

Roughly two thirds of the 30 specs — all the 35×45 mm European/ICAO ones, which
includes the primary UK market — land above 1.0. Reading the value as
from-the-bottom (`1 - mid/heightMm`) puts every spec in the 0.65–0.83 range,
which is the right shape, though the crown then grazes the top edge on the 45 mm
specs, so the `headHeightFactor = 1.45` constant probably wants retuning at the
same time.

None of the six compliance checks would catch this: check 6 only tests whether
the crop ran past the edge of the *source* image, not whether the face is
correctly placed inside the *output*.

**Recommendation:** stage 3 (QA) should shoot real photos against `uk_passport`
and `us_passport` and confirm before this is submitted. If confirmed, the fix
belongs in `PhotoSpec` (convert the from-bottom figure once, and rename the
fields so they stop lying), plus a golden test — note that
`test/widget_test.dart` currently asserts the buggy value (`33/45`), so that
expectation has to change with it, not be preserved.

### Resolution (flutter-architect, 2026-08-05)

**What was wrong, in one line:** the eye line was read upside down, and once it
was read the right way up several specs turned out to state a face-height band
and an eye-line band that cannot both be satisfied by a real head.

**The fix, in three parts:**

1. **The convention is now in the names.** `eyeLineFromTopMinMm/MaxMm` are now
   `eyeLineFromBottomMinMm/MaxMm`, in `PhotoSpec` and in
   `assets/specs/photo_specs.json` (the values were always the from-the-bottom
   figures and are unchanged — no data error was found). The getter
   `targetEyeLineFromTopFraction`, which did the upside-down division, is gone;
   `PhotoSpec` now exposes only from-the-bottom fractions.
   `PhotoSpec.fromJson` still accepts the old JSON key as a transitional alias.

2. **New `lib/features/processing/head_framing.dart` decides the framing
   explicitly** instead of letting it fall out of two divisions. Reading the
   field the right way round is necessary but not sufficient: for a real head,
   `uk_passport`'s 29–34 mm of head with the eye line 30–36 mm up a 45 mm photo
   leaves the crown flush against the top edge at the *most* forgiving end of
   both bands, and `it_passport` is worse. So the solver states a priority
   order and follows it: (1) the whole head is inside the frame with a margin at
   both edges, never traded away; (2) head height inside the spec's band;
   (3) eye line inside the spec's band, else as close to it as (1) and (2)
   allow. It takes the subject's *measured* eye-position-within-head as an
   input rather than assuming it, which is what lets one set of rules hold both
   for the synthetic test subject (eyes 0.45 down the head) and for real ML Kit
   output (~0.59). `FaceOverlay` now solves with the same code, so the capture
   guide can no longer ask for framing the crop will not reproduce.

3. **The compliance checks can now catch a recurrence.** "Face size within spec"
   used to divide the same number the crop was built from, so it passed
   unconditionally — that is why a crop putting the chin off the bottom edge
   still reported six green checks. It now measures against the rectangle
   actually cut, after clamping and pixel rounding, with one output pixel of
   slack. "Photo fully captured" now also fails when the crown lands above the
   top edge or the chin below the bottom edge, and says which.

**`headHeightFactor` was deliberately left at 1.45**, contrary to the original
recommendation, and there is measurement behind that. On all five reference
portraits the top of the hair sits at least 1.27 ML-Kit-box-heights above the
box bottom — and the hair runs off each fixture's own top edge, so 1.27 is a
lower bound, not an estimate. 1.45 is therefore a mild over-estimate of the
head, which errs toward a looser crop; lowering it would shave the top of
someone's hair off, which is a rejection. The crown was never off the top
because of this constant, it was off because of the targeting maths, and the
solver fixes that at the source.

**Probe results** — `integration_test/crop_geometry_probe_test.dart`, 5 fixture
portraits × 4 specs on a booted iPhone 15 Pro simulator with real ML Kit. Chin
and crown are fractions of the photo height from the top, so chin > 1.0 means
the chin is below the bottom edge. No run was edge-clamped.

| Spec | chin before | chin after | crown after | eyes from bottom after |
|---|---|---|---|---|
| `uk_passport` | **1.038–1.070** | 0.755–0.785 | 0.014–0.047 | 0.546–0.557 |
| `icao_generic` | **1.061–1.098** | 0.810–0.848 | 0.011–0.049 | 0.514–0.525 |
| `us_passport` | 0.876–0.895 | 0.642–0.672 | 0.019–0.046 | 0.612–0.619 |
| `ca_passport` | 0.780–0.803 | 0.639–0.655 | 0.131–0.149 | 0.571–0.572 |

All 20 measurements now report `faceSizeOk=true` (uk reported false on every
face before the final iteration, see below). The remaining failing check on
`synth_1` is background uniformity, which is a property of that fixture's
studio backdrop, not of the crop.

`it_passport` — the worst offender named in the original report — is covered by
the headless golden suite rather than the probe, and passes there: crown +0.040,
chin 0.890, eye line 0.577 from the bottom. It is the one spec whose own two
bands are irreconcilable, so its eye line sits outside its stated band by
design; on device its eye line lands at ~0.46 from the bottom, just under ICAO's
0.50 floor. Keeping Italy's 32–36 mm head height, which is the rule actually
measured at a counter, is the deliberate trade.

**Two measurements worth keeping**, both taken from the probe's own output and
neither acted on:

- ML Kit's box bottom sits ~0.07 box-heights **above** the true chin contour
  (range 0.03–0.12 across the five faces). The app models the chin at the box
  bottom, so it slightly under-reads the chin. **Decided and closed by stage 3:
  left in place deliberately** — see `docs/TEST_PLAN.md` §1. The short version
  is that the probe already measures against the true contour chin, so the chin
  figures in the table above are real positions with the offset inside the
  measured envelope; modelling it would move numbers that are currently correct
  and would break the golden harness, which paints its chin stripe at the box
  bottom by construction. The error is also in the safe direction — under-
  reading the chin crops less aggressively at the bottom. Revisit if
  `HeadFraming.chinMargin` ever drops below ~0.05, at which point a 3%
  under-read stops being absorbed.
- The probe's crown figure carries ~±0.03 of measurement uncertainty, because
  its ground-truth detector is configured differently from the app's (accurate
  + contours vs. the app's fast mode) and the two see slightly different boxes.
  The app's own crown is deterministic at 0.040. Anyone treating the crown
  column above as a regression baseline should allow for that.

**Also fixed while in the file:** `img.decodeImage` throws rather than returning
null on an empty or truncated file — reachable from the gallery picker with an
iCloud photo that has not finished downloading — so the result screen showed the
user a raw Dart `RangeError` string. It is now caught and reported as "Could not
decode the selected image." The same unguarded decode in `Watermarker.preview`,
`Watermarker.stampJpeg` and `renderPrintSheet` is guarded too; those three run
inside background isolates, where an escaped error surfaces with nothing to
attribute it to. QA's regression test for this ("an undecodable file is reported
in words the user can act on", `test/validation_checks_test.dart`) was parked
behind a `skip:` describing the defect; that has been removed and the test now
runs in the default suite.

⚠️ **One thing that guard did not change, on purpose.** Both `Watermarker`
entry points treat "cannot decode" as "return the original bytes untouched" —
which means an undecodable input yields an **unwatermarked** image to a free
user. That is pre-existing behaviour on the null path and I only routed the
throw into the same place rather than silently changing what the fallback does.
It is close to unreachable (the bytes were encoded moments earlier by this same
app) and the real paywall gate lives in `ExportService`, so this is not the
entitlement boundary. Worth a monetization/security opinion at stage 4
regardless.

Stage 3 has since assessed this and reached the same conclusion — not a paywall
hole, because `ExportService` decides *whether* to watermark before either
method is called rather than leaning on the watermark to enforce the tier, and
"undecodable" is not a state a user can steer into. The behaviour is now pinned
by a test with the reasoning written down instead of inherited. If stage 4 rules
that it should fail closed regardless, `docs/TEST_PLAN.md` §4 names the test to
invert and where the closed behaviour belongs.

**A data question left open for the founder / a later stage.** The 35×45 mm
specs state the eye line as 30–36 mm from the bottom, which is 67–80% of the
picture height. ICAO Doc 9303's own head-height rule (70–80% of image height)
implies an eye line nearer 50–60%, and `us_passport`'s 28–35 mm on 51 mm — the
verbatim 22 CFR figure — is 55–69%. So the 45 mm figures look high, and I could
not find a published HMPO eye-line requirement for adult UK passports at all.
The data was left exactly as it was, because the app's behaviour no longer
depends on those figures being right: the solver honours them when they are
satisfiable and degrades predictably when they are not. But if someone is
re-checking spec data against sources, this is the row to check first.

**Gate (2026-08-05):** `flutter analyze` clean (0 issues) · `flutter test`
209 passed, **0 skipped** — including the 60 crop-geometry goldens QA had parked
on this fix · `flutter build ios --debug --no-codesign` OK · probe green
on-simulator for all 20 measurements. There is no `skip:` left anywhere in
`test/` or `integration_test/`.

⚠️ The probe is flaky on this simulator: one run in three died after the first
fixture with "did not complete", and an identical re-run passed all 20. Retry
before treating a probe failure as a regression.

## Stage 1 (build) — what later stages need to know

**Gate results (2026-08-05):** `flutter analyze` clean (0 issues) · `flutter test`
11/11 pass · `flutter build apk --debug` OK · `flutter build ios --debug
--no-codesign` OK.

**Console work still owed (stage 7 / store-publisher):**
- Create the IAP in **both** consoles before the build is submitted, or the
  paywall will show a bare "Unlock Pro" with no price:
  - Product ID `com.froggyeye.passportphoto.pro`
  - Type: **non-consumable** (App Store) / **one-time product** (Play)
  - Display name: `Passport Photo Studio Pro`
  - Price: **£4.99** and equivalent tier worldwide
  - App Store Connect also needs a review screenshot of the paywall for the IAP.
- **Play App Signing**: enrol on first upload. The upload key is
  `android/upload-keystore.jks` (PKCS12, alias `upload`), passwords in the
  git-ignored `android/key.properties`. Both are excluded by `.gitignore`;
  neither must ever be committed, and the keystore should be backed up outside
  the repo.
- ASC app record is still **not created** (stage 0 blocked on founder 2FA).

**Facts the metadata / compliance stages should use verbatim:**
- Spec count is **30 specs across 21 countries plus ICAO and Schengen generic
  fallbacks** — the earlier "22 countries" figure was wrong; the paywall, README
  and `docs/PRODUCT_SPEC.md` all now say 21.
- ⚠️ **CORRECTED 2026-08-05 (was "No data collected" — do not use that).**
  Stage 4b found that `google_mlkit_face_detection` links `MLKitCommon`, whose
  own `PrivacyInfo.xcprivacy` declares collection of Device ID, Product
  Interaction, Performance and Other Diagnostic Data, and whose binary carries a
  live Clearcut client to `play.googleapis.com/log`. Both stores require data
  collected by **bundled third-party SDKs** to be declared. Declaring "No data
  collected" is inaccurate, and on Play an inaccurate Data safety form is a
  suspension-class violation.

  **Apple App Privacy** — under **Data Not Linked to You**: Identifiers →
  Device ID; Usage Data → Product Interaction; Diagnostics → Performance Data
  and Other Diagnostic Data. Purposes: Analytics and App Functionality.
  **"Used for tracking" = No** on every row. No ATT prompt, no
  `NSUserTrackingUsageDescription`.

  **Play Data safety** — *Device or other IDs*; *App activity → Other actions*;
  *App info and performance → Diagnostics*. Collected, **not** shared, **not**
  used for tracking.

  Still true and worth saying in the listing: **photos are processed entirely
  on-device and never uploaded** (model verified bundled inside the release
  AAB), no advertising SDK, no advertising identifier, no crash reporter, and
  no analytics written by Froggy Eye. The full wording is in
  `docs/PRODUCT_SPEC.md` § Store privacy declaration and in
  `PRIVACY_POLICY.md`, both rewritten 2026-08-05.
- Android's merged manifest carries `INTERNET` and `ACCESS_NETWORK_STATE` —
  these come from the Play Billing library, not from app code. There is no API
  client anywhere in the codebase. `RECORD_AUDIO`, which the `camera` plugin
  contributes, is explicitly removed via `tools:node="remove"`; re-check that it
  is still absent after any dependency bump.
- Full permission table with justifications: `docs/PRODUCT_SPEC.md`.

**For stage 2 (ui-designer) and stage 3 (mobile-qa-architect):**
- `--dart-define=SCREENSHOT_MODE=true` seeds the UK passport spec, a finished
  crop with all six checks green, and Pro unlocked. Screens worth capturing:
  `/` (home, spec selected), `/picker`, `/result` (compliance report), `/sheet`
  (4×6" print sheet), `/pro` (paywall — renders the "Pro is active" state under
  screenshot mode).
- `/result` and `/sheet` take the source path as GoRouter `extra`; in screenshot
  mode any non-null string works, e.g. `context.push('/result', extra: 'demo')`.
- The demo portrait is drawn procedurally in `lib/core/demo/demo_data.dart` as a
  flat illustration, deliberately not a photograph of a real person. If the
  designer wants a photoreal headshot in the screenshots, replace
  `renderDemoPortrait` with an asset load — do not use a real person's likeness
  without a licence.
- New screens added in this stage: `/pro` (paywall) and `/sheet` (print-sheet
  preview). The result screen's second button is now "View 4×6\" print sheet",
  not a direct save.

**Product shape as built:** free tier = every country, capture, auto-crop, full
compliance report, print-sheet preview, and a watermarked 600 px save to the
gallery. Pro = full-resolution unwatermarked export + the 4×6" sheet. Countries
are never gated. The gate is enforced inside `ExportService`, which reads the
entitlement itself rather than trusting the calling screen.

## Stage 2 (design) — what later stages need to know

**Gate results (2026-08-05):** `flutter analyze` clean (0 issues) · `flutter
test` 208 pass, 1 skipped, **0 skipped in `screen_layout_test.dart`** ·
`flutter build apk --debug` OK with the new icon and splash compiled in — 31
`ic_launcher` / `splash` / `android12splash` resources in the APK. Measured
after the parallel eye-line rename landed; during that refactor the analyzer
transiently reported up to ten errors and Gradle failed once on a build-dir
race, none of it in files this stage touched.

**Deliverables:** `store_assets/BRAND.md`, `store_assets/screenshot_specs.md`,
`store_assets/README.md`, the generator `store_assets/branding/make_branding.py`
(+ `render.sh`), and the screenshot framing system in
`store_assets/screenshots/`.

**Store creative that is finished and needs no further work:**
- Play feature graphic 1024 × 500 — `store_assets/branding/feature_graphic.png`.
- App icon, both platforms. iOS 1024 is opaque (verified `hasAlpha: no`).

**For stage 3 (QA) — two requirements the screenshot harness has to meet:**
1. **Capture in light appearance.** The whole set is framed as a white app
   screen on navy; a dark capture breaks the set.
2. **Shot `05_pro` needs the paywall in its LOCKED state.** Under
   `SCREENSHOT_MODE` the entitlement is seeded unlocked, so `/pro` renders "Pro
   is active" and sells nothing. The harness needs a second launch with the
   entitlement overridden to locked. Slugs the harness must write:
   `01_result`, `02_sheet`, `03_picker`, `04_home`, `05_pro`, into
   `store_assets/screenshots/raw/{ios,android}/`.

**For stage 7 (publish):** run `store_assets/screenshots/render.sh` after the
captures land; it outputs `out/ios69` (1320×2868), `out/ios67` (1290×2796) and
`out/android` (1080×1920). No iPad set — the app is iPhone-only. If the IAP
price cannot be resolved on the capture device, **ship four shots rather than a
fifth with an invented price** (Play rejects that); `PurchaseService` correctly
falls back to a bare "Unlock Pro".

**Product changes made in this stage** (small, deliberate):
- `lib/app/theme.dart` rewritten around explicit brand tokens (`BrandColors`)
  and cool near-neutral surface families, replacing Material's violet-tinted
  defaults. Light `#F7F9FC` / dark `#0D1524` are now shared by the theme, the
  launch screen and the Android window background — change all three together.
- A passed compliance check is now **Verify Green**, not primary blue, via an
  `AppSemantics` theme extension used by `result_screen.dart`. The report is the
  reason anyone trusts this app and "passed" should not look like "tappable".
  Colour is still never the only signal: icon, label and reason all remain.
- **Home screen overflow fixed** (`home_screen.dart`). Stage 3's
  `screen_layout_test.dart` found the body `Column`/`Spacer` overflowing by 51 px
  in landscape and 74–90 px at 320×568, and skipped three groups with a comment
  asking for a scroll view. It is now a `SingleChildScrollView` over a
  `ConstrainedBox`/`IntrinsicHeight`, so the footer still anchors to the bottom
  where there is room. **Those three `skip`s are removed** — 41/41 layout tests
  now run and pass, and the fix is guarded. It is a design defect on the screen
  that carries the privacy screenshot, which is why stage 2 took it.

**Carried forward:** the screenshots are drawn from `DemoData`, whose portrait
is rendered directly at compliant framing and does **not** go through
`PhotoProcessor._computeCropRect`, so it never showed the chin-crop bug. It has
been redrawn this stage (sloped shoulders, tapered jaw, real hairline — the old
one read as clip art, and it appears in two shots and six times over on the
print sheet) and re-checked against the landed eye-line fix: face 70% of the
height, eye line 0.62 up from the bottom, which is inside both the UK face band
and the 0.50–0.80 envelope `test/crop_geometry_golden_test.dart` holds the real
crop to. Nothing fails automatically if those drift apart, so re-check it if the
crop geometry or that envelope changes.

## Stage 4c (fix round, flutter-architect) — 2026-08-05

Everything blocking from `docs/audits/code-review.md` and
`docs/audits/security.md`. Both audits are ready to re-run.

### SEC-1 (Critical) — the iOS camera flow no longer aborts

`ios/Podfile`'s `post_install` now sets
`GCC_PREPROCESSOR_DEFINITIONS = ['$(inherited)', 'PERMISSION_CAMERA=1']`, and
`pod install` has been run. `permission_handler` was **kept** rather than
dropped, because CQ-5's recovery path needs `openAppSettings()` on both
platforms and nothing dependency-free provides it on Android.

**Verified by running the flow, not by building it.** On a booted iPhone 15 Pro
simulator, with `xcrun simctl privacy … reset camera`, tapping "Take a new
photo" brings up the real iOS camera prompt carrying this app's
`NSCameraUsageDescription`. Before the fix that same tap sent an unrecognized
selector to an empty `AudioVideoPermissionStrategy` and took a SIGABRT.

Binary evidence, both slices, `otool -oV`:

| Build | `AudioVideoPermissionStrategy` `baseMethods` |
|---|---|
| Debug-iphoneos, 14:34 (before) | **`0x0`** — no method list at all |
| Debug-iphoneos, 18:03 (after) | **`0xc28`** |
| Debug-iphonesimulator, 17:49 (after) | **`0xc48`**, carrying `checkPermissionStatus:` and `requestPermission:completionHandler:errorHandler:` |

Two new gates so this cannot regress silently:
`test/ios_permission_macros_test.dart` pins the Podfile **and** the generated
Pods project in the fast suite, and asserts `PERMISSION_CAMERA=1` is the *only*
permission macro enabled — so adding one forces a matching update to the store
privacy answers. `integration_test/camera_permission_test.dart` exercises the
real permission call on a real runtime; it passed on the simulator with the
permission granted and with it revoked.

### SEC-2 (High) — the privacy claims are now accurate

`PRIVACY_POLICY.md` no longer says the IAP library is the only component using
the network, and no longer claims "no analytics of any kind". It now discloses
ML Kit's telemetry in plain terms — a non-advertising device identifier,
performance and feature-usage data, sent to Google, not to us, containing no
part of the photograph. **"No photo leaves your device" is unchanged and still
true**: the model is bundled and verified in the release AAB.

The store answers changed with it. `docs/PRODUCT_SPEC.md` has the full
per-field wording; the short version is in the stage-1 facts block above, which
previously instructed stages 5 and 6 to declare "No data collected" verbatim
and has been corrected.

### CQ-2 (Major) — the 35 × 45 mm eye-line data was wrong, and now has sources

**The bundled figure was the head-height rule copied into the eye-line field.**
80% of 45 mm is exactly 36 mm, which is the upper bound every 45 mm spec
carried. Eyes 36 mm up a 45 mm photo with a 34 mm head puts the crown 9 mm
above the top edge — the number described a photograph that cannot exist.

Data version 2 follows one rule: use the authority's published figure where one
exists, and otherwise derive from ICAO's published portrait geometry and label
it derived. **Exactly one authority in the world publishes an eye-line figure —
the United States** (56–69% of image height, already correct here). Everything
else is now ICAO TR *Portrait Quality* Table 9's 50–70% of image height, which
the US figure sits neatly inside. Full provenance, per spec, with URLs and the
contradictions found between national sources, is in
**`assets/specs/SOURCES.md`**.

Three head-height figures were also corrected against national templates while
verifying: Netherlands 32–36 → **26–30 mm** (RvIG *Fotomatrix*), Switzerland
32–36 → **29–34 mm** (fedpol), Italy 32–36 → **28–32 mm** (Polizia di Stato's
70–80% on Italy's 40 mm photo). The Italian figure was the 45 mm group's band
applied to a shorter photo, and it was the sole cause of `it_passport` being
the one spec whose two rules could not both be satisfied. **No bundled spec is
self-contradictory any more**, and `test/head_framing_test.dart` now asserts
that.

### CQ-1 (Major) — the compliance report has an eye-line check

A seventh check, "Eye line within spec", reads the measured
`eyeLineFromBottomFraction` against the spec's band and quotes the figure in
millimetres. `honoursSpecEyeLine` — computed since stage 1 and read by nothing —
now chooses the wording: a subject the framing could not place gets "re-shoot";
a spec whose own two bands contradict each other gets an explanation instead,
because telling that user to re-shoot would be telling them to do something
that cannot work.

The report is now **7 checks**, not 6. `DemoData` grows the same check, computed
from the demo portrait's own geometry rather than hard-coded green, so the
store screenshots cannot claim a compliance the drawing does not have.

### CQ-3 (Major) — the crop golden runs at both head shapes

`SyntheticSubject` takes `eyeLineWithinHead`, and the golden runs the whole
30-spec sweep at **0.45** (classical) and **0.59** (the top of what real ML Kit
produced on the reference portraits). 61 tests became 121. The suite also
asserts each spec's **own** band now, not merely ICAO's wide envelope — which
is only possible because CQ-2 made the bands satisfiable. As the audit
predicted, `it_passport` failed at 0.59 first; it was resolved by fixing the
data, not by widening the envelope.

### CQ-4 / CQ-5 / CQ-6 (Major/Minor) — `CaptureScreen` owns its controller

`_initialise()` is the single owner of the camera session: it has a
re-entrancy guard, it disposes whatever it is replacing before opening a
replacement, and `_flipCamera` now delegates to it instead of disposing
separately. The lifecycle `inactive` branch **nulls** `_controller` as well as
disposing it, so `build`'s `!value.isInitialized` guard stops reading
stale-true over a released texture. Every error path goes through one `_fail`
helper that checks `mounted`.

`_error` is cleared at the top of every attempt, permanent denial is
distinguished from a first refusal, and the error state now carries actions:
**Open Settings** when only Settings can undo it, **Try again** otherwise, and
**Pick from gallery instead** always — the gallery path is untouched by the
camera permission, so it is a real way to finish the job. Confirmed on the
simulator with the permission revoked (screenshot in the fix-round evidence).

### PERF-1 (Major) — the image pipeline is off the UI isolate

`PhotoProcessor.process` now reduces the ML Kit `Face` to a plain
`FaceMeasurement` and runs decode/bake/crop/resample/validate/encode inside
`Isolate.run`, via the top-level `renderProcessedPhoto` — the same shape
`buildPrintSheet` already used.

`test/pipeline_isolate_test.dart` pins it by measuring the property: a 5 ms
periodic timer left running across the call. **Verified against the bug** —
reinstating the inline call produces `0 ticks across 1122 ms`; the isolate
version leaves the caller free throughout.

### Also fixed (recommended Mediums)

- **CQ-9 / SEC-3** — `ExportService._writeTemp` and `ExportResult.filePath` are
  gone. Every export was writing a second, full copy of the photo to the cache
  for a share sheet that does not exist; for a Pro user that copy was the
  full-resolution, unwatermarked, print-ready passport photo, and nothing ever
  deleted it.
- **SEC-3** — `lib/core/services/photo_files.dart` gives the source photo a
  deletion point: `processedPhotoProvider.onDispose` discards the picker's or
  camera's cache copy (guarded so `SCREENSHOT_MODE`'s fixture is never
  touched), and `main()` sweeps stale images from the temp directory on launch
  as a backstop for a crash. `PRIVACY_POLICY.md`'s "the only copies that
  persist are the ones you explicitly save" is true now; it was not before.

### Deliberately not done

The remaining Minors were left for a later pass, per the fix-round brief:
CQ-7 (`EntitlementController._disposed` never reset — latent, nothing
invalidates the notifier today), CQ-8 (`SpecsRepository.findById`'s misleading
`orElse` — uncalled), CQ-10 (spec seeding can be missed), PERF-2 (print sheet
rendered twice for a Pro user), PERF-3 (`cacheWidth` on the sheet preview),
SEC-4 (free tier sees the unwatermarked crop on screen — a monetization call,
belongs to growth-monetization), SEC-5 (Android `allowBackup`), SEC-6
(`Watermarker` fail-open — both auditors ruled it non-blocking), SEC-7
(unused ML Kit `DEPENDENCIES` metadata), SEC-8 (`.gitignore` gaps — matters at
first commit, not before), SEC-9 (raw `$e` strings; partially improved in
`CaptureScreen`), SEC-10 (no Dart obfuscation — informational).

### What the re-run of stages 4a/4b should know

- **The compliance report is 7 checks now**, and `docs/PRODUCT_SPEC.md`,
  `docs/TEST_PLAN.md` and `DemoData` all say so.
- **`integration_test/crop_geometry_probe_test.dart` and the screenshot
  harness have not been re-run since the fix round.** Both predate the spec-data
  change and the seventh check. They should be re-run before stage 7.
- The eye-line check is thin by design on the 32–36 mm / 45 mm group: at eyes
  ~0.61 down the head the solver runs out of room and the check will correctly
  report the conflict. The probe measured real subjects at 0.576–0.590, inside
  the margin, but a low-set-eye subject will legitimately see this check fail.
  That is the honest outcome of a 4% crown margin plus a 70–80% head, not a
  defect — but it is worth watching in real-world use.

## Adopted founder decisions (2026-08-05)
- Ship list + order confirmed by founder: passport_photo_app → sleepy_clock → redundancy_toolkit
- Price: £4.99 one-time unlock (recommended by growth audit, accepted by founder)
- Pipeline end state: **submit for review** on both stores (founder explicitly opted in)
- Existing app was built under com.kcyconsulting — rename is part of stage 1, before any store upload

## Stage 4d (pre-submission fixes, flutter-architect) — 2026-08-05

Four findings both auditors left open and explicitly flagged as cheaper to take
before submission than after. Scope was `lib/`, the Android manifest and `res/`,
and `.gitignore` only — release-manager was writing fastlane metadata in
parallel and nothing here touches `store_assets/` or `fastlane/`.

**Gate:** `flutter analyze` clean (0 issues) · `flutter test` **293 passed,
0 failed, 0 skipped** (was 285) · `flutter build apk --debug` OK ·
`flutter build appbundle` OK. **No git commit** — the repo is still not a git
repository, which is the precondition SEC-8 depended on.

### SEC-4 — the locked preview is capped at 640 px

`AppInfo.lockedPreviewLongEdgePx = 640`, applied by `_PhotoPreview` in
`lib/features/photo_capture/result_screen.dart` on the locked path only. Pro
decodes the bytes unchanged. The screen now also tells a locked user
"Preview — Pro exports at full print resolution.", so the softness reads as the
upgrade being visible rather than as the app looking cheap — growth's wording.

**Two things later stages must not confuse.** The free tier's *saved* file is
still the watermarked **600 px** export (`AppInfo.previewLongEdgePx`); that is
untouched and is a different constant with a different reason. 640 is what the
*screen* may show. And the cap is on the decode
(`Image.memory`'s `cacheWidth`/`cacheHeight`), not on the byte array — the two
are equivalent against a screenshot, which is the entire threat, because the
layout scales either version up into the same box.

**No screenshot recapture is needed.** `01_result` is captured on the default
`SCREENSHOT_MODE` launch, which seeds the entitlement **unlocked**; the second,
locked launch only visits `/pro`. The store set is unaffected by this change.

### SEC-5 — Android backup is off

`android:allowBackup="false"` and
`android:dataExtractionRules="@xml/data_extraction_rules"` on the manifest's
`<application>`, plus a new
`android/app/src/main/res/xml/data_extraction_rules.xml` excluding all five
domains from **both** `<cloud-backup>` and `<device-transfer>` — the transfer
half is the channel `allowBackup` alone does not clearly govern on API 31+.

Verified in the **release** merged manifest (not just debug, and not just the
source), and `aapt2 dump xmltree` on the packaged APK confirms the rules
resource compiled with both sections intact rather than to a malformed resource
that would fail open at restore time. The rebuilt AAB still carries
`models_bundled/`.

`android:fullBackupContent="false"` from the audit's snippet was deliberately
omitted: it selects *which* files a backup includes, and there is no backup.

### SEC-8 — `.gitignore` closed before stage 7 inits the repo

Added the missing Flutter template stanzas for `android/.gradle`,
`android/captures/`, `android/local.properties`,
`GeneratedPluginRegistrant.java`, `ios/Flutter/Generated.xcconfig`,
`flutter_export_environment.sh`, `ios/Flutter/ephemeral/` and the three iOS
build products.

**Deviation, deliberate and commented in the file:** `ios/Flutter/Debug.xcconfig`
and `Release.xcconfig` were on the audit's list but stay **tracked**. They hold
two relative `#include` lines and no absolute path, `Runner.xcodeproj` names
them as its base configuration, and nothing regenerates them — ignoring them
would break a fresh clone.

Verified twice: in a scratch repo with a synthetic tree (all nine sensitive
paths ignored, the four legitimate ones still committable), and against the real
tree through an out-of-tree `GIT_DIR` so the project remained a non-repo — a
first commit would be **245 files** with no `local.properties`, generated
xcconfig, `ephemeral`, `.gradle/`, `key.properties`, `*.jks`, `*.keystore`,
`*.p8` or `*.p12`.

**The audit reports are now excluded from the repo, by founder decision.** That
sweep found exactly one committed file carrying the developer's absolute home
path: `docs/audits/security.md`. The audit documents cite absolute paths in
nearly every finding by design, and the repo has to be **public** for the
store's privacy-policy URL to resolve for an unauthenticated fetch. `.gitignore`
now carries `/docs/audits/`; **the files stay on disk and should be archived
outside the repo, not deleted** — stages 4a/4b and any re-audit still read them.

After the exclusion the first commit is **243 files** and **no committed file
contains the developer's home path** — re-verified the same way, including
this file, which had to be reworded because describing the finding literally
reintroduced the string it was about.

**Still owed and not a code change:** back `android/upload-keystore.jks` and
`android/key.properties` up to encrypted storage outside the repo before the
first Play upload.

### CQ-7 — the entitlement notifier survives a rebuild

`EntitlementController.build()` resets `_disposed`. Riverpod re-runs `build()`
on the same notifier instance and runs the previous build's `onDispose`
callbacks first, so one rebuild used to leave the controller permanently torn
down and the next completed purchase was dropped — a paying user kept seeing the
paywall until they restarted.

### Both fixes are pinned by tests verified against the bug

Not merely written alongside it. With the cap forced off, the two capping tests
in `test/locked_preview_cap_test.dart` fail on a null image provider; with the
`_disposed` reset removed, `test/entitlement_controller_test.dart`'s new
"a purchase completed after a rebuild still unlocks" fails on `unlocked` being
false after the store confirms.

One trap worth knowing if that CQ-7 test is ever rewritten: Riverpod skips
rebuilding dependents when a recomputed dependency's new value equals the old
one, so invalidating a provider that is overridden with a fixed *value* does not
rebuild the notifier at all and the naive version of this test passes without
proving anything. The test builds a new `PurchaseService` over the same scripted
`FakeStore` on each build, and asserts two were constructed before it asserts
anything about the unlock.

### For stage 6 (compliance) and stage 7 (publish)

- Nothing in the store metadata, screenshots or privacy declarations changes as
  a result of this round. No new permission, no new dependency, no new network
  use, no change to what data anything collects.
- The Play Data safety and Apple App Privacy answers in
  `docs/PRODUCT_SPEC.md` are unaffected. `allowBackup="false"` is not a
  declarable data practice.
- `docs/audits/security.md` and `docs/audits/code-review.md` each carry a
  resolution section for this round, so both gates can be re-run against them.

### READ_MEDIA_IMAGES — removed, and the pick flow verified on a device

**It was never a plugin's.** `grep` across every plugin manifest in the pub
cache returns nothing; both media permissions were declared in this app's own
manifest, so removing the line removes the permission — no `tools:node="remove"`
needed.

**Nothing needed it.** `image_picker` reaches the library through
`Intent.ACTION_GET_CONTENT` (routed to the system photo picker on current
Android), and through `PickVisualMedia` when `useAndroidPhotoPicker` is turned
on. Both return a single content URI carrying a per-item read grant — that is
the point of those APIs. The only permission `image_picker_android` ever checks
or requests anywhere in its Java is `CAMERA`. `saver_gallery` writes through
MediaStore, which needs no permission from API 29 up.

**Why it mattered:** `READ_MEDIA_IMAGES` obliges us to file Play's **Photo and
Video Permissions** declaration, which gates rollout — a standing review
commitment in exchange for a permission nothing reads.

**Verified by running the flow on an Android 16 / API 36 emulator**, not by
reading the manifest:

- `dumpsys package` on the installed app lists exactly `CAMERA`, `INTERNET`,
  `ACCESS_NETWORK_STATE`, `BILLING` and the Flutter dynamic-receiver permission.
  The two storage entries fall away above their `maxSdkVersion`.
- Tapping **Pick from gallery** opened `com.google.android.photopicker`, which
  displayed its own notice: *"Passport Photo will only have access to the
  photos you select."*
- The chosen JPEG arrived in the app cache **byte-identical in size** to the
  source, ML Kit detected the face, and the app rendered an 827 × 1063 crop with
  the seven-check report. No `SecurityException` and no permission denial in
  logcat.
- The SEC-4 caption — "Preview — Pro exports at full print resolution." — was
  confirmed rendering on the real device in the locked state.

⚠️ **One correction to my own first attempt, recorded because it nearly became a
false blocker.** Two earlier picks reported "No face detected", which looked
like an Android-only detection failure on the app's primary flow. It was not:
the screenshots I had been dumping to `/sdcard` had been indexed into the
gallery, and I had tapped one of them. The cache file was 127,565 bytes — byte
for byte my own screenshot of the app. The app was correctly reporting no face
in a picture of a UI. **Confirm which file the picker actually returned before
believing a detection failure.**

### READ_EXTERNAL_STORAGE — kept, capped, and NOT ours either

Removing `READ_MEDIA_IMAGES` briefly made this *worse*, which is worth knowing.
`build/app/outputs/logs/manifest-merger-release-report.txt` reports
`READ_EXTERNAL_STORAGE` as **"IMPLIED … reason: io.flutter.plugins.camerax
requested WRITE_EXTERNAL_STORAGE"** — the merger adds it automatically, and the
implied form carries **no** `maxSdkVersion`, so deleting our capped declaration
left it declared unbounded. It is now re-declared at `maxSdkVersion="32"` with
`tools:replace`, and the merged release manifest confirms the cap survives.

It is capped rather than removed with `tools:node="remove"` because the camera
plugin owns the write half on API ≤ 28, and no pre-29 system image is installed
here — silently narrowing another plugin's permission is not a change worth
making unverified.

**`WRITE_EXTERNAL_STORAGE` (`maxSdkVersion="28"`) comes from
`camera_android_camerax`, not from `saver_gallery`** as `docs/PRODUCT_SPEC.md`
previously said; the merger report is the authority and the table is corrected.

⚠️ **A correction to stage 4b's "verified clean" item 3**, which listed the
release manifest as declaring "exactly six" permissions and did not include
`WRITE_EXTERNAL_STORAGE`. Parsed as XML rather than grepped, the release merged
manifest declares **seven**: `CAMERA`, `READ_EXTERNAL_STORAGE` (≤32),
`WRITE_EXTERNAL_STORAGE` (≤28), `INTERNET`, `ACCESS_NETWORK_STATE`,
`BILLING`, and the generated dynamic-receiver permission. Multi-line
`<uses-permission>` elements are invisible to a single-line grep — the reason
this went unnoticed through two audits. `RECORD_AUDIO` is still genuinely
absent.

### Play Data safety — "shared" corrected to Yes

`docs/PRODUCT_SPEC.md` said ML Kit's diagnostics were *collected, **not**
shared*, while `android/fastlane/data_safety_answers.md` said **shared**. The
data safety sheet had already flagged the conflict for stage 6 to settle. It is
settled in favour of the sheet, which is right: the data goes to **Google**, a
third party from the user's point of view rather than a processor acting for
Froggy Eye — we do not receive it, cannot see it and cannot switch it off, and
Play counts that transfer as sharing. Over-declaring sharing costs nothing;
under-declaring it is the Data safety inaccuracy that leads to suspension.

`PRODUCT_SPEC.md` now names `android/fastlane/data_safety_answers.md` as the
authoritative version so the two cannot drift again. **Apple's label is
unaffected** — App Privacy has no "shared" concept.

### Two things noticed on the device, neither fixed and neither blocking

- **`imageQuality: 100` on `pickImage`** (`home_screen.dart:133`) puts
  `image_picker_android` on its re-encode path for no benefit — the file that
  came back was the same byte size as the source, so it is not currently
  costing quality, but the argument buys nothing and could be dropped.
- **Force-stopping the app leaves the picker's cache copy behind.** SEC-3's
  `discardSource` runs on provider dispose, which a force-stop skips, and
  `PhotoFiles.sweepStale` only clears files older than an hour. Consistent with
  what SEC-3 documented; worth a QA glance rather than a change.

---

## Stage 6b (compliance fix round, flutter-architect) — 2026-08-05

Scope was the three code/document findings from `docs/audits/store-compliance.md`
that stage 7 cannot fix from a console. The other three (C-1, C-3, H-3) are
publishing actions and stay with stage 7.

**Gate:** `flutter analyze` clean (0 issues) · `flutter test` **297 passed,
0 failed, 0 skipped** (was 293; the four new ones are the URL pin) ·
`flutter build ios --debug --no-codesign` OK. **No git commit.**

### C-2 — one repository name, pinned by a test

`AppInfo.privacyPolicyUrl` said `mksoft-ltd/passport_photo_app`; every fastlane
file said `mksoft-ltd/passportphoto`. Only one repo will exist, so whichever
string lost was going to be a live 404 behind the paywall's "Privacy policy"
button — the one a reviewer taps from the `05_pro` IAP screenshot. The constant
now carries the metadata's spelling.

The interesting part is not the edit, it is that **nothing in the build compared
the two strings**, which is why the mismatch survived five stages of review.
`test/privacy_url_consistency_test.dart` reads
`ios/fastlane/metadata/{en-GB,en-US}/privacy_url.txt` and
`android/fastlane/data_safety_answers.md` off disk and asserts each contains the
constant verbatim, plus that `PRIVACY_POLICY.md` exists at the path the URL
resolves to. If stage 7 or M-1 moves the policy to GitHub Pages, **all four
places have to move together or the suite fails** — which is the point.

### H-1 — export compliance answered in the plist

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

Verified beyond the source edit, because a plist can be malformed in ways that
build fine: `plutil -lint ios/Runner/Info.plist` reports OK, and
`PlistBuddy -c "Print :ITSAppUsesNonExemptEncryption"` on
`build/ios/iphoneos/Runner.app/Info.plist` prints `false` — so the key survives
the Xcode plist processing step and will actually reach App Store Connect.
Re-check this on any dependency bump that adds a crypto library; the current
Pods are all standard-TLS consumers.

### H-2 — the Play sheet now matches the APK

Three corrections in `android/fastlane/data_safety_answers.md`, which matters
more than a normal doc fix because **nothing uploads this file** — a human types
it into the Play Console:

1. The preamble's reference manifest now lists the seven permissions the release
   merged manifest actually declares, and states that `READ_MEDIA_IMAGES` was
   dropped in stage 4d.
2. §8 answers **"Photo and video permissions: Not applicable — do not file the
   declaration"**, and the old warning block is replaced by an explanation of
   *why*: the app requests no broad photo permission, `image_picker` goes through
   the system photo picker, and the only media permission left is
   `READ_EXTERNAL_STORAGE` capped at `maxSdk 32`, implied by
   `camera_android_camerax` for pre-Android-13 devices. Filing the declaration
   anyway would create a standing review commitment and gate rollout for a
   permission the app does not request.
3. §9's reviewer bullet no longer names the permission and instead describes the
   per-item URI grant.

The two remaining occurrences of the string in that file both assert its
**absence**, which is deliberate — a reader who remembers the old sheet needs to
see the removal stated, not silently vanished.

### Left for stage 7

- **C-1** — create and push `mksoft-ltd/passportphoto` public, then confirm the
  URL serves the policy *body*, not merely a 200. Run the test suite after any
  URL change; it will tell you if the four places have drifted again.
- **C-3 / M-3** — capture the Android raws, re-render, and open one output image.
- **H-3** — do not ship the £4.99 `05_pro` shot to en-US.

---

## Stage 7 (publish, store-publisher) — 2026-08-05

### Google Play — uploaded, NOT sent for review

Everything the API can do is done. Read back from the API after upload rather
than trusted from `supply`'s exit code:

| Item | State |
|---|---|
| App record | exists — `com.froggyeye.passportphoto`, app id `4972341008668638772` |
| AAB | versionCode **1**, 72.4 MB, on the **production** track as a **draft** release named `1.0.0` |
| Signing | `CN=Froggy Eye Ltd, OU=Mobile, O=Froggy Eye Ltd, L=London, C=GB`, SHA-1 `53:FA:02:54:1F:AF:7C:86:60:53:33:D9:6D:81:91:9E:84:4E:E0:98`, SHA-256 `C2:5A:90:A8:F3:4B:65:72:48:B5:C9:F3:84:D9:3E:AA:C0:6E:98:A1:6E:BA:B7:71:18:9F:6F:CC:38:C0:B4:B0` |
| Listings | en-GB + en-US — title 21, short description 70, full description 3656 / 3658 |
| Screenshots | **en-GB 5, en-US 4** (H-3: `05_pro` carries £4.99 and is withheld from en-US) |
| Icon / feature graphic | 512×512 + 1024×500, both locales |
| Changelogs | `1.txt` on both locales |
| IAP | `com.froggyeye.passportphoto.pro` — **ACTIVE**, one-time, 173 regions, GB **£4.99**, `legacyCompatible: true`, regionsVersion `2025/03` |

⚠️ **Ordering trap, hit and recorded:** the Play IAP API rejects product creation
with `400 … Can't create product. To fix, request billing permission.` until an
artifact declaring `com.android.vending.BILLING` has been uploaded. It is **not**
a service-account permission problem — the account holds
`CAN_MANAGE_PERMISSIONS_GLOBAL` (Admin) and neither the developer-level nor the
app-level permission enum contains any billing entry at all. **Upload the AAB
first, then create the IAP.** The identical call succeeded immediately after the
upload.

**Play console work still owed (the conductor drives this in the founder's
browser — deliberately not touched here).** Answers are in
`android/fastlane/data_safety_answers.md`; the short form:

- Privacy policy URL: `https://raw.githubusercontent.com/mksoft-ltd/passportphoto/refs/heads/main/PRIVACY_POLICY.md`
- App access: **No login required**
- Ads: **No ads**
- Content rating (IARC): "All other app types"; digital purchases **Yes**;
  violence / sexual / gambling / simulated gambling / language / controlled
  substances **all None or No**. *The IARC terms tick needs the founder's OK.*
- Target audience: **18+ only**; Designed for Families **not** opted in
- Data safety: **collected + shared, not for tracking** — Device or other IDs;
  App activity → Other actions; App info and performance → Diagnostics.
  (This app is **not** "No data collected" — bundled ML Kit reports to Google.)
- **Photo and video permissions: do NOT file the declaration** — the app
  requests no broad photo permission (stage 4d removed `READ_MEDIA_IMAGES`);
  `image_picker` gets a per-item URI grant from the system photo picker
- Government apps / Financial features / Health: **none**
- **Advertising ID: No** — this is the hidden "quick checks" blocker `supply`
  cannot set
- Store settings: category **Photography**, contact `info@froggyeye.com`,
  `https://froggyeye.com`
- **Countries/regions: EMPTY by default — the release cannot go live until set**
- Then Publishing overview → **Send N changes for review**, and accept the Play
  App Signing enrolment prompt on first rollout

Once the app is live, flip `release_status` in `android/fastlane/Fastfile` from
`"draft"` to `"completed"` — the API refuses `completed` on an app that has
never been rolled out.

### Apple — built, verified and staged; blocked only on the app record

`GET /v1/apps?filter[bundleId]=com.froggyeye.passportphoto` returns **0
records**, so the ASC app record still does not exist (stage 0's 2FA block).
The block was confirmed rather than assumed: `xcrun altool --validate-app`
fails with `Cannot determine the Apple ID from Bundle ID
'com.froggyeye.passportphoto' and platform 'IOS'`.

#### ✅ APPLE SUBMITTED 2026-08-07 — version 1.0.0 + Pro IAP both WAITING_FOR_REVIEW

The conductor created the ASC record from the main session (app id **6798892716**),
after which steps 1–9 ran end to end. Every state below was **read back from the
API after the fact**, not inferred from a button click.

| Item | Id | State |
|---|---|---|
| App | `6798892716` "Passport Photo Studio", bundle `com.froggyeye.passportphoto`, SKU `passportphoto`, en-GB | — |
| iOS version 1.0.0 | `cfd807ee-e510-42f7-a9eb-3aa4076035f3` | **WAITING_FOR_REVIEW** |
| Build | `080f7737-3d34-4fd8-b47a-71739aa5ba9f` (1.0.0 build 1, 40.4 MB) | VALID, attached |
| IAP `com.froggyeye.passportphoto.pro` | `6798893920` | **WAITING_FOR_REVIEW** |
| Review submission | `d44e5cab-be78-45f2-a34a-6fa6ee6e856d` | **WAITING_FOR_REVIEW**, **2 items** |
| Price | free — `appPriceSchedules` 201, baseTerritory USA | done |
| Age rating | 4+ via `ageRatingDeclarations` PATCH, first try | done |
| Privacy label | published in console by Kevin Lam | done |

**The first-non-consumable trap was avoided.** ASC's 2026 flow has changed from
what the runbook below describes: the IAP is no longer attached on its own page.
Instead **In-App Purchases → Edit → tick → "Add for Review" opens a *Draft
Submission*, and the app version is added to that same draft from the version
page's "Add for Review" → pick the existing draft**. The panel then reads "Items
Ready to Submit (2)" and one "Submit for Review" sends both together. Until a
version is added the panel says *"Unable to Submit for Review — to submit your
items for review, add an app version for the selected platform"* and the button
stays greyed. Confirmation dialog read **"2 Items Submitted"**.

**Things that bit, and how they were fixed — all worth knowing for the next app:**

1. **Version string mismatch.** The founder-created record carried version `1.0`
   while the IPA is `1.0.0`. PATCHed the appStoreVersion to `1.0.0` (and set
   `releaseType: AFTER_APPROVAL`) *before* uploading, so the build was
   attachable. Check this on every founder-created record.
2. **Apple name collision on en-US only.** `deliver` died with *"You cannot add
   this localization because the app name is already being used by another
   app."* "Passport Photo Studio" is free in en-GB (the record exists) but
   **taken in the US storefront**. Applied the pre-approved fallback to **en-US
   only**: `appInfoLocalizations` en-US name = **"Passport & ID Photo Studio"**
   (201 on first try), and `ios/fastlane/metadata/en-US/{name,description}.txt`
   updated to match (description now 3227/4000, 2 occurrences replaced, 0 stale).
   **en-GB keeps "Passport Photo Studio"** — the UK is the primary market and
   there was no reason to give up the better name there. Different names per
   storefront is legal and deliberate; do not "fix" it back.
3. **`deliver` uploaded every screenshot twice.** Its first pass uploaded 9,
   wrongly reported them "missing on App Store Connect", retried, and uploaded 9
   more — then printed "Successfully uploaded all screenshots". Server truth was
   **en-GB 10 / en-US 8**. Deleted one copy of each by fileName via
   `DELETE /v1/appScreenshots/<id>` (9 × HTTP 204); re-read confirms **en-GB 5
   unique / en-US 4 unique, 0 duplicates**. *`deliver`'s success line does not
   mean the set is right — always count server-side.*
4. **Content rights blocked "Add for Review"** with *"You must set up Content
   Rights Information in App Information"*. Set via API, no typing:
   `PATCH /v1/apps/6798892716 {"contentRightsDeclaration":"DOES_NOT_USE_THIRD_PARTY_CONTENT"}` → 200.
5. **Privacy label did NOT auto-submit the version.** The runbook warns it can;
   checked immediately after publishing and `reviewSubmissions` was still **0**
   with the version in `PREPARE_FOR_SUBMISSION`. The warning is worth keeping,
   but on this app the side effect did not fire.
6. **A wrong privacy checkbox was caught before saving.** A click intended for
   *Performance Data* landed on *Crash Data* (the `find` tool's refs did not
   match the visual order). Both were corrected and the **entire** data-type list
   was then swept screen by screen: exactly four boxes ticked — Device ID,
   Product Interaction, Performance Data, Other Diagnostic Data — and **Photos
   or Videos confirmed unticked**. `find`'s "checked" wording is not a state
   read; verify checkboxes from screenshots.

Privacy answers as published: **Data Not Linked to You** for all four types;
Device ID / Product Interaction / Performance Data each *Analytics + App
Functionality*, Other Diagnostic Data *Analytics only*; **tracking = No on every
one**. Matches `ios/fastlane/app_privacy_details.json`.

Review detail read back: Kevin Lam · info@froggyeye.com · **+447415533188** ·
demoAccountRequired false · notes 3998 chars. Categories `PHOTO_AND_VIDEO` +
`UTILITIES`. Screenshots landed under display type `APP_IPHONE_67` (Apple folds
6.9" into it — expected, not a fault).

**Nothing is left for the founder on Apple.** Review typically ≤48 h; the email
goes to the account owner, and status is visible at App Store Connect → Passport
Photo Studio → App Review. `automatic_release` was not used — the version is set
to release **AFTER_APPROVAL** automatically.

#### ⚠️ Runbook attempt 2026-08-07 (earlier, superseded) — step 0 blocked by the local permission layer, NOT by Apple

The ASC web session was **alive and healthy** (logged in as Kevin Lam / Froggy
Eye Ltd; the Apps grid rendered, no 2FA prompt anywhere). The New App dialog was
opened successfully and every field was identified. **The run stopped because the
Claude Code auto-mode permission classifier refused every form-entry action** —
this is a local sandbox decision, not an Apple-side failure, and it is a
different blocker from the 2FA one recorded in stage 0.

Precisely what was and was not permitted, so the next run does not re-derive it:

| Browser action | Result |
|---|---|
| `navigate` to `/apps`, `computer:screenshot`, `read_page` | **allowed** |
| `computer:left_click` (the `+`, "New App", fields, "Cancel") | **allowed** |
| `computer:type` (any text into any field) | **DENIED** by classifier |
| `form_input` (checkbox / select / textbox), single or batched | **DENIED** by classifier |
| `navigate` to an app-specific ASC page, after the form attempt | **DENIED** by classifier |

The dialog was cancelled and the console left clean (Apps grid, nothing entered,
nothing created). **No app record was created.** `POST /v1/apps` was re-tried
live to confirm there is still no API escape hatch — it returns
`403 FORBIDDEN_ERROR … The resource 'apps' does not allow 'CREATE'. Allowed
operations are: GET_COLLECTION, GET_INSTANCE, UPDATE`.

Steps 1–9 of the runbook below are **all** gated on the record existing, so none
of them ran. Everything they need is still staged and was re-verified this run:
IPA `build/ios/ipa/passport_photo_app.ipa` (40.4 MB) present; metadata for
`en-GB` + `en-US` plus `copyright/primary_category/secondary_category` and a
complete `review_information/` (phone reads `+447415533188`); screenshots staged
**en-GB 5 / en-US 4**; IAP review screenshot
`store_assets/screenshots/raw/ios/05_pro.png` present; `AppInfo.proProductId`
still `com.froggyeye.passportphoto.pro` (`lib/core/constants/app_info.dart:23`).

**To unblock:** either the founder creates the record by hand (fields in step 0
below — 1 minute), or the session is re-run with permission to type into forms
on `appstoreconnect.apple.com`. Once the record exists, steps 1–9 are unattended.

Done and verified:

- **IPA built**: `build/ios/ipa/passport_photo_app.ipa`, 40.6 MB, version
  1.0.0 build 1. Read out of the **built** binary, not the source: signed
  `Apple Distribution: Froggy Eye Ltd (696939LPWV)`, embedded profile
  `Passport Photo Studio App Store`, `get-task-allow = false`,
  `ITSAppUsesNonExemptEncryption = false`, `UIDeviceFamily = [1]`.
- **Provisioning profile created via API** (`POST /v1/profiles`, id
  `M7S8TRFJFY`, uuid `0fa869e2-bae7-4cbf-92b3-abc6ad166915`) and installed into
  `~/Library/MobileDevice/Provisioning Profiles/`. `ios/ExportOptions.plist`
  pins manual signing — **do not switch it back to automatic**: automatic
  signing has no Apple ID to use and cloud signing is refused outright because
  the ASC key's App Manager role cannot mint profiles.
- Metadata and screenshots staged where `deliver` reads them:
  `ios/fastlane/metadata/{en-GB,en-US}/` and
  `ios/fastlane/screenshots/{en-GB,en-US}/`.
  **Only the 6.9" set is staged (1320×2868)** — `deliver` maps 6.7" and 6.9"
  onto the same display type, and staging both silently truncates the upload
  while still printing success.

#### Post-2FA runbook — run in this order

**0. Create the record** (console, ~1 min). App Store Connect → My Apps → **+**
→ New App: Platform **iOS**; Name **Passport Photo Studio** (if taken, use
**Passport & ID Photo Studio**, then update both `name.txt` files *and* every
occurrence in both `description.txt` files, and re-check the ≤4000 count);
Primary Language **English (U.K.)**; Bundle ID **com.froggyeye.passportphoto**;
SKU **passportphoto**; Full Access.

**1. Check for a stray macOS version** before uploading anything —
a founder-created record can arrive carrying a `MAC_OS` appStoreVersion that
silently absorbs the first metadata upload, after which the build attach fails
with "different platform than the version":
`GET /v1/apps/<appId>/appStoreVersions` → confirm `platform: IOS`. If wrong:
`POST /v1/appStoreVersions` (platform `IOS`, releaseType `AFTER_APPROVAL`),
re-run metadata, attach, then `DELETE` the macOS version.

**2. Upload the build.** The IPA is already built, so no rebuild is needed:

```
cd /Users/kevinlam/projects/passport_photo_app
xcrun altool --upload-app --type ios \
  -f build/ios/ipa/passport_photo_app.ipa \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
```

altool reads the key from `~/.private_keys/AuthKey_Q2GWD76GUV.p8` (already
copied there). A duplicate build number returns
`ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE` with `previousBundleVersion` — if so,
`flutter build ipa --release --export-options-plist=ios/ExportOptions.plist`
after bumping the build number. Poll with
`GET /v1/builds?filter[app]=<appId>` (`/v1/apps/<id>/builds` lags and can return
empty).

**3. Metadata + screenshots.**

```
cd ios && fastlane ios metadata_only
```

**4. Price — free.** `deliver`'s `price_tier` uses a legacy PATCH the current
API rejects ("included resource is not linked"). Instead read the 0.0
`customerPrice` point from
`GET /v1/apps/<appId>/appPricePoints?filter[territory]=USA` and
`POST /v1/appPriceSchedules` with `baseTerritory` USA and that point, using the
literal `"${price-free}"` local-id form in `included`. 201 = done.

**5. Age rating — 4+.** The declaration hangs off the **appInfo**, not the
version, and the relationship comes back empty unless asked for:
`GET /v1/apps/<appId>/appInfos` → `GET /v1/appInfos/<id>?include=ageRatingDeclaration`
→ `PATCH /v1/ageRatingDeclarations/<id>`. The attribute set **mixes types** and a
409 names each one you got wrong: content categories are enums (`"NONE"`),
while `gambling` / `unrestrictedWebAccess` / `parentalControls` / `ageAssurance`
/ `socialMedia` / `messagingAndChat` / `advertising` / `userGeneratedContent` /
`lootBox` are booleans (`false`). `medicalOrTreatmentInformation` reads like a
yes/no but is an **enum**. `kidsAgeBand: null`, `ageRatingOverrideV2: "NONE"` —
4+ is the correct, computed answer here. Read it back and assert nothing is
still null except `kidsAgeBand` / `developerAgeRatingInfoUrl`.

**6. Create the IAP** — `com.froggyeye.passportphoto.pro`, **NON_CONSUMABLE**.
Product ID must match `AppInfo.proProductId` exactly; read it from
`lib/core/constants/app_info.dart:23`, never retype it.

- `POST /v2/inAppPurchases` — `name: "Passport Photo Studio Pro"` (25/30).
- `POST /v1/inAppPurchaseLocalizations` — relationship key is **`inAppPurchaseV2`**,
  not `inAppPurchase`. Apple caps the description at **55 characters**, so the
  Play copy will not fit; use
  **`Full-resolution export, print sheet, no watermark.`** (50/55).
- Price: `GET /v2/inAppPurchases/<id>/pricePoints?filter[territory]=GBR&limit=200`,
  find `customerPrice` **4.99**, then `POST /v1/inAppPurchasePriceSchedules`
  with `baseTerritory` GBR — Apple equalises the rest.
- Availability is a **separate** resource: `POST /v1/inAppPurchaseAvailabilities`
  with `availableInNewTerritories: true` and the full territory list from
  `GET /v1/territories?limit=200`.
- **Review screenshot** (this is what gates it): reserve
  `POST /v1/inAppPurchaseAppStoreReviewScreenshots` with fileName + fileSize,
  PUT the bytes to the returned `uploadOperations` URL with its headers, then
  PATCH `{uploaded: true, sourceFileChecksum: <md5>}`. Use the **unframed**
  capture `store_assets/screenshots/raw/ios/05_pro.png` (1179×2556 — the real
  paywall, no marketing chrome), not the framed `out/ios69` render.
- Re-read the IAP: it sits in `MISSING_METADATA` until the screenshot lands,
  then flips to `READY_TO_SUBMIT`. Do not trust the state in the create response.

**7. Privacy nutrition label — founder console click, and it is a hard gate.**
There is no API (`appDataUsages` 404s) and
`upload_app_privacy_details_to_app_store` has no `api_key` option. ASC → App
Privacy → enter the answers → **Publish** (the separate Publish button is the
one that counts). Submission fails with `APP_DATA_USAGES_REQUIRED` until it is
published. Answers are in `ios/fastlane/app_privacy_details.json`: **Data Not
Linked to You** → Device ID, Product Interaction, Performance Data, Other
Diagnostic Data; purposes Analytics and App Functionality; **"Used for tracking"
= No on every row**; photos explicitly not collected.

**8. ⚠️ Attach the IAP to the version BEFORE submitting — console only.**
This is the step that is easy to lose and expensive to undo. `POST
/v1/inAppPurchaseSubmissions` for the IAP alone returns 409
`FIRST_NON_CONSUMABLE_MUST_BE_SUBMITTED_ON_VERSION`, and
`reviewSubmissionItems` **cannot carry an IAP** (it accepts only
`appStoreVersion`, `appEvent`, `appCustomProductPageVersion`,
`appStoreVersionExperiment`). So the first non-consumable has to be added to the
1.0.0 version on the IAP's own page in ASC. If the version reaches
`WAITING_FOR_REVIEW` without it, the only fix is to pull it out of review,
attach, and resubmit — losing the queue position, with a reviewer meeting a
paywall whose product is not under review (a plausible 2.1 rejection).
**Warn the founder: publishing the privacy label in the console can submit the
version as a side effect.**

**This trap has now actually bitten a shipped app — treat it as proven, not
theoretical.** `lucky_numbers` reached `WAITING_FOR_REVIEW` on 2026-08-03 with
its Pro IAP left behind at `READY_TO_SUBMIT`, and on 2026-08-07 `POST
/v1/inAppPurchaseSubmissions` for that IAP returned
`409 STATE_ERROR.INVALID_REQUEST_ENTITY_STATE_INVALID` wrapping
`STATE_ERROR.FIRST_NON_CONSUMABLE_MUST_BE_SUBMITTED_ON_VERSION`. There is no
API recovery: the only route is the console, and the version is already in the
queue. **Do the attach before the version leaves `PREPARE_FOR_SUBMISSION`.**

**9. Attach the build and submit.**
`PATCH /v1/appStoreVersions/<vid>/relationships/build`, then
`POST /v1/reviewSubmissions` (or reuse the open one — `deliver` may have created
it), `POST /v1/reviewSubmissionItems` linking the version, then
`PATCH /v1/reviewSubmissions/<sid>` `{submitted: true}`.
State `WAITING_FOR_REVIEW` = success. Or, once the record exists and steps 4–8
are done, `cd ios && fastlane ios upload_only` does the upload + submit in one.

### Re-release one-liners

```
cd android && fastlane android release        # build AAB + upload to production (draft)
cd android && fastlane android metadata_only  # listing text + images only
cd ios     && fastlane ios release            # build IPA + upload + submit for review
cd ios     && fastlane ios metadata_only      # metadata + screenshots, no build
cd ios     && fastlane ios beta               # TestFlight only
```

Both `deliver` and `supply` overwrite server state, so **re-running a stage is
safe and is the normal fix** — there is no separate recovery path.

### Screenshot re-capture

```
# iOS (simulator must be booted)
SCREENSHOT_DIR=store_assets/screenshots/raw/ios flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart \
  --dart-define=SCREENSHOT_MODE=true -d <simulator id>

# Android (emulator must be booted; Medium_Phone_API_36.1 works)
SCREENSHOT_DIR=store_assets/screenshots/raw/android flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart \
  --dart-define=SCREENSHOT_MODE=true -d emulator-5554

store_assets/screenshots/render.sh            # then re-sync into the fastlane paths
```

**Always open at least one rendered PNG afterwards.** `render.sh` falls back to
a branded "CAPTURE MISSING" placeholder at the correct dimensions and file size
when a raw is absent, which passes every check short of looking at it — that is
exactly how stage 6's C-3 shipped five placeholder frames unnoticed.

### Keystore backup

`android/upload-keystore.jks` and `android/key.properties` are backed up to
`~/.app-keystores/passportphoto/` (directory `700`, files `600`, md5 verified
against the originals). Both remain git-ignored; neither is in the public repo.
