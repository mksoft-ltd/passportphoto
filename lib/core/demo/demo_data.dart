import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/photo_spec.dart';
import '../../features/processing/processed_photo.dart';

/// Fixture state for `--dart-define=SCREENSHOT_MODE=true`.
///
/// Everything here is reached only through `AppInfo.screenshotMode`, which is
/// `false` at compile time in release builds, so none of it survives into a
/// shipped binary. Nothing in here touches the camera, the photo library or
/// ML Kit — the point is that the screenshot run is deterministic and needs no
/// device permissions.
class DemoData {
  const DemoData._();

  /// The spec the screenshots are framed around.
  static const String specId = 'uk_passport';

  /// A finished UK passport photo with every compliance check passing.
  static Future<ProcessedPhoto> processedPhoto(PhotoSpec spec) async {
    final width = spec.widthPx;
    final height = spec.heightPx;
    final backgroundValue = spec.background.color.toARGB32();
    final jpeg = await Isolate.run(
      () => renderDemoPortrait(
        width: width,
        height: height,
        backgroundArgb: backgroundValue,
      ),
    );

    return ProcessedPhoto(
      spec: spec,
      jpegBytes: jpeg,
      widthPx: width,
      heightPx: height,
      checks: checksFor(spec),
    );
  }

  /// Where the demo portrait's eye line sits, as a fraction of the picture
  /// height measured up from the bottom.
  ///
  /// Derived from the drawing itself, not chosen: `renderDemoPortrait` puts the
  /// crown at 0.085 and the chin at 0.785 of the height, with the eyes 0.42 of
  /// the way down the head, so the eye line lands at 1 - (0.085 + 0.42 × 0.70).
  /// Keep the two in step — the illustration is what the store screenshots
  /// show, and this is the number the report next to it quotes.
  static const double portraitEyeLineFromBottom = 0.621;

  /// The seventh check, computed rather than asserted, so the screenshot
  /// fixture cannot claim a compliance the drawing does not have.
  static ValidationCheck _eyeLineCheck(PhotoSpec spec) {
    final mm = portraitEyeLineFromBottom * spec.heightMm;
    final ok = portraitEyeLineFromBottom >= spec.eyeLineFromBottomMinFraction &&
        portraitEyeLineFromBottom <= spec.eyeLineFromBottomMaxFraction;
    final band = '${spec.eyeLineFromBottomMinMm}-'
        '${spec.eyeLineFromBottomMaxMm}mm';
    return ValidationCheck(
      label: 'Eye line within spec',
      passed: ok,
      detail: ok
          ? 'Eyes sit ${mm.toStringAsFixed(1)}mm above the bottom edge '
              '(target $band).'
          : 'Eyes sit ${mm.toStringAsFixed(1)}mm above the bottom edge — '
              'should be $band.',
    );
  }

  /// The same seven checks the real processor runs, all passing, with the
  /// numbers derived from [spec] so the report stays plausible for whichever
  /// document is on screen.
  static List<ValidationCheck> checksFor(PhotoSpec spec) {
    final minPct = (spec.faceHeightMinMm / spec.heightMm * 100).round();
    final maxPct = (spec.faceHeightMaxMm / spec.heightMm * 100).round();
    final actualPct = ((minPct + maxPct) / 2).round();
    return [
      const ValidationCheck(
        label: 'Single face detected',
        passed: true,
        detail: 'Exactly one face found in frame.',
      ),
      const ValidationCheck(
        label: 'Eyes open',
        passed: true,
        detail: 'Both eyes are clearly open.',
      ),
      const ValidationCheck(
        label: 'Looking forward',
        passed: true,
        detail: 'Head is centered and facing the camera.',
      ),
      const ValidationCheck(
        label: 'Neutral expression',
        passed: true,
        detail: 'Neutral expression, mouth closed.',
      ),
      ValidationCheck(
        label: 'Face size within spec',
        passed: true,
        detail: 'Face fills $actualPct% of photo height '
            '(target $minPct-$maxPct%).',
      ),
      _eyeLineCheck(spec),
      const ValidationCheck(
        label: 'Background',
        passed: true,
        detail: 'Plain, evenly-lit light background. '
            'This document asks for off-white — check the shade matches.',
      ),
      const ValidationCheck(
        label: 'Photo fully captured',
        passed: true,
        detail: 'Whole head in frame, and the crop fits within the source.',
      ),
    ];
  }
}

