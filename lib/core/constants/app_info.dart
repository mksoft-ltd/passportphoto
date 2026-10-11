import 'package:flutter/foundation.dart';

/// The identity strings that also appear in store metadata, fastlane files and
/// the privacy policy. Keep them in sync from here.
class AppInfo {
  const AppInfo._();

  static const String appName = 'Passport Photo Studio';
  static const String publisher = 'Froggy Eye Ltd';
  static const String copyright = '© 2026 Froggy Eye Ltd';

  static const String supportUrl = 'https://froggyeye.com';
  /// Must stay byte-identical to `ios/fastlane/metadata/{en-GB,en-US}/privacy_url.txt`
  /// and §1 of `android/fastlane/data_safety_answers.md`, or the paywall's
  /// "Privacy policy" button and the store listings point at different pages.
  /// Hosted on the publisher's own domain (Froggy Eye Ltd), rendered verbatim
  /// from `PRIVACY_POLICY.md` in this repo. Pinned by
  /// `test/privacy_url_consistency_test.dart`.
  static const String privacyPolicyUrl =
      'https://passportphoto.froggyeye.com/privacy.html';

  /// One-time non-consumable unlock. Must match the product created in App
  /// Store Connect and the Play Console.
  ///
  /// The stores use different ids. Play keeps the original `.pro`; the App
  /// Store record was recreated in Oct 2026 and Apple never releases a
  /// product id once used, even by a deleted app, so iOS sells `.pro2`.
  static String get proProductId =>
      defaultTargetPlatform == TargetPlatform.iOS ? iosProProductId : androidProProductId;

  static const String androidProProductId = 'com.froggyeye.passportphoto.pro';
  static const String iosProProductId = 'com.froggyeye.passportphoto.pro2';

  static const String proDisplayName = 'Passport Photo Studio Pro';

  /// App Store Connect's Apple ID for the app record created in Oct 2026
  /// (the earlier record was deleted). Only used to open the listing from
  /// "Rate the app"; Android finds its listing from the package name.
  static const String appStoreId = '6821667025';

  /// Long edge, in pixels, of the free tier's watermarked preview export.
  /// Big enough to prove the crop is right, too small to print.
  static const int previewLongEdgePx = 600;

  /// Long edge, in pixels, that the locked result screen is allowed to *decode*
  /// and therefore to show.
  ///
  /// Without this the free tier rendered the finished, unwatermarked crop at
  /// full print resolution — for the UK spec that is 827 × 1063 px against a
  /// preview box of roughly 1035 × 1332 device pixels, so every pixel of the
  /// paid artefact was on screen and one screenshot away. That matters because
  /// UK renewals and the US online application are now overwhelmingly digital
  /// uploads: an uploading user needs no printable file, only enough pixels,
  /// and the 600 px watermarked save the paywall offers them is *smaller* than
  /// what the preview was already giving away.
  ///
  /// 640 sits below both digital-upload minimums (UK 600 × 750, US 600 × 600)
  /// while keeping the crop and the framing plainly readable, which is what the
  /// free tier is actually for. Pro is unaffected and still displays the full
  /// resolution bytes.
  static const int lockedPreviewLongEdgePx = 640;

  /// Screenshot harness: `flutter run --dart-define=SCREENSHOT_MODE=true`
  /// seeds a finished UK passport photo, all checks green, and Pro unlocked.
  ///
  /// The `!kReleaseMode` term is load-bearing, not defensive. Seeding also
  /// grants the paid unlock, so without it a release build made with the define
  /// set would give the in-app purchase away. Both operands are compile-time
  /// constants, so a release build folds this to `false` and tree-shakes every
  /// seeding branch behind it; debug and profile — which is what `flutter
  /// drive` uses — are unaffected.
  ///
  /// Guarded by `test/screenshot_mode_release_guard_test.dart`.
  static const bool screenshotMode =
      !kReleaseMode && bool.fromEnvironment('SCREENSHOT_MODE', defaultValue: false);
}
