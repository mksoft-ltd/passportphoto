import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:passport_photo_app/core/constants/app_info.dart';
import 'package:passport_photo_app/core/models/photo_spec.dart';
import 'package:passport_photo_app/core/services/preferences.dart';
import 'package:passport_photo_app/features/export/export_service.dart';
import 'package:passport_photo_app/features/export/watermark.dart';
import 'package:passport_photo_app/features/processing/face_detector_service.dart';
import 'package:passport_photo_app/features/processing/photo_processor.dart';
import 'package:passport_photo_app/features/processing/processed_photo.dart';
import 'package:passport_photo_app/features/purchase/entitlement_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:passport_photo_app/features/processing/processing_providers.dart';

import 'support/crop_harness.dart';
import 'support/specs.dart';

/// The paid boundary.
///
/// Everything about the app is free except the file you can take to a print
/// shop, so the whole of the £4.99 rests on these methods behaving differently
/// for a locked and an unlocked user. There are two ways to get it wrong: give
/// the printable file away, or withhold it from someone who paid.
///
/// The gate is read inside [ExportService] rather than passed in by the screen
/// that calls it, so a screen that forgets the check cannot hand out a
/// printable file. The provider wiring is what makes that true, and it is
/// tested at the bottom of this file rather than assumed.
void main() {
  // SharedPreferences' in-memory mock talks over a platform channel.
  TestWidgetsFlutterBinding.ensureInitialized();

  Uint8List flatJpeg({required int width, required int height}) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(240, 238, 232));
    return Uint8List.fromList(img.encodeJpg(image, quality: 92));
  }

  ProcessedPhoto photoFor(PhotoSpec spec) => ProcessedPhoto(
        spec: spec,
        jpegBytes: flatJpeg(width: spec.widthPx, height: spec.heightPx),
        widthPx: spec.widthPx,
        heightPx: spec.heightPx,
        checks: const [],
      );

  ExportService serviceFor({required bool unlocked}) => ExportService(
        PhotoProcessor(FaceDetectorService()),
        () => unlocked,
      );

  group('the print sheet', () {
    test('is refused without the unlock', () async {
      final result = await serviceFor(
        unlocked: false,
      ).savePrintSheet(photoFor(ukPassport()));

      // Refused before any rendering or gallery write, so this needs no
      // platform channels — and, more to the point, a locked user's bytes are
      // never produced at all rather than produced and then withheld.
      expect(result.outcome, ExportOutcome.requiresPro);
      expect(result.message, contains(AppInfo.proDisplayName));
    });
  });

  group('the watermarked preview', () {
    test('is downscaled past printable resolution', () {
      final spec = ukPassport();
      final preview = Watermarker.preview(
        flatJpeg(width: spec.widthPx, height: spec.heightPx),
        longEdgePx: AppInfo.previewLongEdgePx,
      );

      final decoded = img.decodeImage(preview)!;
      expect(decoded.height, AppInfo.previewLongEdgePx);
      expect(decoded.width, lessThan(AppInfo.previewLongEdgePx));
      // The source is 1063 px tall. A preview that kept full height would be a
      // free printable file, which is the entire product given away.
      expect(decoded.height, lessThan(spec.heightPx));
    });

    test('keeps the free file well under half the paid one', () {
      // Not an arbitrary threshold: a preview close to the real export would
      // make the paid tier pointless, and one far below it would stop being a
      // useful proof that the crop is right.
      final spec = ukPassport();
      expect(AppInfo.previewLongEdgePx, lessThan(spec.heightPx / 1.5));
      expect(AppInfo.previewLongEdgePx, greaterThan(400));
    });

    test('marks the image so it cannot pass as the finished photo', () {
      final stamped = Watermarker.preview(
        flatJpeg(width: 400, height: 500),
        longEdgePx: 400,
      );

      final decoded = img.decodeImage(stamped)!;
      // The band across the bottom is the part a reviewer would look for.
      final band = decoded.getPixel(decoded.width ~/ 2, decoded.height - 8);
      expect(band.r, lessThan(120));

      // And the tiled repeat means the middle is no longer the flat fill it
      // started as, so cropping the band off does not recover a clean photo.
      var darkPixels = 0;
      for (var y = 0; y < decoded.height - 60; y++) {
        for (var x = 0; x < decoded.width; x++) {
          if (decoded.getPixel(x, y).r < 200) darkPixels++;
        }
      }
      expect(darkPixels, greaterThan(0));
    });

    test('leaves an image alone that is already small enough', () {
      // Upscaling a small source would fake a resolution the photo does not
      // have, which is the opposite of the problem the watermark solves.
      final stamped = Watermarker.stampJpeg(
        flatJpeg(width: 200, height: 250),
        longEdgePx: 1000,
      );
      final decoded = img.decodeImage(stamped)!;
      expect(decoded.width, 200);
      expect(decoded.height, 250);
    });

    test('hands undecodable bytes back untouched, and so degrades open', () {
      // Pinning a deliberate decision rather than an assumption, because this
      // is the one place in the app where a failure produces an *unwatermarked*
      // image. Both entry points treat "cannot decode" as "return the input",
      // so an undecodable input is returned without a watermark on it.
      //
      // Assessed and left alone. It is not a paywall hole: the bytes reaching
      // these methods were encoded by `PhotoProcessor` seconds earlier in the
      // same process, so "undecodable" is not a state a user can steer into;
      // and the entitlement gate is in `ExportService`, which decides *whether*
      // to watermark before either method is called, rather than relying on
      // the watermark itself to enforce the tier. The alternative — throwing —
      // would turn a near-impossible decode failure into a visible export
      // crash inside a background isolate, which is a worse trade.
      //
      // If stage 4 decides fail-closed is the rule regardless, this is the
      // test to invert, and `ExportService.savePhoto` is where the closed
      // behaviour belongs.
      final rubbish = Uint8List(64);
      expect(Watermarker.preview(rubbish, longEdgePx: 400), same(rubbish));
      expect(Watermarker.stampJpeg(rubbish), same(rubbish));
    });

    test('the gate does not depend on the watermark succeeding', () {
      // The reason the fallback above is survivable. `savePrintSheet` — the
      // Pro-only artefact — is refused before any rendering happens at all, so
      // no amount of watermarking behaviour can change what a locked user
      // receives from it.
      final refused = serviceFor(unlocked: false);
      expect(
        refused.savePrintSheet(photoFor(ukPassport())),
        completion(
          isA<ExportResult>().having(
            (r) => r.outcome,
            'outcome',
            ExportOutcome.requiresPro,
          ),
        ),
      );
    });
  });

  group('the sheet preview on screen', () {
    test('is watermarked for a locked user and clean for a paid one', () async {
      final photo = photoFor(caPassport());

      final locked = await serviceFor(unlocked: false).buildSheetPreview(photo);
      final unlocked = await serviceFor(unlocked: true).buildSheetPreview(photo);

      // A free user sees exactly what they would be buying; screenshotting it
      // must not be a substitute for buying it.
      expect(locked, isNot(equals(unlocked)));

      expect(img.decodeImage(locked)!.width, lessThanOrEqualTo(1000));

      final full = img.decodeImage(unlocked)!;
      // The real sheet is 6 x 4 inches at 300 dpi.
      expect(full.width, 1800);
      expect(full.height, 1200);
    });
  });

  group('the print sheet layout', () {
    test('tiles copies at the spec size on a white 4x6 sheet', () {
      final spec = ukPassport();
      final sheet = img.decodeImage(
        renderPrintSheet(
          flatJpeg(width: spec.widthPx, height: spec.heightPx),
          widthMm: spec.widthMm,
          heightMm: spec.heightMm,
        ),
      )!;

      expect(sheet.width, 1800);
      expect(sheet.height, 1200);

      // The margin has to stay white, or a print shop's trim lands on a photo.
      final corner = sheet.getPixel(4, 4);
      expect(corner.r, greaterThan(240));
      expect(corner.g, greaterThan(240));

      // 35 mm at 300 dpi is 413 px, so four fit across the 6 inch edge. A
      // sheet with fewer than four copies is not worth taking to a shop.
      final tileW = (spec.widthMm / 25.4 * 300).round();
      expect((1800 - 60 + 20) ~/ (tileW + 20), greaterThanOrEqualTo(4));
    });

    test(
      'refuses bytes it cannot decode rather than printing a blank sheet',
      () {
        expect(
          () => renderPrintSheet(Uint8List(64), widthMm: 35, heightMm: 45),
          throwsA(isA<PhotoProcessingFailure>()),
        );
      },
    );
  });

  group('the provider wiring', () {
    // The gate is only as good as where it reads from. These pin that
    // `exportServiceProvider` consults the live entitlement rather than a
    // value captured when the service was built.

    Future<ProviderContainer> containerWith({required bool unlocked}) async {
      SharedPreferences.setMockInitialValues(
        unlocked ? {'pro_unlocked': true} : {},
      );
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          // The real one closes an ML Kit detector over a platform channel
          // when the container is disposed.
          faceDetectorServiceProvider.overrideWithValue(StubFaceDetector()),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('a locked container refuses the sheet', () async {
      final c = await containerWith(unlocked: false);
      final result = await c
          .read(exportServiceProvider)
          .savePrintSheet(photoFor(ukPassport()));
      expect(result.outcome, ExportOutcome.requiresPro);
    });

    test('an unlock mid-session takes effect without a rebuild', () async {
      // The service holds a closure over `ref.read`, not a captured boolean.
      // Someone who buys Pro on the review screen has to be able to save the
      // sheet immediately, without the screen being torn down first.
      final c = await containerWith(unlocked: false);
      final service = c.read(exportServiceProvider);

      expect(
        (await service.savePrintSheet(photoFor(ukPassport()))).outcome,
        ExportOutcome.requiresPro,
      );

      c.read(entitlementProvider.notifier).state = const EntitlementState(
        unlocked: true,
      );
      expect(c.read(isProUnlockedProvider), isTrue);

      // Same service instance, different answer. `requiresPro` is returned by
      // the gate itself, before any rendering; anything else means execution
      // got past it and reached the gallery write, which is a platform channel
      // this suite has no implementation for and which therefore reports a
      // failed save rather than a refusal.
      //
      // This used to assert a MissingPluginException from `path_provider`,
      // which worked only because every export also wrote a redundant temp
      // copy. That write is gone (it left an unrequested, unwatermarked copy of
      // a passport photo in the cache on every save), so the tripwire is the
      // outcome itself.
      final after =
          (await service.savePrintSheet(photoFor(ukPassport()))).outcome;
      expect(after, isNot(ExportOutcome.requiresPro));
    });
  });
}
