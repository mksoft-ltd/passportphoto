/// The print-sheet preview has to follow the entitlement.
///
/// `/sheet` is the one screen where a locked user is shown the paid artefact
/// on purpose — watermarked, so the upsell is concrete rather than abstract —
/// and its own save button is what pushes `/pro`. So buying Pro *from this
/// screen* and coming straight back to it is the ordinary path, not an edge
/// case.
///
/// Until 2026-09-19 the preview did not refresh on that path. Nothing it
/// depended on changed when a purchase completed: `exportServiceProvider`
/// deliberately reads the Pro flag at call time rather than watching it, so it
/// is not rebuilt by an unlock, and the processed photo is unchanged. The user
/// therefore came back to a sheet still stamped PREVIEW underneath a button
/// that now read "Save print sheet to gallery". The *saved* file was correct
/// — `savePrintSheet` re-renders it — so the bug was confined to the picture,
/// which on a screen whose whole job is showing you what you are buying is the
/// worst place for it.
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:passport_photo_app/core/models/photo_spec.dart';
import 'package:passport_photo_app/core/services/preferences.dart';
import 'package:passport_photo_app/features/export/print_sheet_screen.dart';
import 'package:passport_photo_app/features/processing/face_detector_service.dart';
import 'package:passport_photo_app/features/processing/processed_photo.dart';
import 'package:passport_photo_app/features/processing/processing_providers.dart';
import 'package:passport_photo_app/features/purchase/entitlement_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/crop_harness.dart' show StubFaceDetector;
import 'support/specs.dart';

/// The watermark's bottom band is a near-black bar across the full width. A
/// clean sheet is white paper with photo tiles on it and has nothing like it.
///
/// Measured rather than pattern-matched on the exact colour so the test does
/// not break when the band's alpha is retuned.
bool looksWatermarked(Uint8List jpegBytes) {
  final sheet = img.decodeImage(jpegBytes)!;
  // Sample a row inside the bottom band (9% of the height, so 97% down sits
  // in it) but below the band's own white caption, which would otherwise
  // brighten a fifth of the samples on the row through the middle of it.
  final y = (sheet.height * 0.97).round().clamp(0, sheet.height - 1);
  var dark = 0;
  var sampled = 0;
  for (var x = 0; x < sheet.width; x += 8) {
    final p = sheet.getPixel(x, y);
    final lum = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
    if (lum < 110) dark++;
    sampled++;
  }
  // Measured: a stamped sheet reads 0.99 on this row, a clean one 0.00.
  return dark / sampled > 0.5;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PhotoSpec spec;
  late ProcessedPhoto photo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    spec = ukPassport();
    final image = img.Image(width: spec.widthPx, height: spec.heightPx);
    img.fill(image, color: img.ColorRgb8(238, 236, 230));
    photo = ProcessedPhoto(
      spec: spec,
      jpegBytes: Uint8List.fromList(img.encodeJpg(image, quality: 92)),
      widthPx: spec.widthPx,
      heightPx: spec.heightPx,
      checks: const [],
    );
  });

  Future<ProviderContainer> containerWith({required bool unlocked}) async {
    final prefs = await SharedPreferences.getInstance();
    if (unlocked) await prefs.setBool('pro_unlocked', true);
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // ML Kit is a platform channel; nothing here detects anything, but
        // the real service's `close()` throws when the container is disposed.
        faceDetectorServiceProvider
            .overrideWith((ref) => StubFaceDetector() as FaceDetectorService),
        // Stand in for the detector + crop, which need a platform channel.
        processedPhotoProvider('fixture').overrideWith((ref) async => photo),
      ],
    );
  }

  test('a locked user sees a watermarked sheet', () async {
    final container = await containerWith(unlocked: false);
    addTearDown(container.dispose);

    final bytes = await container.read(sheetPreviewProvider('fixture').future);
    expect(looksWatermarked(bytes), isTrue);
  });

  test('an unlocked user sees a clean sheet', () async {
    final container = await containerWith(unlocked: true);
    addTearDown(container.dispose);

    final bytes = await container.read(sheetPreviewProvider('fixture').future);
    expect(looksWatermarked(bytes), isFalse);
  });

  test('buying Pro while the sheet is on screen clears the watermark',
      () async {
    final container = await containerWith(unlocked: false);
    addTearDown(container.dispose);

    // Hold a listener open, the way the live screen does — without one the
    // autoDispose provider is torn down between reads and would recompute for
    // that reason rather than because the entitlement changed, which is
    // precisely the bug this test is here to catch.
    final sub = container.listen(
      sheetPreviewProvider('fixture'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    final before = await container.read(sheetPreviewProvider('fixture').future);
    expect(looksWatermarked(before), isTrue,
        reason: 'precondition: the locked sheet is stamped');

    // The purchase completing is the only thing that changes.
    await container
        .read(sharedPreferencesProvider)
        .setBool('pro_unlocked', true);
    container.read(entitlementProvider.notifier).state = container
        .read(entitlementProvider)
        .copyWith(unlocked: true);
    await container.pump();

    final after = await container.read(sheetPreviewProvider('fixture').future);
    expect(looksWatermarked(after), isFalse,
        reason: 'the sheet must re-render unwatermarked once Pro is unlocked, '
            'not stay stamped under a button that says it is unlocked');
  });
}
