import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:passport_photo_app/core/models/photo_spec.dart';

import 'support/crop_harness.dart';

/// What a passport photo has to be true of, whatever the crop maths does to
/// get there.
///
/// Every assertion is a measurement of a finished photo — the stripes painted
/// across the source are located again in the output — so nothing here
/// restates the formula it is checking, and the suite does not have to be
/// rewritten when the formula is retuned. See `test/support/crop_harness.dart`
/// for the ruler.
///
/// ## What this file exists to stop happening again
///
/// Until 2026-08-05 the crop put the chin below the bottom edge of the photo
/// for 19 of the 30 bundled specs, including `uk_passport` — the app's primary
/// market — and `icao_generic`, the fallback for every country not on the
/// list. `PhotoSpec` divided the eye-line figures as a distance down from the
/// top edge, while `assets/specs/photo_specs.json` holds them as distances *up
/// from the bottom*, which is how ICAO Doc 9303, UK HMPO and 22 CFR 51.604 all
/// state the eye line. `us_passport`'s 28–35 mm is verbatim the US State
/// Department figure, and 22 CFR words it "from the bottom of the photo".
///
/// Nothing caught it. The six compliance checks all reported green, because
/// the one that could have noticed divided the crop by itself. The suite had a
/// unit test asserting the eye line came out at `33/45`, which pinned the
/// defect in place as though it were the specification.
///
/// So these tests assert against the picture, and they cover the crown as well
/// as the chin: reading the field the right way round is necessary but not
/// sufficient, and a fix that only changed the convention would have pushed
/// the crown off the *top* edge on the 45 mm specs instead.
///
/// Measured on device against real ML Kit by
/// `integration_test/crop_geometry_probe_test.dart`; run that after any change
/// to the framing, because everything here runs on a fabricated face and
/// cannot tell you whether ML Kit's real bounding box still behaves the way
/// the crop assumes.
void main() {
  late final List<PhotoSpec> specs;

  setUpAll(() {
    final raw = File('assets/specs/photo_specs.json').readAsStringSync();
    final data = json.decode(raw) as Map<String, dynamic>;
    specs = (data['specs'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PhotoSpec.fromJson)
        .toList();
  });

  group('the harness itself', () {
    // Green today, and green after the fix. Without this, a golden that is
    // skipped for a bug and a golden that is skipped because its ruler broke
    // look identical.
    test('can measure a crop that does frame the whole head', () async {
      final ca = specs.firstWhere((s) => s.id == 'ca_passport');
      final placement = await measureCrop(ca);

      expect(placement.crownVisible, isTrue, reason: '$placement');
      expect(placement.chinVisible, isTrue, reason: '$placement');
      expect(placement.eyeLine, isNotNull, reason: '$placement');

      // The three stripes come back in the order they were painted.
      expect(placement.crown!, lessThan(placement.eyeLine!));
      expect(placement.eyeLine!, lessThan(placement.chin!));

      // And the head measures the size the spec asked for. This is the one
      // thing the current crop already gets right, so it pins the ruler's
      // scale without asserting anything about the defect.
      expect(
        placement.faceHeightFraction,
        closeTo(ca.targetFaceHeightFraction, 0.02),
        reason: '$placement',
      );
    });
  });

  // Both head shapes the app actually meets. 0.45 is the classical "eyes half
  // way down the head" figure and the processor's own landmark-less fallback;
  // 0.59 is the top of the range real ML Kit produced on the five reference
  // portraits, and therefore the one that ships.
  //
  // Running at one value only is how CQ-1 stayed invisible: at 0.45 every spec
  // looked compliant, while at 0.59 — the shipping geometry — `it_passport`
  // landed its eye line at 0.458, outside the envelope this file asserts. The
  // fix for that was the spec data (see assets/specs/SOURCES.md), not a wider
  // envelope.
  const eyeShapes = <String, double>{
    'classical head': SyntheticSubject.harnessEye,
    'real ML Kit head': SyntheticSubject.realMlKitEye,
  };

  for (final shape in eyeShapes.entries) {
    group('every bundled spec, ${shape.key} (eyes ${shape.value} down)', () {
      for (final id in _allSpecIds) {
        test('$id frames the whole head', () async {
          final spec = specs.firstWhere((s) => s.id == id);
          _theHeadIsInsideTheFrame(
            spec,
            await measureCrop(spec, eyeLineWithinHead: shape.value),
          );
        });

        test('$id places the eye line where the standards put it', () async {
          final spec = specs.firstWhere((s) => s.id == id);
          _theEyeLineSitsWhereTheStandardsPutIt(
            spec,
            await measureCrop(spec, eyeLineWithinHead: shape.value),
          );
        });
      }
    });
  }
}

/// The whole head, crown to chin, is inside the photo.
///
/// This is the floor. A document photo missing the chin is rejected at the
/// counter, and a photo missing the crown is rejected too — every issuing
/// authority measures head height from one to the other, so both have to be
/// there before any other rule can even be assessed.
void _theHeadIsInsideTheFrame(PhotoSpec spec, HeadPlacement placement) {
  expect(
    placement.chinVisible,
    isTrue,
    reason: '${spec.id}: the chin is below the bottom edge — $placement',
  );
  expect(
    placement.crownVisible,
    isTrue,
    reason: '${spec.id}: the crown is above the top edge — $placement',
  );

  // Inside, and not pressed against an edge: a chin touching the bottom is a
  // photo with no neck in it, which the same counter will also turn away.
  expect(
    placement.chin,
    lessThan(0.95),
    reason: '${spec.id}: the chin is jammed against the bottom — $placement',
  );
  expect(
    placement.crown,
    greaterThan(0.02),
    reason: '${spec.id}: the crown is jammed against the top — $placement',
  );

  // And the head is the size the spec asks for, measured from the finished
  // photo rather than from the processor's own arithmetic.
  expect(
    placement.faceHeightFraction,
    inInclusiveRange(
      spec.faceHeightMinMm / spec.heightMm - 0.01,
      spec.faceHeightMaxMm / spec.heightMm + 0.01,
    ),
    reason: '${spec.id}: head height out of spec — $placement',
  );
}

/// The eye line falls where the spec says it should, measured *up from the
/// bottom edge*.
///
/// Two assertions, in widening order. The outer one is ICAO's envelope
/// (50–80% of the picture height, the range every published national figure
/// sits inside); the inner one is the spec's own band from
/// `photo_specs.json`.
///
/// Until 2026-08-05 only the envelope was asserted, because the bundled bands
/// were not satisfiable: the 45 mm specs stated the eye line at 30–36 mm, which
/// is the *head-height* rule copied into the eye-line field and describes a
/// photo whose crown is 9 mm above its own top edge. With the data corrected
/// against ICAO's published portrait geometry (`assets/specs/SOURCES.md`) the
/// specs' own bands are satisfiable, so the stronger assertion is the one worth
/// making — and it is the assertion that backs the app's seventh compliance
/// check, which compares the same measurement against the same band.
void _theEyeLineSitsWhereTheStandardsPutIt(
  PhotoSpec spec,
  HeadPlacement placement,
) {
  expect(
    placement.eyeLineFromBottom,
    isNotNull,
    reason: '${spec.id}: the eye line is not in the photo at all — $placement',
  );
  expect(
    placement.eyeLineFromBottom,
    inInclusiveRange(0.50, 0.80),
    reason: '${spec.id}: the eye line is ${placement.eyeLineFromBottom} of the '
        'way up from the bottom; ICAO 9303 wants 0.50–0.80 — $placement',
  );

  // A stripe is seven source pixels tall and survives a cubic resample and a
  // quality-92 encode, so the located row carries about a pixel of slack.
  const rulerSlack = 0.01;
  expect(
    placement.eyeLineFromBottom,
    inInclusiveRange(
      spec.eyeLineFromBottomMinFraction - rulerSlack,
      spec.eyeLineFromBottomMaxFraction + rulerSlack,
    ),
    reason: '${spec.id}: the eye line is ${placement.eyeLineFromBottom} of the '
        'way up from the bottom. The spec sheet asks for '
        '${spec.eyeLineFromBottomMinMm}–${spec.eyeLineFromBottomMaxMm} mm up a '
        '${spec.heightMm} mm photo, which is '
        '${spec.eyeLineFromBottomMinFraction.toStringAsFixed(3)}–'
        '${spec.eyeLineFromBottomMaxFraction.toStringAsFixed(3)} — $placement',
  );
}

/// Named rather than derived from the asset, so that a spec quietly
/// disappearing from `photo_specs.json` shows up as a missing test rather than
/// as a suite that got shorter.
const _allSpecIds = <String>[
  'icao_generic',
  'schengen_generic',
  'us_passport',
  'us_visa',
  'us_drivers_license',
  'uk_passport',
  'uk_visa',
  'ca_passport',
  'ca_id',
  'au_passport',
  'nz_passport',
  'ie_passport',
  'de_passport',
  'de_id',
  'fr_passport',
  'es_passport',
  'it_passport',
  'nl_passport',
  'se_passport',
  'ch_passport',
  'jp_passport',
  'cn_passport',
  'cn_visa',
  'in_passport',
  'in_visa',
  'sg_passport',
  'ae_passport',
  'br_passport',
  'mx_passport',
  'za_passport',
];
