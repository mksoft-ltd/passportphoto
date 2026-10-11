import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

import '../../core/models/photo_spec.dart';
import 'face_detector_service.dart';
import 'head_framing.dart';
import 'processed_photo.dart';

class PhotoProcessingFailure implements Exception {
  PhotoProcessingFailure(this.message);
  final String message;
  @override
  String toString() => 'PhotoProcessingFailure: $message';
}

/// Everything the crop and the compliance checks need from ML Kit, as plain
/// numbers.
///
/// A [Face] cannot cross an isolate boundary — and neither can the
/// [PhotoProcessor] that produced it, which holds a platform-channel detector.
/// Reducing the detection to doubles here is what lets the whole image pipeline
/// run off the UI isolate.
class FaceMeasurement {
  const FaceMeasurement({
    required this.boxLeft,
    required this.boxTop,
    required this.boxWidth,
    required this.boxHeight,
    required this.leftEyeY,
    required this.rightEyeY,
    required this.yaw,
    required this.roll,
    required this.pitch,
    required this.leftEyeOpenProbability,
    required this.rightEyeOpenProbability,
    required this.smilingProbability,
  });

  factory FaceMeasurement.fromFace(Face face) {
    final box = face.boundingBox;
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];
    return FaceMeasurement(
      boxLeft: box.left,
      boxTop: box.top,
      boxWidth: box.width,
      boxHeight: box.height,
      leftEyeY: leftEye?.position.y.toDouble(),
      rightEyeY: rightEye?.position.y.toDouble(),
      yaw: face.headEulerAngleY ?? 0,
      roll: face.headEulerAngleZ ?? 0,
      pitch: face.headEulerAngleX ?? 0,
      leftEyeOpenProbability: face.leftEyeOpenProbability ?? 1.0,
      rightEyeOpenProbability: face.rightEyeOpenProbability ?? 1.0,
      // Null when the detector declines to classify. Treated as not smiling,
      // so a detector that cannot tell never fails the photograph.
      smilingProbability: face.smilingProbability ?? 0.0,
    );
  }

  final double boxLeft;
  final double boxTop;
  final double boxWidth;
  final double boxHeight;

  /// Eye landmark rows, null when the detector did not return them.
  final double? leftEyeY;
  final double? rightEyeY;

  final double yaw;
  final double roll;
  final double pitch;
  final double leftEyeOpenProbability;
  final double rightEyeOpenProbability;

  /// ML Kit's own confidence that the subject is smiling, 0-1.
  final double smilingProbability;

  double get boxBottom => boxTop + boxHeight;
  double get boxCentreX => boxLeft + boxWidth / 2.0;

  /// Midpoint of the two eye landmarks, or null when either is missing.
  double? get eyeMidpointY => leftEyeY == null || rightEyeY == null
      ? null
      : (leftEyeY! + rightEyeY!) / 2.0;

  double get boxArea => boxWidth * boxHeight;
}

/// Pipeline:
///   1. Run ML Kit face detection (platform channel, off-thread already)
///   2. Reduce the detection to plain numbers
///   3. Everything else — decode, EXIF bake, crop, resample, validate, encode —
///      in a background isolate
class PhotoProcessor {
  PhotoProcessor(this._faceDetector);

  final FaceDetectorService _faceDetector;

  Future<ProcessedPhoto> process({
    required String sourcePath,
    required PhotoSpec spec,
  }) async {
    final faces = await _faceDetector.detectFromFile(sourcePath);

    if (faces.isEmpty) {
      throw PhotoProcessingFailure(
        'No face detected. Make sure your face is clearly visible and well-lit.',
      );
    }

    // Pick the largest face (in case of stray detections).
    faces.sort((a, b) {
      final aArea = a.boundingBox.width * a.boundingBox.height;
      final bArea = b.boundingBox.width * b.boundingBox.height;
      return bArea.compareTo(aArea);
    });
    final face = FaceMeasurement.fromFace(faces.first);
    final extraFaces = faces.length - 1;

    // Decode, bake, crop, cubic-resample and JPEG-encode a full-resolution
    // camera still: measured at 679 ms on an Apple Silicon Mac and roughly
    // 1.5-3 s on a phone. On the UI isolate that is a frozen frame, not a
    // loading state — the result screen's spinner cannot animate through it.
    //
    // The closure below captures only plain data, exactly as [buildPrintSheet]
    // does two methods down, so it never drags the platform-channel detector
    // across the boundary.
    return Isolate.run(
      () => renderProcessedPhoto(
        sourcePath: sourcePath,
        spec: spec,
        face: face,
        extraFaces: extraFaces,
      ),
    );
  }

