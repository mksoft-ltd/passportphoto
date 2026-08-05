/// [HeadFraming] decides where the head goes. It is the piece that got this
/// wrong before: the crop used to place the eye line by reading a
/// measured-from-the-bottom figure as measured-from-the-top, which put the chin
/// below the bottom edge on 19 of the 30 bundled specs.
///
/// These are algebra tests on the solver alone. Whether the finished JPEG really
/// comes out that way is a different question, answered by
/// `test/crop_geometry_golden_test.dart` against a rendered photo and by
/// `integration_test/crop_geometry_probe_test.dart` against real ML Kit.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:passport_photo_app/core/models/photo_spec.dart';
import 'package:passport_photo_app/features/processing/head_framing.dart';

/// A spec built to order, for driving solver behaviour that no bundled spec
/// provokes any more. Only the five fields the framing reads are meaningful.
PhotoSpec constructedSpec({
  required double heightMm,
  required double faceMinMm,
  required double faceMaxMm,
  required double eyeMinMm,
  required double eyeMaxMm,
}) =>
    PhotoSpec(
      id: 'constructed',
      countryCode: 'ZZ',
      countryName: 'Constructed',
      documentType: 'Test',
      widthMm: 35,
      heightMm: heightMm,
      dpi: 600,
      faceHeightMinMm: faceMinMm,
      faceHeightMaxMm: faceMaxMm,
      eyeLineFromBottomMinMm: eyeMinMm,
      eyeLineFromBottomMaxMm: eyeMaxMm,
      background: BackgroundColor.white,
      format: 'JPEG',
    );

