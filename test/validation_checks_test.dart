import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:passport_photo_app/core/models/photo_spec.dart';
import 'package:passport_photo_app/features/processing/photo_processor.dart';
import 'package:passport_photo_app/features/processing/processed_photo.dart';

import 'support/crop_harness.dart';
import 'support/specs.dart';

/// The six checks on the review screen are the app's entire promise: a user
/// pays £4.99 on the strength of a green tick, then takes the print to a
/// passport office. A check that says "pass" when it should not is worse than
/// no check at all, because it moves the rejection from the phone to the
/// counter.
///
/// None of these had any coverage before stage 3.
void main() {
  const subject = SyntheticSubject();

  ValidationCheck check(ProcessedPhoto photo, String label) =>
      photo.checks.firstWhere((c) => c.label == label);

  group('Single face detected', () {
    test('passes with exactly one face', () async {
      final photo = await runProcessor(spec: ukPassport());
      expect(check(photo, 'Single face detected').passed, isTrue);
    });

    test('fails, and counts them, when someone else is in shot', () async {
      final photo = await runProcessor(
        spec: ukPassport(),
        faces: [
          subject.face,
          // Smaller and off to one side — a bystander, not the subject. The
          // processor sorts by area and must crop to the larger one.
          subject.faceWith(heightScale: 0.45, offsetX: 700),
        ],
      );
      final result = check(photo, 'Single face detected');
      expect(result.passed, isFalse);
      expect(result.detail, contains('2 faces'));
    });
  });

  group('Eyes open', () {
    test('passes when both eyes are open', () async {
      final photo = await runProcessor(spec: ukPassport());
      expect(check(photo, 'Eyes open').passed, isTrue);
    });

    test('fails when one eye is closed', () async {
      final photo = await runProcessor(
        spec: ukPassport(),
        faces: [subject.faceWith(leftEyeOpen: 0.1)],
      );
      final result = check(photo, 'Eyes open');
      expect(result.passed, isFalse);
      expect(result.detail, contains('L: 10%'));
    });

    test('a blink at exactly the threshold still fails', () async {
      // The rule is `> 0.6`, so 0.6 itself is a fail. Worth pinning: a change
      // to `>=` would quietly start passing half-shut eyes, which is the most
      // common reason a passport photo is rejected.
      final photo = await runProcessor(
        spec: ukPassport(),
        faces: [subject.faceWith(leftEyeOpen: 0.6, rightEyeOpen: 0.6)],
      );
      expect(check(photo, 'Eyes open').passed, isFalse);
    });

    test('treats an unmeasured eye as open', () async {
      // ML Kit returns null when classification is off or the face is too
      // small to score. Failing the user on a missing measurement would be a
      // false accusation, so the code defaults to 1.0 — pinned here so the
      // default is a decision rather than an accident.
      final photo = await runProcessor(
        spec: ukPassport(),
        faces: [subject.faceWith(leftEyeOpen: null, rightEyeOpen: null)],
      );
      expect(check(photo, 'Eyes open').passed, isTrue);
    });
  });

  group('Looking forward', () {
    test('passes a square-on head', () async {
      final photo = await runProcessor(spec: ukPassport());
      expect(check(photo, 'Looking forward').passed, isTrue);
    });

    test('fails a turned head and reports the angles', () async {
      final photo = await runProcessor(
        spec: ukPassport(),
        faces: [subject.faceWith(yaw: 20)],
      );
      final result = check(photo, 'Looking forward');
      expect(result.passed, isFalse);
      expect(result.detail, contains('yaw 20.0'));
    });

    test('roll is held to a tighter tolerance than yaw', () async {
      // 10 degrees of roll fails while 10 degrees of yaw passes. A tilted head
      // is the more serious fault for a document photo, so the asymmetry is
      // deliberate and worth pinning.
      final tilted = await runProcessor(
        spec: ukPassport(),
        faces: [subject.faceWith(roll: 10)],
      );
      final turned = await runProcessor(
        spec: ukPassport(),
        faces: [subject.faceWith(yaw: 10)],
      );
      expect(check(tilted, 'Looking forward').passed, isFalse);
      expect(check(turned, 'Looking forward').passed, isTrue);
    });
  });

  group('Background uniform', () {
    test('passes a plain evenly-lit wall', () async {
      final photo = await runProcessor(spec: ukPassport());
      expect(check(photo, 'Background uniform').passed, isTrue);
    });

    test('fails a busy background', () async {
      final photo = await runProcessor(
        spec: ukPassport(),
        sourceJpeg: _stripedBackdrop(),
      );
      final result = check(photo, 'Background uniform');
      expect(result.passed, isFalse);
      expect(result.detail, contains('uneven'));
    });
  });

  group('Eye line within spec', () {
    // The check that did not exist. `HeadFraming.honoursSpecEyeLine` and the
    // crop's own `eyeLineFromBottomFraction` were both computed, documented and
    // read by nothing in lib/, so at the eye position real ML Kit produces, 17
    // of the 30 bundled specs were framed outside their own stated band and
    // still reported every check green. The eye line is one of the two rules
    // every issuing authority publishes.

    test('passes a well-framed head', () async {
      final photo = await runProcessor(spec: ukPassport());
      final result = check(photo, 'Eye line within spec');
      expect(result.passed, isTrue, reason: result.detail);
    });

    test('passes at the head shape real ML Kit produces', () async {
      // 0.45 is the harness's classical head; 0.59 is what ships. The check has
      // to hold at both, because it is the one the £4.99 is backed by.
      for (final spec in [ukPassport(), usPassport(), caPassport()]) {
        final photo = await runProcessor(
          spec: spec,
          eyeLineWithinHead: SyntheticSubject.realMlKitEye,
        );
        final result = check(photo, 'Eye line within spec');
        expect(result.passed, isTrue, reason: '${spec.id}: ${result.detail}');
      }
    });

    test('fails when the eye line lands outside the spec band', () async {
      // A band of 5-6 mm up a 45 mm photo puts the eyes almost on the bottom
      // edge. No framing that keeps the head in the picture can reach it, so
      // the check has to report the miss rather than restate the request.
      final impossible = PhotoSpec.fromJson({
        ...ukPassportJson,
        'id': 'test_low_eye_band',
        'eyeLineFromBottomMinMm': 5.0,
        'eyeLineFromBottomMaxMm': 6.0,
      });
      final photo = await runProcessor(spec: impossible);
      final result = check(photo, 'Eye line within spec');
      expect(result.passed, isFalse, reason: result.detail);
    });

    test('says whose fault it is when the spec contradicts itself', () async {
      // The degradation case `honoursSpecEyeLine` exists to name. A 32-36 mm
      // head with the eye line 30-36 mm up a 45 mm photo — the figures the app
      // shipped until 2026-08-05 — cannot both be satisfied by a real head, and
      // the solver keeps head height because that is the rule offices measure.
      // Telling the user to re-shoot would be telling them to do something that
      // cannot work.
      final contradictory = PhotoSpec.fromJson({
        ...ukPassportJson,
        'id': 'test_contradictory_bands',
        'faceHeightMinMm': 32.0,
        'faceHeightMaxMm': 36.0,
        'eyeLineFromBottomMinMm': 30.0,
        'eyeLineFromBottomMaxMm': 36.0,
      });
      final photo = await runProcessor(spec: contradictory);
      final result = check(photo, 'Eye line within spec');
      expect(result.passed, isFalse);
      expect(result.detail, contains('cannot both be met'));
      expect(result.detail, isNot(contains('re-shoot')));
    });

    test('the millimetre figure it quotes is the one in the photo', () async {
      // The anti-vacuity test, same shape as the face-size one: cross-checked
      // against the stripe ruler, which locates the eye line in the finished
      // JPEG and knows nothing about the processor's arithmetic.
      for (final spec in [ukPassport(), usPassport(), caPassport()]) {
        final photo = await runProcessor(spec: spec);
        final placement = await measureCrop(spec);
        final quoted = RegExp(r'Eyes sit ([\d.]+)mm')
            .firstMatch(check(photo, 'Eye line within spec').detail);

        expect(quoted, isNotNull, reason: spec.id);
        final measured = placement.eyeLineFromBottom! * spec.heightMm;
        expect(
          double.parse(quoted!.group(1)!),
          closeTo(measured, 0.6),
          reason: '${spec.id}: the report quotes a different eye line from the '
              'one in the picture — $placement',
        );
      }
    });
  });

  group('Photo fully captured', () {
    test('passes when the crop fits inside the source', () async {
      final photo = await runProcessor(spec: ukPassport());
      expect(check(photo, 'Photo fully captured').passed, isTrue);
    });

    test('fails when the crown ends up above the top edge', () async {
      // Rebuilt in the crop fix: this check now looks at where the head landed
      // in the *output*, not only at whether the crop fitted the source. That
      // matters because the two come apart — the crop can sit entirely inside
      // the source and still be framed so the head does not fit it, which is
      // exactly the shape of the defect that shipped.
      final photo = await runProcessor(
        spec: ukPassport(),
        faces: [subject.faceWith(offsetY: -1300)],
      );
      final result = check(photo, 'Photo fully captured');
      expect(result.passed, isFalse);
      expect(result.detail, contains('top of the head is above the top edge'));
      expect(result.detail, contains('Leave more space above your head'));
    });

    test('fails when the chin ends up below the bottom edge', () async {
      // The failure the app shipped with, on 19 of 30 specs, reported as a
      // green tick. If this test ever passes vacuously again, the compliance
      // report is lying to someone about to pay for a print.
      final photo = await runProcessor(
        spec: ukPassport(),
        faces: [subject.faceWith(offsetY: 1500)],
      );
      final result = check(photo, 'Photo fully captured');
      expect(result.passed, isFalse);
      expect(result.detail, contains('chin falls below the bottom edge'));
    });

    test('tells the user which way to move, not just that it failed', () async {
      // Three distinct failure branches, three different instructions. A
      // single "re-shoot" for all of them would leave the user guessing which
      // direction to move, and re-shooting the same mistake is how people
      // conclude an app is broken.
      final tooHigh = check(
        await runProcessor(
          spec: ukPassport(),
          faces: [subject.faceWith(offsetY: -1300)],
        ),
        'Photo fully captured',
      );
      final tooLow = check(
        await runProcessor(
          spec: ukPassport(),
          faces: [subject.faceWith(offsetY: 1500)],
        ),
        'Photo fully captured',
      );
      final offSource = check(
        await runProcessor(
          spec: ukPassport(),
          faces: [subject.faceWith(offsetY: -900)],
        ),
        'Photo fully captured',
      );

      expect({tooHigh.detail, tooLow.detail, offSource.detail}, hasLength(3));
      for (final detail in [tooHigh.detail, tooLow.detail, offSource.detail]) {
        expect(detail, contains('re-shoot'));
      }
    });

    test('fails when the requested crop runs off the source', () async {
      // The subject stands too close and too high in the frame, so the crop
      // the spec asks for starts above the top edge. This is the check that
      // tells the user to step back, and the only one that can catch a crop
      // the source could never satisfy.
      final photo = await runProcessor(
        spec: ukPassport(),
        faces: [subject.faceWith(offsetY: -900)],
      );
      final result = check(photo, 'Photo fully captured');
      expect(result.passed, isFalse);
      expect(result.detail, contains('Move further from the camera'));
    });
  });

  group('Face size within spec', () {
    // Until 2026-08-05 this check could not fail. `_computeCropRect` divided
    // the requested crop height by itself, so the answer was always the
    // midpoint of the band it was being compared against. That is why the
    // chin-crop defect shipped with six green ticks against it.
    //
    // It now measures the detected head against the rectangle that was
    // actually cut, which is a different number whenever a clamp fired or the
    // framing had to shrink the head to keep it in the picture. These tests
    // exist to keep it that way: a check that agrees with everything is worse
    // than no check, because it is the reassurance a user pays £4.99 on.

    test('passes a well-framed head', () async {
      final photo = await runProcessor(spec: ukPassport());
      final result = check(photo, 'Face size within spec');
      expect(result.passed, isTrue, reason: result.detail);
    });

    test('fails when the head cannot be made to fit the band', () async {
      // A band of 10.0-10.4 mm on a 45 mm photo asks for a head a fifth the
      // size a passport photo wants. The framing cannot honour it and keep
      // the head off both edges, so the check has to say so rather than
      // restate the request.
      final narrow = PhotoSpec.fromJson({
        ...ukPassportJson,
        'id': 'test_narrow_band',
        'faceHeightMinMm': 10.0,
        'faceHeightMaxMm': 10.4,
      });
      final photo = await runProcessor(spec: narrow);
      final result = check(photo, 'Face size within spec');
      expect(result.passed, isFalse, reason: result.detail);
      expect(result.detail, contains('should be'));
    });

    test('the percentage it quotes is the one in the photo', () async {
      // The anti-vacuity test. It is not enough that the check *can* fail; the
      // number it puts on screen has to be a measurement of the picture the
      // user is looking at. Cross-checked against the stripe ruler, which
      // locates the crown and chin in the finished JPEG and knows nothing
      // about the processor's arithmetic.
      for (final spec in [ukPassport(), usPassport(), caPassport()]) {
        final photo = await runProcessor(spec: spec);
        final placement = await measureCrop(spec);
        final quoted = RegExp(r'Face fills (\d+)%')
            .firstMatch(check(photo, 'Face size within spec').detail);

        expect(quoted, isNotNull, reason: spec.id);
        // Tight on purpose. The check carries one output pixel of slack for
        // whole-pixel rounding of the crop rectangle (1/1063 on a UK photo);
        // anything looser than a point or so here would let a real framing
        // error hide behind that allowance, and the quoted percentage is what
        // a user reads before deciding the photo is fit to print.
        expect(
          int.parse(quoted!.group(1)!) / 100,
          closeTo(placement.faceHeightFraction!, 0.012),
          reason: '${spec.id}: the report and the photo disagree — $placement',
        );
      }
    });
  });

  test('allPassed and passedCount agree with the checks', () async {
    final good = await runProcessor(spec: ukPassport());
    expect(good.checks, hasLength(7));
    expect(good.passedCount, good.checks.where((c) => c.passed).length);
    expect(good.allPassed, good.passedCount == 7);

    final bad = await runProcessor(
      spec: ukPassport(),
      faces: [subject.faceWith(leftEyeOpen: 0.0, yaw: 40)],
    );
    expect(bad.allPassed, isFalse);
    expect(bad.passedCount, lessThan(7));
  });

  test('the output is exactly the pixel size the spec asks for', () async {
    for (final spec in [ukPassport(), usPassport(), caPassport()]) {
      final photo = await runProcessor(spec: spec);
      expect(photo.widthPx, spec.widthPx, reason: spec.id);
      expect(photo.heightPx, spec.heightPx, reason: spec.id);

      final decoded = img.decodeImage(photo.jpegBytes)!;
      expect(decoded.width, spec.widthPx, reason: spec.id);
      expect(decoded.height, spec.heightPx, reason: spec.id);
    }
  });

  test('a photo with no face in it is refused, not silently cropped', () async {
    await expectLater(
      runProcessor(spec: ukPassport(), faces: const []),
      throwsA(
        isA<PhotoProcessingFailure>().having(
          (e) => e.message,
          'message',
          contains('No face detected'),
        ),
      ),
    );
  });

  test(
    'an undecodable file is reported in words the user can act on',
    () async {
      // `PhotoProcessor` guards on `decodeImage` returning null, and for most
      // rubbish that is what happens. Not for a file of fewer than five bytes:
      // the `image` package walks its decoders, and the PSD one reads past the
      // end of the buffer and throws `RangeError (length): Invalid value: Not
      // in inclusive range 0..-1: 5` before any decoder can decline. A
      // RangeError is not a PhotoProcessingFailure, so it used to sail past the
      // friendly message and reach the result screen's `_ErrorView`, which
      // renders `e.toString()` verbatim.
      //
      // An **empty file** is the case that matters, and it is reachable: the
      // gallery picker hands back a path, and an iCloud photo that has not
      // finished downloading — or a failed share-sheet import — is zero bytes
      // on disk. Nothing crashed and "Try again" still worked, so it was
      // cosmetic, but what the user saw was a Dart error string.
      //
      // Fixed 2026-08-05 by a try/catch around the decode in
      // `PhotoProcessor.process`. The same unguarded `decodeImage` in
      // `Watermarker.preview`, `Watermarker.stampJpeg` and `renderPrintSheet`
      // is guarded too — those run inside isolates, where an escaped error is
      // harder to attribute to anything.
      await expectLater(
        runProcessor(spec: ukPassport(), sourceJpeg: Uint8List(0)),
        throwsA(
          isA<PhotoProcessingFailure>().having(
            (e) => e.message,
            'message',
            contains('Could not decode'),
          ),
        ),
      );
    },
  );
}

/// A backdrop with hard vertical bars across the top, so the uniformity check
/// has something to object to. The check samples the top tenth of the finished
/// photo, which is why the bars go there.
Uint8List _stripedBackdrop() {
  final image = img.decodeImage(subjectJpeg())!;
  for (var y = 0; y < image.height ~/ 2; y++) {
    for (var x = 0; x < image.width; x++) {
      if ((x ~/ 40).isEven) {
        image.setPixel(x, y, img.ColorRgb8(20, 20, 20));
      }
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 92));
}