  /// Tile copies of [photo] onto a 4x6" sheet at 300 DPI. Returns JPEG bytes.
  ///
  /// The 1800×1200 composite is heavy enough to drop frames, so it runs off the
  /// UI isolate. [renderPrintSheet] is top-level precisely so the closure below
  /// captures nothing but plain data — this object holds a platform-channel
  /// face detector, which is not sendable.
  Future<Uint8List> buildPrintSheet(ProcessedPhoto photo) {
    final bytes = photo.jpegBytes;
    final widthMm = photo.spec.widthMm;
    final heightMm = photo.spec.heightMm;
    return Isolate.run(
      () => renderPrintSheet(bytes, widthMm: widthMm, heightMm: heightMm),
    );
  }
}

/// The whole image pipeline, as a pure function of plain data.
///
/// Top-level and free of any reference to [PhotoProcessor] so it is safe to run
/// in a background isolate. Also the reason the crop and the checks can be
/// tested without a detector.
ProcessedPhoto renderProcessedPhoto({
  required String sourcePath,
  required PhotoSpec spec,
  required FaceMeasurement face,
  required int extraFaces,
}) {
  // bakeOrientation rotates pixels per EXIF so coordinates match what ML Kit
  // saw.
  final raw = File(sourcePath).readAsBytesSync();
  img.Image? decoded;
  try {
    decoded = img.decodeImage(raw);
  } catch (_) {
    // A truncated or part-downloaded file makes `decodeImage` throw — usually
    // a RangeError — rather than return null. The result screen prints
    // whatever comes out of here verbatim, so an uncaught one shows the user
    // a Dart error string. Reachable from the gallery picker.
    decoded = null;
  }
  if (decoded == null) {
    throw PhotoProcessingFailure('Could not decode the selected image.');
  }
  final source = img.bakeOrientation(decoded);

  final cropResult = _computeCropRect(
    face: face,
    sourceWidth: source.width,
    sourceHeight: source.height,
    spec: spec,
  );

  // Crop, then resize to the exact spec pixel dimensions.
  final cropped = img.copyCrop(
    source,
    x: cropResult.cropRect.left,
    y: cropResult.cropRect.top,
    width: cropResult.cropRect.width,
    height: cropResult.cropRect.height,
  );

  final resized = img.copyResize(
    cropped,
    width: spec.widthPx,
    height: spec.heightPx,
    interpolation: img.Interpolation.cubic,
  );

  final checks = _runValidations(
    face: face,
    extraFaces: extraFaces,
    cropResult: cropResult,
    resized: resized,
    spec: spec,
  );

  final jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: 92));

  return ProcessedPhoto(
    spec: spec,
    jpegBytes: jpeg,
    widthPx: resized.width,
    heightPx: resized.height,
    checks: checks,
  );
}

// ---- Cropping -----------------------------------------------------------

