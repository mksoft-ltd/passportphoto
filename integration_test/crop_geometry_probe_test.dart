import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:passport_photo_app/core/models/photo_spec.dart';
import 'package:passport_photo_app/features/processing/face_detector_service.dart';
import 'package:passport_photo_app/features/processing/photo_processor.dart';

/// Measures, on a real device running real ML Kit, where the crown and the chin
/// actually land inside a photo produced by the shipping [PhotoProcessor].
///
/// This is a *measuring instrument*, not a pass/fail gate: it asserts only that
/// it managed to take a measurement, and prints the numbers. The expectations
/// live in `test/crop_geometry_golden_test.dart`, which runs headless. This
/// exists because that headless test has to fabricate the [Face] the detector
/// would have returned, and a fabricated face cannot tell you whether ML Kit's
/// real bounding box and landmarks behave the way the crop maths assumes.
///
/// It needs a device because `google_mlkit_face_detection` is a platform
/// channel — there is no ML Kit in the Dart VM.
///
/// ```
/// flutter test integration_test/crop_geometry_probe_test.dart \
///   -d <simulator id> \
///   --dart-define=REPO_ROOT=/abs/path/to/passport_photo_app \
///   --dart-define=PROBE_DIR=/abs/path/to/passport_photo_app/build/crop_probe
/// ```
///
/// Fixtures come from `test_fixtures/portraits/` — generated faces, no real
/// person; see PROVENANCE.md there. They are read by absolute host path rather
/// than bundled as Flutter assets, so no build of the app ever carries a face
/// photograph. That works on the iOS Simulator, which shares the Mac's
/// filesystem; on a physical device the probe skips itself.
///
/// ## How the measurement works
///
/// Nothing here asks [PhotoProcessor] where it cropped. Instead the same
/// contour-enabled detector is run twice — once on the framed source, once on
/// the finished crop — and the crop's scale factor is recovered from the ratio
/// of the interocular distances. The chin is then projected from the source
/// into output coordinates:
///
///     scale  = interocular(output) / interocular(source)
///     chin   = eyesY(output) + (chinY(source) - eyesY(source)) x scale
///
/// which is defined whether or not the chin is still inside the frame. A value
/// above 1.0 means the chin is below the bottom edge — it was cropped away.
/// Ground truth for the chin is the lowest point of ML Kit's face *contour*, a
/// reading the app never requests, so it is independent of the maths under
/// test.
///
/// The finished crops are also written to `PROBE_DIR`. A number saying the chin
/// sits at 1.06 of the frame height is an argument; the picture of a chinless
/// passport photo is the evidence.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const repoRoot = String.fromEnvironment('REPO_ROOT');
  const probeDir = String.fromEnvironment('PROBE_DIR');

  final fixtureDir = Directory('$repoRoot/test_fixtures/portraits');

  /// A second detector, configured with contours — which the app deliberately
  /// does not request.
  late final FaceDetector groundTruth;

  setUpAll(() {
    groundTruth = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableLandmarks: true,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.05,
      ),
    );
  });

  tearDownAll(() => groundTruth.close());

  test('measures crown and chin placement for the headline specs', () async {
    if (!fixtureDir.existsSync()) {
      markTestSkipped(
        'no fixtures at ${fixtureDir.path} — pass --dart-define=REPO_ROOT=<repo> '
        'and run on a simulator, which can read the host filesystem',
      );
      return;
    }
    expect(
      probeDir,
      isNotEmpty,
      reason: 'pass --dart-define=PROBE_DIR=<abs dir> so the crops land on disk',
    );

    final specs = await _loadSpecs();
    final portraits = fixtureDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.jpg'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(portraits, isNotEmpty, reason: 'no .jpg fixtures found');

    final out = Directory(probeDir);
    if (!out.existsSync()) out.createSync(recursive: true);

    final processor = PhotoProcessor(FaceDetectorService());
    final tempDir = Directory.systemTemp.createTempSync('crop_probe');
    var measured = 0;

    for (final portrait in portraits) {
      final name = portrait.uri.pathSegments.last.replaceAll('.jpg', '');

      // The fixtures are tight head crops. Reframe each as the sort of photo
      // someone would actually feed the app — head high in a portrait frame,
      // room above and below — because the crop the app asks for begins above
      // the top of a tight crop and would be clamped to the image edge, which
      // hides the very thing being measured.
      final framed = await _reframe(portrait, groundTruth);
      if (framed == null) {
        // ignore: avoid_print
        print('CROPPROBE|$name|-|SKIP no face found in fixture');
        continue;
      }
      final sourceFile = File('${tempDir.path}/$name.jpg')
        ..writeAsBytesSync(framed.bytes);
      File('${out.path}/${name}__00_source.jpg')
          .writeAsBytesSync(framed.bytes);

      for (final specId in _probedSpecs) {
        final spec = specs[specId]!;
        final photo = await processor.process(
          sourcePath: sourceFile.path,
          spec: spec,
        );
        final cropFile = File('${out.path}/${name}__$specId.jpg')
          ..writeAsBytesSync(photo.jpegBytes);

        final placement = await _measure(
          source: framed,
          cropPath: cropFile.path,
          detector: groundTruth,
        );

        final boundaryCheck = photo.checks
            .firstWhere((c) => c.label == 'Photo fully captured')
            .passed;
        final faceSizeCheck = photo.checks
            .firstWhere((c) => c.label == 'Face size within spec')
            .passed;
        // Added with the seventh check in the audit round. It is the one
        // compliance check that speaks directly about the geometry this probe
        // measures, so a probe that did not report it would leave the reader
        // to infer it from `eyesFromBottom` by hand.
        final eyeLineCheck = photo.checks
            .firstWhere((c) => c.label == 'Eye line within spec')
            .passed;
        // Whichever checks did fail, named. Otherwise a "6/7" line says
        // something is wrong without saying what, and the fixtures do have
        // pre-existing failures unrelated to the crop (a busy background, a
        // head that is not square on).
        final failed = photo.checks
            .where((c) => !c.passed)
            .map((c) => c.label)
            .join('+');

        // ignore: avoid_print
        print(
          'CROPPROBE|$name|$specId'
          '|crown=${placement.describe(placement.crown)}'
          '|chin=${placement.describe(placement.chin)}'
          '|eyesFromBottom=${placement.describe(placement.eyesFromBottom)}'
          '|faceFrac=${placement.describe(placement.faceHeightFraction)}'
          '|clamped=${!boundaryCheck}'
          '|faceSizeOk=$faceSizeCheck'
          '|eyeLineOk=$eyeLineCheck'
          '|checks=${photo.passedCount}/${photo.checks.length}'
          '${failed.isEmpty ? '' : '|failed=$failed'}',
        );
        measured++;
      }
    }

    tempDir.deleteSync(recursive: true);
    expect(
      measured,
      greaterThan(0),
      reason: 'the probe took no measurements at all',
    );
  }, timeout: const Timeout(Duration(minutes: 15)));
}

