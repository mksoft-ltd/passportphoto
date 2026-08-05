/// A ruler for the crop.
///
/// [PhotoProcessor] reports nothing about where it cropped, and its crop
/// rectangle is private, so this measures the output the way a person would:
/// three coloured stripes are painted across the source at the crown, the eye
/// line and the chin, and afterwards it looks for them in the finished photo.
/// A stripe that is not in the output was cropped away.
///
/// Nothing here re-implements the crop maths, so the numbers it produces are
/// not a restatement of the code under test.
///
/// ML Kit is a platform channel and cannot run in the Dart VM, so the detector
/// is stubbed with a face whose geometry is stated up front — see
/// [SyntheticSubject]. Whether ML Kit's *real* box behaves the way the crop
/// assumes is a separate question, answered on a device by
/// `integration_test/crop_geometry_probe_test.dart`.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:passport_photo_app/core/models/photo_spec.dart';
import 'package:passport_photo_app/features/processing/face_detector_service.dart';
import 'package:passport_photo_app/features/processing/photo_processor.dart';
import 'package:passport_photo_app/features/processing/processed_photo.dart';

/// The head this harness photographs, in source-image pixels.
///
/// The numbers are chosen so that every one of the 30 bundled specs asks for a
/// crop that fits inside the source with room to spare. That matters: the
/// clamp in `_computeCropRect` silently rescues the framing when the requested
/// crop runs off the source, which would hide exactly what is being measured.
class SyntheticSubject {
  const SyntheticSubject({this.eyeLineWithinHead = harnessEye});

  /// Where this subject's eyes sit within their head, as a fraction of
  /// chin-to-crown measured down from the crown.
  ///
  /// This is the one property of a subject the framing solver takes as an
  /// input, so it is the one a golden has to vary. A suite that only ever
  /// measures [harnessEye] proves its property for a head shape that is not
  /// the head shape that ships.
  final double eyeLineWithinHead;

  /// The classical "eyes half way down the head" figure, which is also
  /// [HeadFraming.nominalEyeLineWithinHead] — the processor's own fallback when
  /// the detector returns no eye landmarks.
  static const double harnessEye = 0.45;

  /// What real ML Kit produced on all five reference portraits, measured on a
  /// booted iPhone 15 Pro simulator on 2026-08-05 by
  /// `integration_test/crop_geometry_probe_test.dart`. The observed range was
  /// 0.576-0.590; 0.59 is its top, so it is the demanding end of what ships.
  ///
  /// ML Kit's box sits lower on the face than the crown-to-chin span the app
  /// infers from it, which is why the real figure is so far from the classical
  /// 0.45 — the difference is a property of the detector, not of the faces.
  static const double realMlKitEye = 0.59;

  static const int sourceWidth = 2400;
  static const int sourceHeight = 3200;

  /// ML Kit's box height. The processor multiplies this by its own
  /// `headHeightFactor` to estimate chin-to-crown.
  static const double boxHeight = 600;
  static const double boxWidth = 520;

  /// The chin-to-crown height the processor will infer (1.45 x the box).
  static const double headHeight = boxHeight * 1.45;

  static const double chinY = 1770;
  static const double crownY = chinY - headHeight;
  static const double centreX = sourceWidth / 2;

  /// The row this subject's eyes are painted on.
  double get eyeY => crownY + eyeLineWithinHead * headHeight;

  Face get face => faceWith();