_CropResult _computeCropRect({
  required FaceMeasurement face,
  required int sourceWidth,
  required int sourceHeight,
  required PhotoSpec spec,
}) {
  // ML Kit's bounding box covers most of the face but stops short of the hair
  // above it, so it has to be extended to reach the crown.
  //
  // Measured against the five reference portraits in `test_fixtures/`: the top
  // of the hair sat at least 1.27 box-heights above the box bottom on every
  // one, and every fixture has the hair running off its own top edge, so that
  // figure is a lower bound. 1.45 keeps a deliberate allowance above it —
  // over-estimating the head widens the crop and costs a little face height,
  // while under-estimating it shaves the top of someone's hair off, which is a
  // rejection.
  const headHeightFactor = 1.45;
  final headHeight = face.boxHeight * headHeightFactor;

  // Estimate the chin and crown Y positions.
  final chinY = face.boxBottom;
  final crownY = chinY - headHeight;

  // Estimate the eye-line Y. Prefer landmark midpoint when available.
  final eyeY = face.eyeMidpointY ??
      (crownY + HeadFraming.nominalEyeLineWithinHead * headHeight);

  // How far down this particular head the eyes fall. Passing the measured
  // value to the framing solver is what lets it keep the crown in frame for a
  // subject with a tall forehead as well as one without.
  final eyeLineWithinHead = (eyeY - crownY) / headHeight;
  final framing = HeadFraming.forSpec(
    spec,
    eyeLineWithinHead: eyeLineWithinHead,
  );

  // The output crop should have:
  //   chinToCrown / cropHeight == framing.faceHeightFraction
  //   (eyeY - cropTop) / cropHeight == framing.eyeLineFromTopFraction
  final cropHeight = headHeight / framing.faceHeightFraction;
  final cropWidth = cropHeight * spec.aspectRatio;

  // The rectangle that gets cut has to keep the spec's aspect ratio, because
  // the resize afterwards forces the output to `spec.widthPx × spec.heightPx`
  // whatever shape arrives. Truncating an over-large crop one axis at a time
  // — which is what this did until 2026-09-19 — changes that shape, and the
  // resize then stretches the face to fill it: a 200 × 200 px square painted
  // on the source came back 138 × 133, and a landscape source with the head
  // filling it squeezed by 36% (both measured; the goldens in
  // `test/crop_aspect_test.dart` are those cases). A geometrically distorted
  // face is refused at the counter, and nothing in the report named it,
  // because every check measures positions within the cut rectangle and a
  // uniform stretch leaves all of them where they were.
  //
  // So when the requested crop does not fit, it is scaled down *uniformly* to
  // the largest rectangle of the same shape that does. The head then fills
  // more of the frame than the spec allows, which is a true statement about
  // the photograph and which the face-size check reports on its own.
  final fitScale = math.min(
    1.0,
    math.min(sourceWidth / cropWidth, sourceHeight / cropHeight),
  );
  final fittedWidth = cropWidth * fitScale;
  final fittedHeight = cropHeight * fitScale;

  // Placed against the rectangle that will actually be cut, so the eye line
  // lands at the intended fraction of it even when the shrink above fired.
  final cropTop = eyeY - framing.eyeLineFromTopFraction * fittedHeight;

  // Centre horizontally on the face midpoint.
  final cropLeft = face.boxCentreX - fittedWidth / 2.0;

  // Clamp so we never read pixels outside the source image.
  final left = cropLeft.clamp(0.0, sourceWidth - fittedWidth);
  final top = cropTop.clamp(0.0, sourceHeight - fittedHeight);

  int rectWidth = math.max(1, math.min(fittedWidth.round(), sourceWidth));
  int rectHeight = math.max(1, math.min(fittedHeight.round(), sourceHeight));

  // Rounding to whole pixels can push an edge past the source. Move the
  // origin rather than trimming a side: trimming is the aspect-ratio bug
  // above in miniature, and the rect is known to fit at this size.
  int rectLeft = left.round().clamp(0, sourceWidth - rectWidth);
  int rectTop = top.round().clamp(0, sourceHeight - rectHeight);

  final rect = _IntRect(
    left: rectLeft,
    top: rectTop,
    width: rectWidth,
    height: rectHeight,
  );

  // Everything below is measured against the rectangle actually cut, not
  // against the one that was asked for. The two differ whenever the clamps
  // above fired or the rounding to whole pixels moved an edge, and it is the
  // rectangle that was cut which ends up in front of a passport clerk. The
  // resize afterwards is a pure scale, so these fractions survive it.
  final cutTop = rectTop.toDouble();
  final cutHeight = rectHeight.toDouble();

  return _CropResult(
    cropRect: rect,
    faceHeightFraction: headHeight / cutHeight,
    crownFraction: (crownY - cutTop) / cutHeight,
    chinFraction: (chinY - cutTop) / cutHeight,
    eyeLineFromBottomFraction: (cutTop + cutHeight - eyeY) / cutHeight,
    // `fitScale` below 1 means the requested crop was larger than the source
    // in at least one axis, which is the same failure to capture the picture
    // as running off an edge — the subject is too close — and has to be
    // reported even when the shrunken rectangle then sits inside the source.
    croppedToBoundary: fitScale < 1.0 || cropLeft != left || cropTop != top,
    honoursSpecEyeLine: framing.honoursSpecEyeLine,
  );
}

