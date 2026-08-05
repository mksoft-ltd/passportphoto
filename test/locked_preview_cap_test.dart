import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:passport_photo_app/app/theme.dart';
import 'package:passport_photo_app/core/constants/app_info.dart';
import 'package:passport_photo_app/core/models/photo_spec.dart';
import 'package:passport_photo_app/core/services/preferences.dart';
import 'package:passport_photo_app/features/photo_capture/result_screen.dart';
import 'package:passport_photo_app/features/processing/processed_photo.dart';
import 'package:passport_photo_app/features/processing/processing_providers.dart';
import 'package:passport_photo_app/features/purchase/entitlement_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/specs.dart';

/// SEC-4: how much of the paid artefact the review screen is allowed to show a
/// user who has not paid for it.
///
/// The free tier used to render the finished, unwatermarked crop at full print
/// resolution — for the UK spec that is 827 x 1063 px inside a preview box of
/// roughly 1035 x 1332 device pixels, so every pixel of the £4.99 file was on
/// screen. That is not a print problem, it is an upload problem: UK renewals
/// and the US online application both accept a JPEG, neither checks the
/// photo's physical dimensions, and a cropped screenshot cleared both minimums
/// comfortably. The watermarked 600 px save the paywall offered in exchange was
/// *smaller* than what the preview was already giving away.
///
/// These tests pin the cap itself rather than the constant's value, except for
/// the one test that asserts the number, because the number is the finding.
void main() {
  const sourcePath = 'demo';

  /// Real JPEG bytes at [width] x [height], so the widget's decode is exercised
  /// rather than stubbed. The cap is read off the widget's image provider, not
  /// off the decoded frame, so nothing here waits on the codec.
  Uint8List jpeg(int width, int height) => Uint8List.fromList(
        img.encodeJpg(img.Image(width: width, height: height), quality: 60),
      );

  ProcessedPhoto photoFor(PhotoSpec spec) => ProcessedPhoto(
        spec: spec,
        jpegBytes: jpeg(spec.widthPx, spec.heightPx),
        widthPx: spec.widthPx,
        heightPx: spec.heightPx,
        checks: const [
          ValidationCheck(
            label: 'Face size within spec',
            passed: true,
            detail: 'Head is 31.2 mm tall (spec: 29-34 mm).',
          ),
        ],
      );

  Future<void> pumpResult(
    WidgetTester tester,
    ProcessedPhoto photo, {
    required bool unlocked,
  }) async {
    tester.view.physicalSize = const Size(393, 852) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          entitlementProvider
              .overrideWith(() => _FixedEntitlement(unlocked: unlocked)),
          processedPhotoProvider(sourcePath).overrideWith((ref) => photo),
        ],
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const ResultScreen(sourcePath: sourcePath),
        ),
      ),
    );
    await tester.pump();
  }

  /// The image provider the preview actually hands to the engine. A
  /// [ResizeImage] is the cap; a bare provider is the full-resolution decode.
  ResizeImage? capOn(WidgetTester tester) {
    final image = tester.widget<Image>(find.byType(Image).first);
    return image.image is ResizeImage ? image.image as ResizeImage : null;
  }

  group('locked preview', () {
    testWidgets('caps a portrait spec at 640 px on the long edge',
        (tester) async {
      final spec = PhotoSpec.fromJson(ukPassportJson);
      // Guards the premise: if this stops being bigger than the cap, the test
      // below would pass for the wrong reason.
      expect(spec.heightPx, greaterThan(AppInfo.lockedPreviewLongEdgePx));

      await pumpResult(tester, photoFor(spec), unlocked: false);

      final cap = capOn(tester);
      expect(cap, isNotNull, reason: 'the locked preview must be downscaled');
      expect(cap!.height, 640);
      // Only the long edge is constrained; the short edge follows from the
      // aspect ratio instead of being stretched to meet a second number.
      expect(cap.width, isNull);
    });

    testWidgets('caps the width when the photo is wider than it is tall',
        (tester) async {
      // No bundled spec is landscape today. The cap is written in terms of the
      // long edge rather than "the height" so that adding one cannot silently
      // turn the cap into an upscale, and this is what holds that.
      final landscape = PhotoSpec.fromJson({
        ...ukPassportJson,
        'id': 'landscape_fixture',
        'widthMm': 45.0,
        'heightMm': 35.0,
      });
      await pumpResult(tester, photoFor(landscape), unlocked: false);

      final cap = capOn(tester);
      expect(cap, isNotNull);
      expect(cap!.width, 640);
      expect(cap.height, isNull);
    });

    testWidgets('leaves a photo that is already under the cap alone',
        (tester) async {
      // The US 2x2 inch spec at 300 dpi is 602 px square — below the cap, so
      // capping it would mean re-encoding for nothing.
      final spec = PhotoSpec.fromJson(usPassportJson);
      expect(spec.widthPx, lessThan(AppInfo.lockedPreviewLongEdgePx));

      await pumpResult(tester, photoFor(spec), unlocked: false);
      expect(capOn(tester), isNull);
    });

    testWidgets('says why the preview is soft', (tester) async {
      await pumpResult(tester, photoFor(PhotoSpec.fromJson(ukPassportJson)),
          unlocked: false);
      expect(
        find.text('Preview — Pro exports at full print resolution.'),
        findsOneWidget,
      );
    });
  });

  group('Pro', () {
    testWidgets('sees the full-resolution decode', (tester) async {
      await pumpResult(tester, photoFor(PhotoSpec.fromJson(ukPassportJson)),
          unlocked: true);

      expect(capOn(tester), isNull,
          reason: 'a paid user must not be shown a downscaled preview');
      expect(
        tester.widget<Image>(find.byType(Image).first).image,
        isA<MemoryImage>(),
      );
    });

    testWidgets('is not told its preview is a preview', (tester) async {
      await pumpResult(tester, photoFor(PhotoSpec.fromJson(ukPassportJson)),
          unlocked: true);
      expect(
        find.text('Preview — Pro exports at full print resolution.'),
        findsNothing,
      );
    });
  });

  test('the cap sits below both digital-upload minimums it exists to defeat',
      () {
    // UK digital passport upload: 600 x 750 px minimum. US online DS-160
    // upload: 600 x 600 px. A capped preview cannot satisfy either, which is
    // the whole point — the free tier proves the crop, Pro sells the file.
    expect(AppInfo.lockedPreviewLongEdgePx, lessThan(750));
    expect(AppInfo.lockedPreviewLongEdgePx, 640);
  });
}

class _FixedEntitlement extends EntitlementController {
  _FixedEntitlement({required this.unlocked});

  final bool unlocked;

  @override
  EntitlementState build() => EntitlementState(unlocked: unlocked);
}