void main() {
  late final List<PhotoSpec> specs;

  setUpAll(() {
    final raw = File('assets/specs/photo_specs.json').readAsStringSync();
    specs = ((json.decode(raw) as Map<String, dynamic>)['specs'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PhotoSpec.fromJson)
        .toList();
  });

  PhotoSpec spec(String id) => specs.firstWhere((s) => s.id == id);

  /// The two eye positions the rest of the suite actually exercises. 0.45 is
  /// what the golden harness's synthetic subject has; 0.60 is what real ML Kit
  /// produced on all five reference portraits, measured on an iPhone simulator
  /// on 2026-08-05. A solver that only worked for one of them would pass one
  /// instrument and fail the other.
  const harnessEye = 0.45;
  const realEye = 0.60;

  group('the head is inside the frame', () {
    for (final eye in [harnessEye, realEye, 0.35, 0.70]) {
      test('for every bundled spec, with the eyes $eye down the head', () {
        for (final s in specs) {
          final f = HeadFraming.forSpec(s, eyeLineWithinHead: eye);
          expect(
            f.crownFraction(eye),
            greaterThanOrEqualTo(HeadFraming.crownMargin - 1e-9),
            reason: '${s.id}: crown too high — $f',
          );
          expect(
            f.chinFraction(eye),
            lessThanOrEqualTo(1 - HeadFraming.chinMargin + 1e-9),
            reason: '${s.id}: chin too low — $f',
          );
        }
      });
    }

    test('even when the eye position is absurd, it never leaves the frame', () {
      // The eye position comes from detector landmarks, so a bad detection can
      // put it anywhere. Clamping inside the solver is what stops that becoming
      // a photo with no chin in it.
      for (final eye in [-5.0, 0.0, 0.01, 0.99, 5.0, 1e9]) {
        for (final s in specs) {
          final f = HeadFraming.forSpec(s, eyeLineWithinHead: eye);
          expect(f.eyeLineFromTopFraction, inInclusiveRange(0.0, 1.0),
              reason: '${s.id} at $eye');
          expect(f.faceHeightFraction, greaterThan(0), reason: '${s.id} at $eye');
        }
      }
    });
  });

  group('head height stays inside the spec band', () {
    for (final eye in [harnessEye, realEye]) {
      test('for every bundled spec, with the eyes $eye down the head', () {
        for (final s in specs) {
          final f = HeadFraming.forSpec(s, eyeLineWithinHead: eye);
          expect(
            f.faceHeightFraction,
            inInclusiveRange(s.faceHeightMinFraction, s.faceHeightMaxFraction),
            reason: '${s.id}: head height outside the spec band — $f',
          );
        }
      });
    }

    test('prefers the middle of the band when nothing forces it lower', () {
      // Canada's 50x70 mm is roomy: a 48% head leaves plenty of margin at both
      // ends, so there is no reason to move off the midpoint.
      final f = HeadFraming.forSpec(spec('ca_passport'),
          eyeLineWithinHead: harnessEye);
      expect(
        f.faceHeightFraction,
        closeTo(spec('ca_passport').targetFaceHeightFraction, 1e-9),
      );
    });

    test('shrinks the head rather than push the crown off the top', () {
      // Rule 2 gives way to rule 1. Driven by a constructed spec rather than a
      // bundled one, because no bundled spec forces this any more: until
      // 2026-08-05 `uk_passport` did, but only because its eye-line figure was
      // the head-height rule miscopied into the eye-line field. Correcting the
      // data removed the tension from the data — the solver still has to
      // handle it, so it is still tested.
      final tight = constructedSpec(
        heightMm: 45,
        faceMinMm: 32,
        faceMaxMm: 36,
        eyeMinMm: 30,
        eyeMaxMm: 36, // the old, impossible figures
      );
      final f = HeadFraming.forSpec(tight, eyeLineWithinHead: harnessEye);
      expect(
        f.crownFraction(harnessEye),
        greaterThanOrEqualTo(HeadFraming.crownMargin - 1e-9),
        reason: 'the crown was pushed off the top to chase the eye line — $f',
      );
      expect(
        f.faceHeightFraction,
        greaterThanOrEqualTo(tight.faceHeightMinFraction),
        reason: 'shrunk past the legal minimum instead of moving the eye line',
      );
    });
  });

  group('the eye line', () {
    test('lands inside the spec band when the framing allows it', () {
      final f = HeadFraming.forSpec(spec('us_passport'),
          eyeLineWithinHead: harnessEye);
      expect(f.honoursSpecEyeLine, isTrue);
      final fromBottom = 1 - f.eyeLineFromTopFraction;
      expect(
        fromBottom,
        inInclusiveRange(
          spec('us_passport').eyeLineFromBottomMinFraction,
          spec('us_passport').eyeLineFromBottomMaxFraction,
        ),
      );
      // 28-35 mm up a 51 mm photo, aiming at the middle.
      expect(fromBottom, closeTo(31.5 / 51, 0.001));
    });

    test('reports honestly when the spec band cannot be reached', () {
      // A spec asking for a 32-36 mm head on a 40 mm photo with the eye line
      // 28-33 mm up. There is no head in that band whose crown clears the top
      // edge with the eyes that high, so the solver has to leave the band —
      // and say so, rather than pretending.
      //
      // These were `it_passport`'s bundled figures until 2026-08-05. Italy
      // publishes the face as 70-80% of the photo, which on its 40 mm format is
      // 28-32 mm, and no eye line at all; the 32-36 mm was the 45 mm group's
      // head-height band applied to a shorter photo. The spec is satisfiable
      // now, so the degradation case is driven from a constructed spec —
      // `honoursSpecEyeLine` is what the seventh compliance check reads to
      // choose its wording, so it has to keep working whether or not any
      // shipped spec currently triggers it.
      final impossible = constructedSpec(
        heightMm: 40,
        faceMinMm: 32,
        faceMaxMm: 36,
        eyeMinMm: 28,
        eyeMaxMm: 33,
      );
      final f =
          HeadFraming.forSpec(impossible, eyeLineWithinHead: harnessEye);
      expect(f.honoursSpecEyeLine, isFalse);
      expect(f.crownFraction(harnessEye),
          greaterThanOrEqualTo(HeadFraming.crownMargin - 1e-9));
      expect(f.faceHeightFraction,
          greaterThanOrEqualTo(impossible.faceHeightMinFraction));
    });

    test('every bundled spec can be honoured at both shipping head shapes', () {
      // The other half of the previous test, and the property CQ-2 bought: with
      // the spec data corrected against ICAO's published portrait geometry,
      // no bundled spec forces the solver to abandon its own eye-line band.
      // If this ever fails, the seventh compliance check will start telling
      // users that a document's two rules contradict each other — which is
      // honest, but is a data question first.
      for (final eye in [harnessEye, realEye]) {
        for (final s in specs) {
          final f = HeadFraming.forSpec(s, eyeLineWithinHead: eye);
          expect(f.honoursSpecEyeLine, isTrue,
              reason: '${s.id} at eyes $eye down the head — $f');
        }
      }
    });

    test('is measured up from the bottom, not down from the top', () {
      // The regression itself, stated as an assertion. The UK's figure is a
      // distance up from the bottom edge, so the eyes belong in the upper half
      // of the photo. Read the old way the eye line came out at 0.27 from the
      // bottom, and the chin at 1.04-1.07 — outside the picture.
      final uk = spec('uk_passport');
      final f = HeadFraming.forSpec(uk, eyeLineWithinHead: harnessEye);
      final fromBottom = 1 - f.eyeLineFromTopFraction;
      expect(fromBottom, greaterThan(0.5));
      expect(fromBottom, closeTo(uk.targetEyeLineFromBottomFraction, 0.02));
    });

    test('stays in the ICAO envelope for every spec at the harness eye', () {
      // ICAO Doc 9303 puts the eye line between 50% and 80% of the picture
      // height up from the bottom. This is the envelope
      // crop_geometry_golden_test.dart asserts, mirrored here so a solver
      // change shows up in the fast suite too.
      for (final s in specs) {
        final f = HeadFraming.forSpec(s, eyeLineWithinHead: harnessEye);
        expect(
          1 - f.eyeLineFromTopFraction,
          inInclusiveRange(0.50, 0.80),
          reason: '${s.id}: $f',
        );
      }
    });
  });

  test('crown, eye line and chin come out in that order', () {
    for (final eye in [harnessEye, realEye]) {
      for (final s in specs) {
        final f = HeadFraming.forSpec(s, eyeLineWithinHead: eye);
        expect(f.crownFraction(eye), lessThan(f.eyeLineFromTopFraction),
            reason: s.id);
        expect(f.eyeLineFromTopFraction, lessThan(f.chinFraction(eye)),
            reason: s.id);
        expect(
          f.chinFraction(eye) - f.crownFraction(eye),
          closeTo(f.faceHeightFraction, 1e-9),
          reason: s.id,
        );
      }
    }
  });
}