/// The specs worth photographing: the primary market, the two other big ones,
/// and the ICAO fallback every unlisted country lands on.
const _probedSpecs = <String>[
  'uk_passport',
  'us_passport',
  'ca_passport',
  'icao_generic',
];

/// A reframed fixture and the ground-truth landmarks read off it.
class _Framed {
  _Framed({
    required this.bytes,
    required this.chinY,
    required this.crownY,
    required this.eyesY,
    required this.interocular,
  });

  final Uint8List bytes;

  /// Lowest point of ML Kit's face contour.
  final double chinY;

  /// The app's own model of the crown: chin minus 1.45 box heights. Measuring
  /// the app against its own model of the head keeps this a test of the
  /// *framing*, not of whether 1.45 is a well-chosen constant.
  final double crownY;
  final double eyesY;
  final double interocular;
}

/// Where the head ended up in the finished crop, as fractions of its height.
class _Placement {
  const _Placement({
    this.crown,
    this.chin,
    this.eyesFromBottom,
    this.faceHeightFraction,
  });

  /// Crown position from the top. Below 0 means above the top edge.
  final double? crown;

  /// Chin position from the top. Above 1 means below the bottom edge.
  final double? chin;

  /// Eye line measured up from the bottom, which is how ICAO, HMPO and
  /// 22 CFR all state it.
  final double? eyesFromBottom;

  /// Crown-to-chin as a fraction of the photo height.
  final double? faceHeightFraction;

  String describe(double? v) => v == null ? 'NO-FACE' : v.toStringAsFixed(3);
}

/// Runs the contour detector on the finished crop and projects the source's
/// chin and crown into output coordinates.
Future<_Placement> _measure({
  required _Framed source,
  required String cropPath,
  required FaceDetector detector,
}) async {
  final faces = await detector.processImage(InputImage.fromFilePath(cropPath));
  if (faces.isEmpty) return const _Placement();
  faces.sort((a, b) => b.boundingBox.height.compareTo(a.boundingBox.height));
  final face = faces.first;

  final eyes = _eyes(face);
  if (eyes == null) return const _Placement();

  final decoded = img.decodeImage(File(cropPath).readAsBytesSync())!;
  final height = decoded.height.toDouble();

  // The crop is a translate-and-scale, so the interocular distance recovers
  // the scale without the processor having to report anything about itself.
  final scale = eyes.interocular / source.interocular;
  final chinY = eyes.y + (source.chinY - source.eyesY) * scale;
  final crownY = eyes.y + (source.crownY - source.eyesY) * scale;

  return _Placement(
    crown: crownY / height,
    chin: chinY / height,
    eyesFromBottom: (height - eyes.y) / height,
    faceHeightFraction: (chinY - crownY) / height,
  );
}

