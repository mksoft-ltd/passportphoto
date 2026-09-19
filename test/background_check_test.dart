/// The background check, measured against walls.
///
/// This check was inverted in practice until 2026-09-19, in two independent
/// ways.
///
/// **It measured the wrong region.** It sampled the full width of the top 10%
/// of rows, on the stated grounds that this was "reliably background (above
/// the head)". [HeadFraming.crownMargin] is 0.04, so a correctly framed head
/// reaches to 4% from the top edge and the lower half of that window is hair.
/// What it actually measured was the contrast between hair and wall. A white
/// wall behind dark hair scored variance 77 and **failed**; a black wall
/// behind dark hair scored variance 4 and **passed**. The photograph that
/// complies was rejected and the one that cannot comply was approved.
///
/// **It never looked at the colour.** The mean was computed and discarded, so
/// the only thing the spec states about the background — "plain light-coloured"
/// (UK), "white or off-white" (US), "light grey" (Germany) — was never tested
/// at all. Evenness was the whole check.
///
/// The thresholds here are deliberately loose. Those three rules are different
/// from each other, and a check tight enough to tell them apart would fail
/// correct photographs over the white balance of the room. So the check catches
/// walls no authority would accept — too dark, too colourful, not plain — and
/// quotes the spec's own requirement so the user can match the shade.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:passport_photo_app/core/models/photo_spec.dart';
import 'package:passport_photo_app/features/processing/photo_processor.dart';
import 'package:passport_photo_app/features/processing/processed_photo.dart';

import 'support/specs.dart';

/// Paints a filled ellipse. `package:image` has no such primitive.
void _ellipse(img.Image im, int cx, int cy, int rx, int ry, img.Color c) {
  for (var y = cy - ry; y <= cy + ry; y++) {
    if (y < 0 || y >= im.height) continue;
    for (var x = cx - rx; x <= cx + rx; x++) {
      if (x < 0 || x >= im.width) continue;
      final dx = (x - cx) / rx, dy = (y - cy) / ry;
      if (dx * dx + dy * dy <= 1.0) im.setPixel(x, y, c);
    }
  }
}

/// A subject on a wall, framed the way the crop will frame them.
///
/// The head geometry matches `test/support/crop_harness.dart`'s synthetic
/// subject, so the crown lands where a real correctly-framed crown lands —
/// which is the whole point, since the defect was about sampling a region the
/// head reaches into.
ProcessedPhoto _shoot({
  required img.Color wall,
  required img.Color hair,
  PhotoSpec? spec,
  bool gradient = false,
}) {
  const w = 2400, h = 3200;
  final src = img.Image(width: w, height: h);
  if (gradient) {
    // A lighting falloff across the wall: bright on the left, shadowed right.
    for (var x = 0; x < w; x++) {
      final v = (255 - (105 * x / w)).round();
      img.drawLine(src, x1: x, y1: 0, x2: x, y2: h - 1,
          color: img.ColorRgb8(v, v, v));
    }
  } else {
    img.fill(src, color: wall);
  }
  // Head: crown 900 -> chin 1770, centred on x=1200.
  _ellipse(src, 1200, (900 + 1770) ~/ 2, 313, (1770 - 900) ~/ 2, hair);
  // Face over the lower two thirds of the head.
  _ellipse(src, 1200, (1130 + 1760) ~/ 2, 250, (1760 - 1130) ~/ 2,
      img.ColorRgb8(226, 190, 165));

  final file = File('${Directory.systemTemp.path}/bg_check.png')
    ..writeAsBytesSync(img.encodePng(src));

  return renderProcessedPhoto(
    sourcePath: file.path,
    spec: spec ?? ukPassport(),
    face: const FaceMeasurement(
      boxLeft: 940, boxTop: 1170, boxWidth: 520, boxHeight: 600,
      leftEyeY: 1391, rightEyeY: 1391,
      yaw: 0, roll: 0, pitch: 0,
      leftEyeOpenProbability: 1, rightEyeOpenProbability: 1,
      smilingProbability: 0,
    ),
    extraFaces: 0,
  );
}

ValidationCheck _background(ProcessedPhoto p) =>
    p.checks.firstWhere((c) => c.label == 'Background');

void main() {
  final darkHair = img.ColorRgb8(35, 30, 28);
  final blondeHair = img.ColorRgb8(215, 190, 140);

  group('a compliant wall passes, whatever the hair', () {
    test('white wall, dark hair — this used to FAIL', () {
      final c = _background(
          _shoot(wall: img.ColorRgb8(250, 250, 250), hair: darkHair));
      expect(c.passed, isTrue, reason: c.detail);
    });

    test('white wall, blonde hair', () {
      final c = _background(
          _shoot(wall: img.ColorRgb8(250, 250, 250), hair: blondeHair));
      expect(c.passed, isTrue, reason: c.detail);
    });

    test('light grey wall — what Germany requires', () {
      final c = _background(_shoot(
          wall: img.ColorRgb8(227, 227, 227),
          hair: darkHair,
          spec: bundledSpecs().firstWhere((s) => s.id == 'de_passport')));
      expect(c.passed, isTrue, reason: c.detail);
    });

    test('cream wall — what the UK asks for', () {
      final c = _background(
          _shoot(wall: img.ColorRgb8(245, 241, 232), hair: darkHair));
      expect(c.passed, isTrue, reason: c.detail);
    });
  });

  group('a wall no authority would accept fails', () {
    test('black wall, dark hair — this used to PASS', () {
      final c =
          _background(_shoot(wall: img.ColorRgb8(20, 20, 20), hair: darkHair));
      expect(c.passed, isFalse);
      expect(c.detail, contains('too dark'));
    });

    test('deep red wall', () {
      final c =
          _background(_shoot(wall: img.ColorRgb8(180, 30, 30), hair: darkHair));
      expect(c.passed, isFalse);
    });

    test('mid-grey wall', () {
      final c = _background(
          _shoot(wall: img.ColorRgb8(120, 120, 120), hair: darkHair));
      expect(c.passed, isFalse);
      expect(c.detail, contains('too dark'));
    });

    test('a bright but strongly coloured wall is caught by chroma, not '
        'brightness', () {
      final c = _background(
          _shoot(wall: img.ColorRgb8(255, 170, 170), hair: darkHair));
      expect(c.passed, isFalse);
      expect(c.detail, contains('colour cast'));
    });

    test('a shadow across the wall still fails as uneven', () {
      final c = _background(
          _shoot(wall: img.ColorRgb8(0, 0, 0), hair: darkHair, gradient: true));
      expect(c.passed, isFalse);
      expect(c.detail, contains('uneven'));
    });
  });

  group('the report itself', () {
    test('has exactly eight checks', () {
      // Both stores' full_description.txt state this number, so it is part of
      // the store listing and cannot drift silently. The background colour
      // test was folded into the existing background check rather than added
      // as its own; the eighth is the neutral-expression check.
      final photo =
          _shoot(wall: img.ColorRgb8(250, 250, 250), hair: darkHair);
      expect(photo.checks, hasLength(8));
    });

    test('names the document\'s own required background either way', () {
      final pass =
          _background(_shoot(wall: img.ColorRgb8(250, 250, 250), hair: darkHair));
      final fail =
          _background(_shoot(wall: img.ColorRgb8(20, 20, 20), hair: darkHair));
      // uk_passport is off-white; the user has to be told which shade to match.
      expect(pass.detail.toLowerCase(), contains('off-white'));
      expect(fail.detail.toLowerCase(), contains('off-white'));
    });
  });
}