// ---- Validation ---------------------------------------------------------

List<ValidationCheck> _runValidations({
  required FaceMeasurement face,
  required int extraFaces,
  required _CropResult cropResult,
  required img.Image resized,
  required PhotoSpec spec,
}) {
  final checks = <ValidationCheck>[];

  // 1. Single face
  checks.add(ValidationCheck(
    kind: CheckKind.singleFace,
    label: 'Single face detected',
    passed: extraFaces == 0,
    detail: extraFaces == 0
        ? 'Exactly one face found in frame.'
        : '${extraFaces + 1} faces found. Only one person should be in the photo.',
  ));

  // 2. Eyes open
  final leftP = face.leftEyeOpenProbability;
  final rightP = face.rightEyeOpenProbability;
  final eyesOpen = leftP > 0.6 && rightP > 0.6;
  checks.add(ValidationCheck(
    kind: CheckKind.eyesOpen,
    label: 'Eyes open',
    passed: eyesOpen,
    detail: eyesOpen
        ? 'Both eyes are clearly open.'
        : 'One or both eyes look closed (L: ${(leftP * 100).round()}%, R: ${(rightP * 100).round()}%).',
  ));

  // 3. Looking forward — Euler angles small
  final yaw = face.yaw;
  final roll = face.roll;
  final pitch = face.pitch;
  final lookingForward = yaw.abs() < 12 && roll.abs() < 8 && pitch.abs() < 12;
  checks.add(ValidationCheck(
    kind: CheckKind.lookingForward,
    label: 'Looking forward',
    passed: lookingForward,
    detail: lookingForward
        ? 'Head is centered and facing the camera.'
        : 'Adjust head position (yaw ${yaw.toStringAsFixed(1)}°, '
            'roll ${roll.toStringAsFixed(1)}°, pitch ${pitch.toStringAsFixed(1)}°).',
  ));

  // 3b. Neutral expression.
  //
  // Every bundled spec asks for this in its notes — "neutral expression",
  // "no smiling, mouth closed" — and ML Kit has returned a smiling
  // probability on every detection since the app shipped. It was read into
  // `FaceMeasurement`'s neighbours and never used, so the one expression rule
  // the detector can actually judge went unreported.
  //
  // 0.55 rather than 0.5: a closed-mouth pleasant face scores a little above
  // a deadpan one, and failing that would be wrong. What this catches is a
  // visible smile, which is what gets photographs refused.
  final smiling = face.smilingProbability > 0.55;
  checks.add(ValidationCheck(
    kind: CheckKind.neutralExpression,
    label: 'Neutral expression',
    passed: !smiling,
    detail: smiling
        ? 'You look like you are smiling '
            '(${(face.smilingProbability * 100).round()}% confidence). '
            'Document photos need a neutral expression with your mouth closed.'
        : 'Neutral expression, mouth closed.',
  ));

  // 4. Face size within spec range, measured from the detected head against
  // the rectangle that was actually cut. Dividing by the requested crop
  // height instead would restate the number the crop was built from and pass
  // unconditionally, which is how a crop that put the chin off the bottom
  // edge for 19 specs still reported six green checks.
  final faceFracMin = spec.faceHeightMinFraction;
  final faceFracMax = spec.faceHeightMaxFraction;
  // One output pixel of slack. The crop rectangle is whole pixels, so a head
  // asked to be exactly the smallest legal size lands a fraction of a pixel
  // either side of it; that is a rounding artefact, not a photo an office
  // would turn away.
  final tolerance = 1.0 / spec.heightPx;
  final faceOk = cropResult.faceHeightFraction >= faceFracMin - tolerance &&
      cropResult.faceHeightFraction <= faceFracMax + tolerance;
  checks.add(ValidationCheck(
    kind: CheckKind.faceSize,
    label: 'Face size within spec',
    passed: faceOk,
    detail: faceOk
        ? 'Face fills ${(cropResult.faceHeightFraction * 100).toStringAsFixed(0)}% '
            'of photo height (target ${(faceFracMin * 100).round()}-${(faceFracMax * 100).round()}%).'
        : 'Face fills ${(cropResult.faceHeightFraction * 100).toStringAsFixed(0)}% '
            'of photo height — should be ${(faceFracMin * 100).round()}-${(faceFracMax * 100).round()}%.',
  ));

  // 5. Eye line within the spec's band, measured up from the bottom edge on
  // the rectangle that was actually cut.
  //
  // This is the second of the two rules every issuing authority publishes, and
  // until 2026-08-05 the report was silent about it while the app was already
  // measuring it — a crop framed outside the band still reported every check
  // green. `honoursSpecEyeLine` separates the two ways of missing: a subject
  // the framing could not place, and a spec whose own head-height and eye-line
  // bands cannot both be satisfied by a head of this shape. The wording has to
  // be different, because only one of them is something the user can fix.
  final eyeFrac = cropResult.eyeLineFromBottomFraction;
  final eyeMinFrac = spec.eyeLineFromBottomMinFraction;
  final eyeMaxFrac = spec.eyeLineFromBottomMaxFraction;
  final eyeOk =
      eyeFrac >= eyeMinFrac - tolerance && eyeFrac <= eyeMaxFrac + tolerance;
  final eyeMm = (eyeFrac * spec.heightMm).toStringAsFixed(1);
  final bandMm = '${_mm(spec.eyeLineFromBottomMinMm)}-'
      '${_mm(spec.eyeLineFromBottomMaxMm)}mm';
  final String eyeDetail;
  if (eyeOk) {
    eyeDetail = 'Eyes sit ${eyeMm}mm above the bottom edge (target $bandMm).';
  } else if (!cropResult.honoursSpecEyeLine) {
    eyeDetail = 'Eyes sit ${eyeMm}mm above the bottom edge; this document asks '
        'for $bandMm. Its head-height rule '
        '(${_mm(spec.faceHeightMinMm)}-${_mm(spec.faceHeightMaxMm)}mm) and its '
        'eye-line rule cannot both be met for a face of this shape, so head '
        'height — the rule offices measure — was kept in spec.';
  } else {
    eyeDetail = 'Eyes sit ${eyeMm}mm above the bottom edge — should be '
        '$bandMm. Hold the camera at eye level, keep your head upright, and '
        're-shoot.';
  }
  checks.add(ValidationCheck(
    kind: CheckKind.eyeLine,
    label: 'Eye line within spec',
    passed: eyeOk,
    detail: eyeDetail,
  ));

  // 6. Background: plain, light, and free of a colour cast.
  //
  // Until 2026-09-19 this measured evenness and nothing else — the mean colour
  // was computed and thrown away — so the one thing the spec actually states
  // about the background was never tested. A subject photographed against an
  // evenly-lit black or deep red wall was told the background was fine.
  //
  // The thresholds only catch a wall no authority would accept, deliberately.
  // "Plain light-coloured" (UK), "white or off-white" (US) and "light grey"
  // (Germany) are different rules, and a check tight enough to tell them apart
  // would fail correct photographs over the white balance of the room. So
  // brightness and colour cast are judged, the spec's own requirement is
  // quoted either way, and the user is left to match the shade.
  final bg = _measureBackground(resized);
  final bgUniform = bg.stdDev < 18;
  final bgLight = bg.meanLum >= 170;
  final bgNeutral = bg.chroma <= 0.18;
  final bgOk = bgUniform && bgLight && bgNeutral;
  final wanted = spec.background.label.toLowerCase();
  // Sentence case for the branches that open with it.
  final wantedCap =
      spec.background.label[0].toUpperCase() + wanted.substring(1);
  final String bgDetail;
  if (bgOk) {
    bgDetail = 'Plain, evenly-lit light background. '
        'This document asks for $wanted — check the shade matches.';
  } else if (!bgUniform) {
    // Reported before brightness and colour: a shadow or an object behind the
    // subject drags the mean around too, so "uneven" is both the more
    // specific diagnosis and the one that has to be fixed first.
    bgDetail = 'The background is uneven (variance '
        '${bg.stdDev.toStringAsFixed(1)}) — a shadow, a gradient or an object '
        'behind you. Use a plain wall and even lighting.';
  } else if (!bgLight) {
    bgDetail = 'The background is too dark (brightness '
        '${bg.meanLum.round()}/255). $wantedCap is required — shoot against a '
        'plain, well-lit wall.';
  } else if (!bgNeutral) {
    bgDetail = 'The background has a colour cast '
        '(${(bg.chroma * 100).round()}% saturation). $wantedCap is required — '
        'use a plain wall without strong colour.';
  } else {
    // Unreachable: bgOk is the conjunction of the three above.
    bgDetail = 'The background does not meet this document\'s requirement '
        '($wanted).';
  }
  checks.add(ValidationCheck(
    kind: CheckKind.background,
    label: 'Background',
    passed: bgOk,
    detail: bgDetail,
  ));

  // 7. The whole head made it into the photo, and the crop it came from fit
  // inside the source. Both are ways of failing to capture the picture, and
  // the second is what causes the first, so they are reported together.
  final headInside = cropResult.headInsideFrame;
  checks.add(ValidationCheck(
    kind: CheckKind.fullyCaptured,
    label: 'Photo fully captured',
    passed: !cropResult.croppedToBoundary && headInside,
    detail: !headInside
        ? (cropResult.chinFraction > 1
            ? 'The chin falls below the bottom edge of the photo. '
                'Move further from the camera and re-shoot.'
            : 'The top of the head is above the top edge of the photo. '
                'Leave more space above your head and re-shoot.')
        : cropResult.croppedToBoundary
            ? 'The required crop ran past the edge of the source photo. '
                'Move further from the camera and re-shoot.'
            : 'Whole head in frame, and the crop fits within the source.',
  ));

  return checks;
}

