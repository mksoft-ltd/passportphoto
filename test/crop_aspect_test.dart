/// The crop must never change the shape of the subject.
///
/// `renderProcessedPhoto` cuts a rectangle and then resizes it to exactly
/// `spec.widthPx x spec.heightPx`. That resize is a pure scale only while the
/// rectangle it is handed already has the spec's aspect ratio; hand it a
/// rectangle of any other shape and it stretches the face to fill the output.
///
/// Until 2026-09-19 an over-large crop was made to fit by truncating width and
/// height independently, which does exactly that. A 200 x 200 px square
/// painted on the source came back 138 x 133, and a landscape source with the
/// head filling it squeezed by 36%. None of the seven compliance checks could
/// see it: every one of them measures a position *within* the cut rectangle,
/// and a uniform stretch moves all of them together.
///
/// `test/crop_geometry_golden_test.dart` cannot catch this, by construction —
/// its subject is sized so that every bundled spec asks for a crop that fits
/// inside the source with room to spare, precisely so the clamp never fires.
/// This file exists to cover the other side of that line.
///
/// The measurement is a reference square painted on the source and found again
/// in the output, so nothing here restates the crop maths.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:passport_photo_app/core/models/photo_spec.dart';
import 'package:passport_photo_app/features/processing/photo_processor.dart';
import 'package:passport_photo_app/features/processing/processed_photo.dart';

import 'support/specs.dart';

/// A source image with a square reference mark centred on the face.
///
/// The mark is deliberately square: whatever the crop and resize do, a square
/// that is still square in the output proves the transform was a uniform
/// scale, and its measured width:height ratio is the distortion factor.
({String path, int markSize}) _sourceWithSquareMark({
  required int width,
  required int height,
}) {
  final src = img.Image(width: width, height: height);
  img.fill(src, color: img.ColorRgb8(200, 200, 200));
  final cx = width ~/ 2;
  final cy = height ~/ 2;
  const half = 50; // a 100 x 100 mark
  img.fillRect(
    src,
    x1: cx - half,
    y1: cy - half,
    x2: cx + half - 1,
    y2: cy + half - 1,
    color: img.ColorRgb8(255, 0, 0),
  );
  final file = File(
    '${Directory.systemTemp.path}/crop_aspect_${width}x$height.png',
  )..writeAsBytesSync(img.encodePng(src));
  return (path: file.path, markSize: half * 2);
}

FaceMeasurement _faceFilling({
  required int sourceWidth,
  required int sourceHeight,
  required double boxWidth,
  required double boxHeight,
}) {
  final cx = sourceWidth / 2;
  final cy = sourceHeight / 2;
  return FaceMeasurement(
    boxLeft: cx - boxWidth / 2,
    boxTop: cy - boxHeight / 2,
    boxWidth: boxWidth,
    boxHeight: boxHeight,
    leftEyeY: cy,
    rightEyeY: cy,
    yaw: 0,
    roll: 0,
    pitch: 0,
    leftEyeOpenProbability: 1,
    rightEyeOpenProbability: 1,
  );
}

/// Width:height of the reference mark as it appears in [photo]. 1.0 means the
/// subject came through undistorted.
double _markAspect(ProcessedPhoto photo) {
  final out = img.decodeImage(photo.jpegBytes)!;
  var minX = 1 << 30, maxX = -1, minY = 1 << 30, maxY = -1;
  for (var y = 0; y < out.height; y++) {
    for (var x = 0; x < out.width; x++) {
      final p = out.getPixel(x, y);
      // JPEG at quality 92 softens the edges; the mark is the only saturated
      // red in the picture, so a loose threshold finds it without finding
      // anything else.
      if (p.r > 150 && p.g < 90 && p.b < 90) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  expect(maxX, greaterThanOrEqualTo(0),
      reason: 'the reference mark was cropped away entirely');
  return (maxX - minX + 1) / (maxY - minY + 1);
}

void main() {
  final uk = PhotoSpec.fromJson(ukPassportJson); // 35 x 45 mm
  final us = PhotoSpec.fromJson(usPassportJson); // 51 x 51 mm

  /// One output pixel of slack on a ~100 px mark, doubled to cover both edges.
  /// Anything a person could see is far outside this.
  const tolerance = 0.03;

  group('a square subject stays square', () {
    test('portrait source, head filling the frame', () {
      final src = _sourceWithSquareMark(width: 1200, height: 1600);
      final photo = renderProcessedPhoto(
        sourcePath: src.path,
        spec: uk,
        face: _faceFilling(
          sourceWidth: 1200,
          sourceHeight: 1600,
          boxWidth: 700,
          boxHeight: 900,
        ),
        extraFaces: 0,
      );
      expect(_markAspect(photo), closeTo(1.0, tolerance));
    });

    test('landscape source, head filling the frame — was a 36% squeeze', () {
      final src = _sourceWithSquareMark(width: 1600, height: 1200);
      final photo = renderProcessedPhoto(
        sourcePath: src.path,
        spec: uk,
        face: _faceFilling(
          sourceWidth: 1600,
          sourceHeight: 1200,
          boxWidth: 700,
          boxHeight: 900,
        ),
        extraFaces: 0,
      );
      expect(_markAspect(photo), closeTo(1.0, tolerance));
    });

    test('landscape source, square spec', () {
      final src = _sourceWithSquareMark(width: 1600, height: 1200);
      final photo = renderProcessedPhoto(
        sourcePath: src.path,
        spec: us,
        face: _faceFilling(
          sourceWidth: 1600,
          sourceHeight: 1200,
          boxWidth: 500,
          boxHeight: 650,
        ),
        extraFaces: 0,
      );
      expect(_markAspect(photo), closeTo(1.0, tolerance));
    });

    test('a comfortably-framed subject is unaffected', () {
      final src = _sourceWithSquareMark(width: 2400, height: 3200);
      final photo = renderProcessedPhoto(
        sourcePath: src.path,
        spec: uk,
        face: _faceFilling(
          sourceWidth: 2400,
          sourceHeight: 3200,
          boxWidth: 520,
          boxHeight: 600,
        ),
        extraFaces: 0,
      );
      expect(_markAspect(photo), closeTo(1.0, tolerance));
    });
  });

  group('the output still matches the spec exactly', () {
    test('an over-large crop still produces spec pixel dimensions', () {
      final src = _sourceWithSquareMark(width: 1600, height: 1200);
      final photo = renderProcessedPhoto(
        sourcePath: src.path,
        spec: uk,
        face: _faceFilling(
          sourceWidth: 1600,
          sourceHeight: 1200,
          boxWidth: 700,
          boxHeight: 900,
        ),
        extraFaces: 0,
      );
      expect(photo.widthPx, uk.widthPx);
      expect(photo.heightPx, uk.heightPx);
    });
  });

  group('the user is told', () {
    test('a subject too close to fit fails "Photo fully captured"', () {
      final src = _sourceWithSquareMark(width: 1600, height: 1200);
      final photo = renderProcessedPhoto(
        sourcePath: src.path,
        spec: uk,
        face: _faceFilling(
          sourceWidth: 1600,
          sourceHeight: 1200,
          boxWidth: 700,
          boxHeight: 900,
        ),
        extraFaces: 0,
      );
      final captured =
          photo.checks.firstWhere((c) => c.label == 'Photo fully captured');
      expect(captured.passed, isFalse,
          reason: 'shrinking the crop to fit must not silently pass the check '
              'that exists to say the shot needs retaking');
    });
  });
}