/// Draws a flat-illustration head-and-shoulders at the exact framing the spec
/// asks for. Top-level and pure so it can be handed to [Isolate.run].
///
/// Deliberately an illustration rather than a photograph: a stand-in face in a
/// store screenshot must not look like a real person's document photo, and it
/// must not be mistakable for one either. It is drawn to plausible passport
/// framing all the same, because it is what the store screenshots show — the
/// crown just inside the top edge and the chin about four fifths down, so the
/// face fills ~70% of the height. That is the middle of the UK spec's 64–76%
/// band, which is the figure the seeded compliance report quotes.
Uint8List renderDemoPortrait({
  required int width,
  required int height,
  required int backgroundArgb,
}) {
  final image = img.Image(width: width, height: height);
  final bg = img.ColorRgb8(
    (backgroundArgb >> 16) & 0xFF,
    (backgroundArgb >> 8) & 0xFF,
    backgroundArgb & 0xFF,
  );
  img.fill(image, color: bg);

  // Very gentle vertical falloff so the backdrop reads as a lit wall rather
  // than a flat fill, while staying well inside the uniformity threshold.
  for (var y = 0; y < height; y++) {
    final shade = (y / height * 10).round();
    for (var x = 0; x < width; x++) {
      final p = image.getPixel(x, y);
      image.setPixelRgb(x, y, p.r - shade, p.g - shade, p.b - shade);
    }
  }

  final cx = width / 2;
  final crownY = height * 0.085;
  final chinY = height * 0.785;
  final faceH = chinY - crownY;
  final headCy = (crownY + chinY) / 2;
  final headRy = faceH / 2;
  final headRx = width * 0.325;

  final eyeY = crownY + faceH * 0.42;
  final eyeDx = headRx * 0.42;
  final shoulderY = height * 0.855;

  const skin = (233, 199, 176);
  const skinShade = (213, 177, 153);
  const skinDeep = (193, 155, 131);
  const hair = (61, 47, 40);
  const lid = (96, 74, 62);
  const iris = (78, 58, 46);
  const pupil = (34, 26, 22);
  const sclera = (250, 250, 250);
  const lip = (188, 134, 124);
  const lipLine = (158, 106, 98);
  const jacket = (46, 62, 88);
  const shirt = (236, 240, 246);

  // Half-width of the head at a given row: an ellipse, narrowed below the
  // cheekbones so the jaw tapers to a chin instead of ending in a dome.
  double headHalfWidth(double y, {double grow = 1.0}) {
    final rx = headRx * grow;
    final ry = headRy * grow;
    final t = (y - headCy) / ry;
    if (t.abs() >= 1) return 0;
    var half = rx * math.sqrt(1 - t * t);
    if (t > 0.08) {
      final u = (t - 0.08) / 0.92;
      half *= 1 - 0.34 * math.pow(u, 1.7);
    }
    return half;
  }

  // Neck: a slight trapezoid from jaw to collar, in shadow because it sits
  // under the chin. It runs past the shoulder line and the torso is painted
  // over it — drawn the other way round, the neck punches a skin-coloured
  // rectangle through the collar.
  final neckTop = chinY - faceH * 0.10;
  final neckBottom = shoulderY + height * 0.07;
  for (var y = neckTop.floor(); y < neckBottom; y++) {
    if (y < 0 || y >= height) continue;
    final t = ((y - neckTop) / (neckBottom - neckTop)).clamp(0.0, 1.0);
    final half = width * (0.115 + 0.040 * t);
    for (var x = (cx - half).floor(); x <= (cx + half).ceil(); x++) {
      if (x < 0 || x >= width) continue;
      image.setPixelRgb(x, y, skinShade.$1, skinShade.$2, skinShade.$3);
    }
  }

  // Torso. The shoulder line is highest beside the neck and slopes away, and
  // it runs off the bottom edge — the way a document photo's does. A
  // flat-topped block here reads as a wall, not a person.
  for (var x = 0; x < width; x++) {
    final dx = (x - cx).abs() / (width * 0.5);
    final top = shoulderY + height * 0.085 * math.pow(dx, 1.7);
    for (var y = top.floor(); y < height; y++) {
      if (y < 0) continue;
      final shirtHalf = width *
          0.17 *
          math.pow(((y - shoulderY) / (height - shoulderY)).clamp(0.0, 1.0), 1.2);
      final c = (x - cx).abs() < shirtHalf ? shirt : jacket;
      image.setPixelRgb(x, y, c.$1, c.$2, c.$3);
    }
  }
  // The shadow the chin casts on the neck.
  _fillEllipse(
    image,
    cx: cx,
    cy: chinY + faceH * 0.015,
    rx: width * 0.100,
    ry: faceH * 0.025,
    color: skinDeep,
  );

  // Ears, level with the eye line, so the illustration matches what the specs
  // actually ask to be visible.
  final earY = eyeY + faceH * 0.07;
  for (final sign in const [-1, 1]) {
    _fillEllipse(
      image,
      cx: cx + sign * headHalfWidth(earY) * 0.96,
      cy: earY,
      rx: width * 0.028,
      ry: faceH * 0.075,
      color: skinShade,
    );
  }

  // The face, with the jaw shaded slightly so it reads as a head rather than a
  // flat oval.
  for (var y = crownY.floor(); y <= chinY.ceil(); y++) {
    if (y < 0 || y >= height) continue;
    final half = headHalfWidth(y.toDouble());
    if (half <= 0) continue;
    final t = ((y - headCy) / headRy).clamp(-1.0, 1.0);
    final shade = t > 0.30 ? ((t - 0.30) / 0.70).clamp(0.0, 1.0) * 0.22 : 0.0;
    final r = (skin.$1 + (skinShade.$1 - skin.$1) * shade).round();
    final g = (skin.$2 + (skinShade.$2 - skin.$2) * shade).round();
    final b = (skin.$3 + (skinShade.$3 - skin.$3) * shade).round();
    for (var x = (cx - half).floor(); x <= (cx + half).ceil(); x++) {
      if (x < 0 || x >= width) continue;
      image.setPixelRgb(x, y, r, g, b);
    }
  }

  // Hair: a cap that follows the skull and drops past the temples, rather than
  // a bowl with a straight edge across the brow. The row loop has to run well
  // below the hairline or the sideburns end in a horizontal cut, and the cap
  // is only fractionally wider than the head — any more and the temples show a
  // step where the hair overhangs the face.
  for (var y = (crownY - faceH * 0.02).floor();
      y <= (crownY + faceH * 0.55).ceil();
      y++) {
    if (y < 0 || y >= height) continue;
    final half = headHalfWidth(y.toDouble(), grow: 1.012);
    if (half <= 0) continue;
    for (var x = (cx - half).floor(); x <= (cx + half).ceil(); x++) {
      if (x < 0 || x >= width) continue;
      final u = ((x - cx) / half).clamp(-1.0, 1.0);
      final hairBottom = crownY + faceH * (0.20 + 0.30 * u * u);
      if (y <= hairBottom) {
        image.setPixelRgb(x, y, hair.$1, hair.$2, hair.$3);
      }
    }
  }

  for (final sign in const [-1, 1]) {
    final ex = cx + sign * eyeDx;

    // Brow: a crescent, cut by a second ellipse in skin below it.
    _fillEllipse(
      image,
      cx: ex,
      cy: eyeY - faceH * 0.085,
      rx: headRx * 0.30,
      ry: faceH * 0.038,
      color: hair,
    );
    _fillEllipse(
      image,
      cx: ex,
      cy: eyeY - faceH * 0.055,
      rx: headRx * 0.32,
      ry: faceH * 0.036,
      color: skin,
    );

    // Eye: an almond of white, an iris, a pupil, then an upper lid over the
    // top of it.
    final eyeRx = headRx * 0.185;
    final eyeRy = faceH * 0.033;
    _fillEllipse(image, cx: ex, cy: eyeY, rx: eyeRx, ry: eyeRy, color: sclera);
    _fillEllipse(
      image,
      cx: ex,
      cy: eyeY,
      rx: eyeRy * (width / height) * 1.9,
      ry: eyeRy * 0.92,
      color: iris,
    );
    _fillEllipse(
      image,
      cx: ex,
      cy: eyeY,
      rx: eyeRy * (width / height) * 0.9,
      ry: eyeRy * 0.46,
      color: pupil,
    );
    for (var y = (eyeY - eyeRy).floor(); y <= eyeY.ceil(); y++) {
      if (y < 0 || y >= height) continue;
      final t = (y - eyeY) / eyeRy;
      final half = eyeRx * math.sqrt(math.max(0.0, 1 - t * t));
      if (t > -0.42) continue;
      for (var x = (ex - half).floor(); x <= (ex + half).ceil(); x++) {
        if (x < 0 || x >= width) continue;
        image.setPixelRgb(x, y, lid.$1, lid.$2, lid.$3);
      }
    }
  }

  // Nose: a shadow at the tip and two nostrils, no outline.
  _fillEllipse(
    image,
    cx: cx,
    cy: eyeY + faceH * 0.20,
    rx: headRx * 0.15,
    ry: faceH * 0.045,
    color: skinShade,
  );
  for (final sign in const [-1, 1]) {
    _fillEllipse(
      image,
      cx: cx + sign * headRx * 0.085,
      cy: eyeY + faceH * 0.215,
      rx: headRx * 0.035,
      ry: faceH * 0.014,
      color: skinDeep,
    );
  }

  // A closed, neutral mouth — what every passport spec asks for.
  final mouthY = eyeY + faceH * 0.345;
  _fillEllipse(
    image,
    cx: cx,
    cy: mouthY,
    rx: headRx * 0.31,
    ry: faceH * 0.028,
    color: lip,
  );
  _fillEllipse(
    image,
    cx: cx,
    cy: mouthY,
    rx: headRx * 0.31,
    ry: faceH * 0.005,
    color: lipLine,
  );

  return Uint8List.fromList(img.encodeJpg(image, quality: 92));
}

void _fillEllipse(
  img.Image image, {
  required double cx,
  required double cy,
  required double rx,
  required double ry,
  required (int, int, int) color,
}) {
  final x0 = math.max(0, (cx - rx).floor());
  final x1 = math.min(image.width - 1, (cx + rx).ceil());
  final y0 = math.max(0, (cy - ry).floor());
  final y1 = math.min(image.height - 1, (cy + ry).ceil());
  for (var y = y0; y <= y1; y++) {
    for (var x = x0; x <= x1; x++) {
      final nx = (x - cx) / rx;
      final ny = (y - cy) / ry;
      if (nx * nx + ny * ny <= 1) {
        image.setPixelRgb(x, y, color.$1, color.$2, color.$3);
      }
    }
  }
}