/// Millimetre figures read as measurements, not as floats: 22.5 stays 22.5,
/// 28.0 reads as 28.
String _mm(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// Measures the wall behind the subject, from the two upper corners.
///
/// The region matters more than the statistics. This used to sample the whole
/// width of the top 10% of rows, on the stated grounds that it was "reliably
/// background (above the head)" — but [HeadFraming.crownMargin] is 0.04, so a
/// correctly framed head's crown sits as close as 4% from the top edge and the
/// bottom half of that window is hair. The measurement was of hair against
/// wall, not of wall, and it inverted the check: a white wall behind dark hair
/// read as variance 77 and *failed*, while a black wall behind dark hair read
/// as variance 4 and *passed*. Both measured on synthetic subjects; see
/// `test/background_check_test.dart`.
///
/// The head is centred and, across the bundled specs, spans roughly the middle
/// two thirds of the width, so the outer eighth of each side stays wall even
/// when the crown is at its highest. Shoulders arrive well below the top
/// quarter.
_BackgroundStats _measureBackground(img.Image image) {
  final bandWidth = math.max(1, (image.width * 0.12).round());
  final bandHeight = math.max(1, (image.height * 0.25).round());
  final xStride = math.max(1, bandWidth ~/ 10);
  final yStride = math.max(1, bandHeight ~/ 12);

  final lums = <double>[];
  double sumR = 0, sumG = 0, sumB = 0;

  void sample(int x, int y) {
    final p = image.getPixel(x, y);
    sumR += p.r;
    sumG += p.g;
    sumB += p.b;
    // BT.601 luminance.
    lums.add(0.299 * p.r + 0.587 * p.g + 0.114 * p.b);
  }

  for (int y = 0; y < bandHeight; y += yStride) {
    for (int x = 0; x < bandWidth; x += xStride) {
      sample(x, y);
      final right = image.width - 1 - x;
      if (right > x) sample(right, y);
    }
  }

  if (lums.isEmpty) {
    return const _BackgroundStats(
        meanR: 0, meanG: 0, meanB: 0, meanLum: 0, stdDev: 0);
  }
  final n = lums.length;
  final meanLum = lums.reduce((a, b) => a + b) / n;
  double variance = 0;
  for (final s in lums) {
    final d = s - meanLum;
    variance += d * d;
  }
  variance /= n;
  return _BackgroundStats(
    meanR: sumR / n,
    meanG: sumG / n,
    meanB: sumB / n,
    meanLum: meanLum,
    stdDev: math.sqrt(variance),
  );
}

// ---- Print sheet (4x6 inch) --------------------------------------------

/// Pure renderer for the 4×6" sheet. Safe to run in a background isolate.
Uint8List renderPrintSheet(
  Uint8List jpegBytes, {
  required double widthMm,
  required double heightMm,
}) {
  const sheetDpi = 300;
  const sheetWidthPx = 6 * sheetDpi; // 1800 px
  const sheetHeightPx = 4 * sheetDpi; // 1200 px
  const margin = 30;
  const gap = 20;

  // Runs in a background isolate, so an escaped decode error surfaces without
  // anything to attribute it to. `decodeImage` throws rather than returning
  // null on a truncated file, so both outcomes are funnelled into the same
  // reported failure.
  img.Image? source;
  try {
    source = img.decodeImage(jpegBytes);
  } catch (_) {
    source = null;
  }
  if (source == null) {
    throw PhotoProcessingFailure(
      'Could not decode processed photo for print sheet.',
    );
  }

  // Scale each tile so its physical size matches the spec mm @ 300dpi.
  final tileW = (widthMm / 25.4 * sheetDpi).round();
  final tileH = (heightMm / 25.4 * sheetDpi).round();
  final tile = img.copyResize(source, width: tileW, height: tileH);

  final sheet = img.Image(width: sheetWidthPx, height: sheetHeightPx);
  img.fill(sheet, color: img.ColorRgb8(255, 255, 255));

  final cols = ((sheetWidthPx - 2 * margin + gap) ~/ (tileW + gap));
  final rows = ((sheetHeightPx - 2 * margin + gap) ~/ (tileH + gap));

  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      final x = margin + c * (tileW + gap);
      final y = margin + r * (tileH + gap);
      img.compositeImage(sheet, tile, dstX: x, dstY: y);
    }
  }

  return Uint8List.fromList(img.encodeJpg(sheet, quality: 92));
}

