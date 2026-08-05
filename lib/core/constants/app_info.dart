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
  /// and §1 of `android/fastlane/data_safety_answers.md`. Only one of the two
  /// repository names can be pushed, so a mismatch leaves a live 404 behind the
  /// paywall's "Privacy policy" button. Pinned by
  /// `test/privacy_url_consistency_test.dart`.
  static const String privacyPolicyUrl =
      'https://raw.githubusercontent.com/mksoft-ltd/passportphoto/refs/heads/main/PRIVACY_POLICY.md';

  /// One-time non-consumable unlock. Must match the product created in App
  /// Store Connect and the Play Console.
  static const String proProductId = 'com.froggyeye.passportphoto.pro';

  static const String proDisplayName = 'Passport Photo Studio Pro';

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