  /// The same subject with one thing changed, for driving a validation check.
  Face faceWith({
    double? leftEyeOpen,
    double? rightEyeOpen,
    double? yaw,
    double? roll,
    double? pitch,
    double heightScale = 1.0,
    double offsetX = 0,
    double offsetY = 0,
    bool withEyeLandmarks = true,
  }) {
    final h = boxHeight * heightScale;
    final w = boxWidth * heightScale;
    final cx = centreX + offsetX;
    final chinY = SyntheticSubject.chinY + offsetY;
    // Keep the eyes in the same place within the head however it is scaled:
    // [eyeLineWithinHead] of the way down the chin-to-crown span, from the
    // crown.
    final eyeRow =
        (chinY - h * 1.45) + eyeLineWithinHead * (h * 1.45);

    return Face(
      boundingBox: Rect.fromLTRB(cx - w / 2, chinY - h, cx + w / 2, chinY),
      landmarks: withEyeLandmarks
          ? {
              FaceLandmarkType.leftEye: FaceLandmark(
                type: FaceLandmarkType.leftEye,
                position: math.Point<int>(
                  (cx - w * 0.22).round(),
                  eyeRow.round(),
                ),
              ),
              FaceLandmarkType.rightEye: FaceLandmark(
                type: FaceLandmarkType.rightEye,
                position: math.Point<int>(
                  (cx + w * 0.22).round(),
                  eyeRow.round(),
                ),
              ),
            }
          : const {},
      contours: const {},
      headEulerAngleX: pitch ?? 0,
      headEulerAngleY: yaw ?? 0,
      headEulerAngleZ: roll ?? 0,
      leftEyeOpenProbability: leftEyeOpen ?? 0.99,
      rightEyeOpenProbability: rightEyeOpen ?? 0.99,
    );
  }
}

/// Where the head ended up, as fractions of the finished photo's height.
class HeadPlacement {
  const HeadPlacement({
    required this.crown,
    required this.eyeLine,
    required this.chin,
  });

  /// Null when the stripe is not in the output — the crown was cropped off the
  /// top, or the chin off the bottom.
  final double? crown;
  final double? eyeLine;
  final double? chin;

  bool get crownVisible => crown != null;
  bool get chinVisible => chin != null;

  /// Chin-to-crown as a fraction of the photo height. Null if either end was
  /// cropped away, because then there is nothing to measure.
  double? get faceHeightFraction =>
      crown == null || chin == null ? null : chin! - crown!;

  /// The eye line measured *up from the bottom edge*, which is how ICAO Doc
  /// 9303, UK HMPO and 22 CFR 51.604 all state it.
  double? get eyeLineFromBottom => eyeLine == null ? null : 1 - eyeLine!;

  @override
  String toString() => 'crown=${_f(crown)} eyes=${_f(eyeLine)} '
      'chin=${_f(chin)} (from bottom: ${_f(eyeLineFromBottom)})';

  static String _f(double? v) =>
      v == null ? 'CROPPED-OFF' : v.toStringAsFixed(3);
}

/// Runs the real [PhotoProcessor] against [spec] and measures the result.
///
/// [eyeLineWithinHead] selects the subject's head shape — see
/// [SyntheticSubject.harnessEye] and [SyntheticSubject.realMlKitEye].
Future<HeadPlacement> measureCrop(
  PhotoSpec spec, {
  double eyeLineWithinHead = SyntheticSubject.harnessEye,
}) async {
  final photo = await runProcessor(spec: spec, eyeLineWithinHead: eyeLineWithinHead);
  final out = img.decodeImage(photo.jpegBytes)!;
  return HeadPlacement(
    crown: _findStripe(out, _crownColour),
    eyeLine: _findStripe(out, _eyeColour),
    chin: _findStripe(out, _chinColour),
  );
}

/// Runs the real [PhotoProcessor] with a scripted detection.
///
/// [faces] defaults to the one well-behaved [SyntheticSubject]; pass others to
/// drive the validation checks — a second face, closed eyes, a turned head.
/// [sourceJpeg] defaults to the striped subject; pass one to drive the
/// background-uniformity check or to shrink the source until the crop runs off
/// its edge.
Future<ProcessedPhoto> runProcessor({
  required PhotoSpec spec,
  List<Face>? faces,
  Uint8List? sourceJpeg,
  double eyeLineWithinHead = SyntheticSubject.harnessEye,
}) async {
  final subject = SyntheticSubject(eyeLineWithinHead: eyeLineWithinHead);
  final dir = Directory.systemTemp.createTempSync('crop_harness');
  try {
    final sourcePath = '${dir.path}/subject.jpg';
    File(sourcePath).writeAsBytesSync(sourceJpeg ?? _paintSubject(subject));
    final processor = PhotoProcessor(
      StubFaceDetector(faces ?? [subject.face]),
    );
    return await processor.process(sourcePath: sourcePath, spec: spec);
  } finally {
    dir.deleteSync(recursive: true);
  }
}

