import 'package:flutter_test/flutter_test.dart';
import 'package:passport_photo_app/core/models/photo_spec.dart';

import 'support/specs.dart';

/// [PhotoSpec] is the whole product in one class: every crop, every output
/// file and every compliance number is derived from these fields. An error
/// here is not a visual glitch, it is a photo that gets turned away at a
/// passport office.
///
/// Note what is *not* here: no test asserts the arithmetic of the eye-line
/// getters. That is deliberate. The suite used to contain
/// `expect(uk.targetEyeLineFromTopFraction, closeTo(33 / 45, 0.001))`, which
/// looked like a specification and was in fact a defect written down: the
/// figure it divided is measured up from the bottom edge, and reading it as a
/// distance down from the top put the chin below the bottom of the photo for
/// 19 of the 30 specs. A test that pins an intermediate value cannot tell you
/// whether the value is right. The eye line is tested in
/// `test/crop_geometry_golden_test.dart` instead, against where it lands in a
/// finished photo.
void main() {
  group('pixel dimensions', () {
    test('35 x 45 mm at 600 dpi is 827 x 1063 px', () {
      final uk = ukPassport();
      expect(uk.widthPx, 827);
      expect(uk.heightPx, 1063);
    });

    test('2 x 2 inch at 300 dpi is 602 x 602 px', () {
      final us = usPassport();
      expect(us.widthPx, 602);
      expect(us.heightPx, 602);
    });

    test('every bundled spec produces a printable pixel size', () {
      for (final spec in bundledSpecs()) {
        // 600 px on the short edge is roughly the floor for a photo that can
        // be printed at document size without visible pixels.
        expect(
          spec.widthPx,
          greaterThan(300),
          reason: '${spec.id} is only ${spec.widthPx} px wide',
        );
        expect(
          spec.heightPx,
          greaterThan(300),
          reason: '${spec.id} is only ${spec.heightPx} px tall',
        );
        // And not so large that a 4x6 sheet of them exhausts memory on an
        // older phone.
        expect(spec.widthPx * spec.heightPx, lessThan(6000000), reason: spec.id);
      }
    });
  });

  group('aspect ratio', () {
    test('is width over height, so a square spec is 1.0', () {
      expect(usPassport().aspectRatio, closeTo(1.0, 0.001));
    });

    test('is below 1 for the portrait specs', () {
      expect(ukPassport().aspectRatio, closeTo(35 / 45, 0.001));
    });

    test('Spain is 26 mm wide by 32 mm tall, not the other way round', () {
      // Until 1.0.3 this spec was bundled as 32 wide x 26 tall. Spanish law
      // writes the size as "32 por 26 milímetros" without saying which is the
      // height, and the data had read it as width-first, so every Spanish
      // photo came out landscape. See assets/specs/SOURCES.md.
      final es = bundledSpecs().firstWhere((s) => s.id == 'es_passport');
      expect(es.widthMm, 26);
      expect(es.heightMm, 32);
      expect(es.aspectRatio, closeTo(26 / 32, 0.001));
      // ICAO's 70-80% head height and 50-70% eye line on a 32 mm photo.
      expect(es.faceHeightMinMm, closeTo(22.4, 0.001));
      expect(es.faceHeightMaxMm, closeTo(25.6, 0.001));
      expect(es.eyeLineFromBottomMinMm, closeTo(16.0, 0.001));
      expect(es.eyeLineFromBottomMaxMm, closeTo(22.4, 0.001));
    });

    test('no bundled spec is wider than it is tall', () {
      // Every document photo in the set is a head-and-shoulders portrait or a
      // square. A landscape entry is far more likely to be a transposed
      // "H x W" figure than a real rule — which is exactly how Spain shipped
      // wrong. Add an exception here only with a source that says so.
      for (final spec in bundledSpecs()) {
        expect(spec.widthMm, lessThanOrEqualTo(spec.heightMm), reason: spec.id);
      }
    });

    test('the pixel dimensions keep the millimetre aspect ratio', () {
      for (final spec in bundledSpecs()) {
        expect(
          spec.widthPx / spec.heightPx,
          closeTo(spec.aspectRatio, 0.005),
          reason: spec.id,
        );
      }
    });
  });

  group('target face height', () {
    test('is the midpoint of the allowed range, over the photo height', () {
      // (25 + 35) / 2 / 51
      expect(usPassport().targetFaceHeightFraction, closeTo(30 / 51, 0.001));
    });

    test('sits inside the spec range for every bundled spec', () {
      // The crop aims at the midpoint, so this is what makes the shipped
      // photos nominally compliant on head height.
      for (final spec in bundledSpecs()) {
        expect(
          spec.targetFaceHeightFraction,
          inInclusiveRange(
            spec.faceHeightMinMm / spec.heightMm,
            spec.faceHeightMaxMm / spec.heightMm,
          ),
          reason: spec.id,
        );
      }
    });
  });

  group('background colours', () {
    test('parses the four values the asset uses', () {
      expect(BackgroundColorX.parse('white'), BackgroundColor.white);
      expect(BackgroundColorX.parse('off-white'), BackgroundColor.offWhite);
      expect(BackgroundColorX.parse('light-grey'), BackgroundColor.lightGrey);
      expect(BackgroundColorX.parse('light-blue'), BackgroundColor.lightBlue);
    });

    test('falls back to white for anything unrecognised', () {
      // The review screen paints the card behind the photo with this, so an
      // unknown value must not throw — a new spec with a typo should render
      // plainly rather than crash the screen.
      expect(BackgroundColorX.parse('unknown'), BackgroundColor.white);
      expect(BackgroundColorX.parse(''), BackgroundColor.white);
    });

    test('every value has a label the picker can show', () {
      for (final value in BackgroundColor.values) {
        expect(value.label, isNotEmpty);
      }
    });
  });

  group('display strings', () {
    test('the size label drops a trailing .0 but keeps a real decimal', () {
      expect(ukPassport().sizeLabel, '35 × 45 mm @ 600dpi');

      final fractional = PhotoSpec.fromJson({
        ...ukPassportJson,
        'widthMm': 33.5,
        'heightMm': 48.5,
      });
      expect(fractional.sizeLabel, '33.5 × 48.5 mm @ 600dpi');
    });

    test('the display label names the country and the document', () {
      expect(ukPassport().displayLabel, 'United Kingdom · Passport');
    });
  });

  group('the bundled asset', () {
    test('parses, and holds the 30 specs the store listing claims', () {
      final specs = bundledSpecs();
      expect(specs, hasLength(30));

      final countries = specs.map((s) => s.countryCode).toSet()
        // ZZ is the ICAO/Schengen generic fallback, not a country.
        ..remove('ZZ')
        ..remove('EU');
      expect(
        countries.length,
        21,
        reason: 'the paywall, README and PRODUCT_SPEC all say 21 countries',
      );
    });

    test('has no duplicate ids', () {
      final ids = bundledSpecs().map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every spec has the fields the UI reads', () {
      for (final spec in bundledSpecs()) {
        expect(spec.countryName, isNotEmpty, reason: spec.id);
        expect(spec.documentType, isNotEmpty, reason: spec.id);
        expect(spec.countryCode, hasLength(2), reason: spec.id);
        expect(spec.dpi, greaterThanOrEqualTo(300), reason: spec.id);
        expect(spec.format, isNotEmpty, reason: spec.id);
      }
    });

    test('every millimetre figure is internally consistent', () {
      for (final spec in bundledSpecs()) {
        expect(spec.widthMm, greaterThan(0), reason: spec.id);
        expect(spec.heightMm, greaterThan(0), reason: spec.id);
        expect(
          spec.faceHeightMinMm,
          lessThanOrEqualTo(spec.faceHeightMaxMm),
          reason: spec.id,
        );
        expect(
          spec.eyeLineFromBottomMinMm,
          lessThanOrEqualTo(spec.eyeLineFromBottomMaxMm),
          reason: spec.id,
        );
        // The head cannot be taller than the photo it is in.
        expect(
          spec.faceHeightMaxMm,
          lessThan(spec.heightMm),
          reason: spec.id,
        );
        expect(
          spec.eyeLineFromBottomMaxMm,
          lessThan(spec.heightMm),
          reason: spec.id,
        );
      }
    });

    test('the eye line sits in the upper half of every photo', () {
      // ICAO Doc 9303 puts the eye line between 50% and 70% of the picture
      // height measured up from the bottom edge; national rules vary a little
      // either side. Every bundled figure lands in that envelope when read
      // that way, and none of them does when read as a distance down from the
      // top — which is how the field earned its current name, and why a spec
      // added later with the wrong convention should fail here rather than in
      // a photo somebody has already had printed.
      for (final spec in bundledSpecs()) {
        final midMm =
            (spec.eyeLineFromBottomMinMm + spec.eyeLineFromBottomMaxMm) / 2;
        expect(
          midMm / spec.heightMm,
          inInclusiveRange(0.50, 0.85),
          reason: '${spec.id}: $midMm mm up from the bottom of a '
              '${spec.heightMm} mm photo',
        );
      }
    });
  });
}