class _IntRect {
  const _IntRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
  final int left;
  final int top;
  final int width;
  final int height;
}

/// Where the head ended up in the rectangle that was actually cut, as fractions
/// of that rectangle's height.
class _CropResult {
  _CropResult({
    required this.cropRect,
    required this.faceHeightFraction,
    required this.crownFraction,
    required this.chinFraction,
    required this.eyeLineFromBottomFraction,
    required this.croppedToBoundary,
    required this.honoursSpecEyeLine,
  });
  final _IntRect cropRect;
  final double faceHeightFraction;

  /// Crown position measured down from the top edge. Negative means the top of
  /// the head is outside the photo.
  final double crownFraction;

  /// Chin position measured down from the top edge. Above 1 means the chin is
  /// below the bottom edge.
  final double chinFraction;

  /// Eye line measured up from the bottom edge, the convention every issuing
  /// authority states it in.
  final double eyeLineFromBottomFraction;

  final bool croppedToBoundary;

  /// False when the framing solver could not put the eye line inside the
  /// spec's own band without pushing the head off an edge — i.e. the spec's two
  /// published rules contradict each other for a head of this shape.
  final bool honoursSpecEyeLine;

  bool get headInsideFrame => crownFraction >= 0 && chinFraction <= 1;
}

class _BackgroundStats {
  const _BackgroundStats({
    required this.meanR,
    required this.meanG,
    required this.meanB,
    required this.meanLum,
    required this.stdDev,
  });
  final double meanR;
  final double meanG;
  final double meanB;

  /// Mean BT.601 luminance, 0-255. The brightness half of "plain light
  /// background" — the rule every authority in `assets/specs/SOURCES.md`
  /// states in some form.
  final double meanLum;

  /// Spread of luminance across the sampled wall. High means a shadow, a
  /// gradient or an object, not a plain wall.
  final double stdDev;

  /// How far the wall is from neutral grey, as a fraction of its own
  /// brightest channel — HSV saturation of the mean colour.
  ///
  /// This is what separates a cream wall (about 0.05, fine everywhere) and a
  /// light blue one (about 0.11) from a painted feature wall. It is a ratio
  /// rather than an absolute channel spread so that it does not tighten as the
  /// photo gets darker.
  double get chroma {
    final maxC = math.max(meanR, math.max(meanG, meanB));
    final minC = math.min(meanR, math.min(meanG, meanB));
    return maxC <= 0 ? 0 : (maxC - minC) / maxC;
  }
}