({double y, double interocular})? _eyes(Face face) {
  final left = face.landmarks[FaceLandmarkType.leftEye];
  final right = face.landmarks[FaceLandmarkType.rightEye];
  if (left == null || right == null) return null;
  final dx = (left.position.x - right.position.x).toDouble();
  final dy = (left.position.y - right.position.y).toDouble();
  return (
    y: (left.position.y + right.position.y) / 2,
    interocular: math.sqrt(dx * dx + dy * dy),
  );
}

/// Places [portrait] in a full-frame portrait canvas with enough room around
/// the head that the requested crop is never clamped to an image edge.
Future<_Framed?> _reframe(File portrait, FaceDetector detector) async {
  final first = await detector.processImage(
    InputImage.fromFilePath(portrait.path),
  );
  if (first.isEmpty) return null;
  first.sort((a, b) => b.boundingBox.height.compareTo(a.boundingBox.height));
  final face = first.first;

  final source = img.bakeOrientation(
    img.decodeImage(portrait.readAsBytesSync())!,
  );

  // Scale so the detected box is a fixed size, which makes the margins below
  // mean the same thing for every fixture.
  const targetBoxHeight = 420.0;
  final scale = targetBoxHeight / face.boundingBox.height;
  final scaled = img.copyResize(
    source,
    width: math.max(1, (source.width * scale).round()),
    height: math.max(1, (source.height * scale).round()),
    interpolation: img.Interpolation.cubic,
  );

  // Headroom of 2.4 box-heights. The most demanding spec asks for a crop
  // starting about 1.5 box-heights above the top of the box; with less than
  // that the clamp in _computeCropRect fires and quietly rescues the framing,
  // which would mask the defect instead of measuring it.
  const marginTop = targetBoxHeight * 2.4;
  const marginBottom = targetBoxHeight * 3.0;
  final boxTop = face.boundingBox.top * scale;
  final boxBottom = face.boundingBox.bottom * scale;

  final canvasHeight =
      (marginTop + (boxBottom - boxTop) + marginBottom).round();
  final canvasWidth = (canvasHeight * 3 / 4).round();

  final canvas = img.Image(width: canvasWidth, height: canvasHeight);
  // A plain, evenly-lit wall.
  img.fill(canvas, color: img.ColorRgb8(236, 234, 229));

  final dstY = (marginTop - boxTop).round();
  final dstX = ((canvasWidth - scaled.width) / 2).round();
  img.compositeImage(canvas, scaled, dstX: dstX, dstY: dstY);

  // Continue the portrait's bottom row downwards so the head is not floating
  // over a hard horizontal seam. The detector does not care; it makes the
  // saved crops readable as photographs when a human looks at them.
  final seamY = dstY + scaled.height - 1;
  if (seamY > 0 && seamY < canvasHeight - 1) {
    final fromX = math.max(0, dstX);
    final toX = math.min(canvasWidth, dstX + scaled.width);
    for (var y = seamY + 1; y < canvasHeight; y++) {
      for (var x = fromX; x < toX; x++) {
        canvas.setPixel(x, y, canvas.getPixel(x, seamY));
      }
    }
  }

  final bytes = Uint8List.fromList(img.encodeJpg(canvas, quality: 95));
  final canvasFile = File(
    '${Directory.systemTemp.path}/reframe_${portrait.uri.pathSegments.last}',
  )..writeAsBytesSync(bytes);
  final second = await detector.processImage(
    InputImage.fromFilePath(canvasFile.path),
  );
  canvasFile.deleteSync();
  if (second.isEmpty) return null;
  second.sort((a, b) => b.boundingBox.height.compareTo(a.boundingBox.height));
  final f = second.first;

  final eyes = _eyes(f);
  if (eyes == null) return null;

  final contour = f.contours[FaceContourType.face];
  final chinY = contour == null || contour.points.isEmpty
      ? f.boundingBox.bottom
      : contour.points.map((p) => p.y).reduce(math.max).toDouble();

  return _Framed(
    bytes: bytes,
    chinY: chinY,
    crownY: f.boundingBox.bottom - 1.45 * f.boundingBox.height,
    eyesY: eyes.y,
    interocular: eyes.interocular,
  );
}

Future<Map<String, PhotoSpec>> _loadSpecs() async {
  // The specs asset is bundled, so read it the way the app does.
  final raw = await rootBundle.loadString('assets/specs/photo_specs.json');
  final data = json.decode(raw) as Map<String, dynamic>;
  final specs = (data['specs'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .map(PhotoSpec.fromJson);
  return {for (final s in specs) s.id: s};
}