/// The striped source [runProcessor] uses by default, for callers that want to
/// resize or repaint it.
Uint8List subjectJpeg({
  double eyeLineWithinHead = SyntheticSubject.harnessEye,
}) =>
    _paintSubject(SyntheticSubject(eyeLineWithinHead: eyeLineWithinHead));

/// Saturated primaries on a neutral field: they survive a cubic resample and a
/// quality-92 JPEG encode still distinguishable from one another.
const _crownColour = (r: 255, g: 0, b: 0);
const _eyeColour = (r: 0, g: 200, b: 0);
const _chinColour = (r: 0, g: 0, b: 255);

/// Paints the source: a plain field with a full-width stripe on each of the
/// three rows that matter.
///
/// Full width, because the crop is narrower than the source and centred on the
/// face — a stripe painted only in the margins would fall outside every crop
/// and read as "cropped off" for all of them. Nothing detects on this image,
/// so painting across the face costs nothing.
Uint8List _paintSubject(SyntheticSubject subject) {
  final image = img.Image(
    width: SyntheticSubject.sourceWidth,
    height: SyntheticSubject.sourceHeight,
  );
  img.fill(image, color: img.ColorRgb8(240, 240, 240));

  void stripe(double y, ({int r, int g, int b}) c) {
    final colour = img.ColorRgb8(c.r, c.g, c.b);
    for (var dy = -3; dy <= 3; dy++) {
      final row = y.round() + dy;
      if (row < 0 || row >= image.height) continue;
      for (var x = 0; x < image.width; x++) {
        image.setPixel(x, row, colour);
      }
    }
  }

  stripe(SyntheticSubject.crownY, _crownColour);
  stripe(subject.eyeY, _eyeColour);
  stripe(SyntheticSubject.chinY, _chinColour);

  return Uint8List.fromList(img.encodeJpg(image, quality: 92));
}

/// The row holding [want], as a fraction of the image height, or null when the
/// stripe is not present.
double? _findStripe(img.Image image, ({int r, int g, int b}) want) {
  int? bestRow;
  var bestScore = 0;
  for (var y = 0; y < image.height; y++) {
    var score = 0;
    for (var x = 0; x < image.width; x += 4) {
      final p = image.getPixel(x, y);
      if (_near(p.r.toInt(), want.r) &&
          _near(p.g.toInt(), want.g) &&
          _near(p.b.toInt(), want.b)) {
        score++;
      }
    }
    if (score > bestScore) {
      bestScore = score;
      bestRow = y;
    }
  }
  // Half the sampled pixels in the row, so a JPEG ringing artefact next to a
  // stripe cannot be mistaken for the stripe itself.
  final threshold = (image.width / 4) * 0.5;
  return bestScore >= threshold && bestRow != null
      ? bestRow / image.height
      : null;
}

bool _near(int actual, int target) => (actual - target).abs() < 70;

/// Stands in for ML Kit, which has no Dart VM implementation.
///
/// Also the way to keep a `ProviderContainer` disposable in a unit test: the
/// real `faceDetectorServiceProvider` closes a platform-channel detector when
/// the container is torn down, which throws a MissingPluginException off the
/// device.
class StubFaceDetector implements FaceDetectorService {
  StubFaceDetector([this._faces = const []]);
  final List<Face> _faces;

  @override
  Future<List<Face>> detectFromFile(String path) async => List.of(_faces);

  @override
  void dispose() {}
}
