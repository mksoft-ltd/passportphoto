import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_info.dart';
import '../../core/demo/demo_data.dart';
import '../../core/services/photo_files.dart';
import '../specs/specs_repository.dart';
import 'face_detector_service.dart';
import 'photo_processor.dart';
import 'processed_photo.dart';

final faceDetectorServiceProvider = Provider<FaceDetectorService>((ref) {
  final svc = FaceDetectorService();
  ref.onDispose(svc.dispose);
  return svc;
});

final photoProcessorProvider = Provider<PhotoProcessor>((ref) {
  return PhotoProcessor(ref.watch(faceDetectorServiceProvider));
});

/// Runs the processor on the source path with the currently-selected spec.
///
/// Keyed by source path so the review screen and the print-sheet preview share
/// one detection + crop rather than doing the work twice.
final processedPhotoProvider = FutureProvider.family
    .autoDispose<ProcessedPhoto, String>((ref, sourcePath) async {
  final spec = ref.watch(selectedSpecProvider);
  if (spec == null) {
    throw PhotoProcessingFailure('No document type selected.');
  }
  // Screenshot runs have no camera and no photo library, so they get a
  // fixture instead of a detection. Compile-time false in release builds.
  if (AppInfo.screenshotMode) {
    return DemoData.processedPhoto(spec);
  }

  // The processed bytes live in memory on ProcessedPhoto; the source file is
  // dead weight the moment this returns, and it is a photograph of someone's
  // face. `/result` and `/sheet` share this one instance — the family is keyed
  // by path — so the sheet screen cannot lose the file out from under itself.
  //
  // Guarded so the screenshot harness's fixture path is never touched.
  ref.onDispose(() {
    if (!AppInfo.screenshotMode) {
      unawaited(PhotoFiles.discardSource(sourcePath));
    }
  });

  final processor = ref.watch(photoProcessorProvider);
  return processor.process(sourcePath: sourcePath, spec: spec);
});
