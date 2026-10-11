import 'package:flutter/foundation.dart';

import '../../core/models/photo_spec.dart';

/// What a [ValidationCheck] measures, and the one thing to change when it
/// fails.
///
/// The hint lives here, beside the check's identity, rather than in the result
/// screen: it is data about the rule, the same for every photo, while
/// [ValidationCheck.detail] is the measurement of this one.
enum CheckKind {
  singleFace('Make sure you are the only person in the frame.'),
  eyesOpen('Look straight at the camera with both eyes open.'),
  lookingForward('Keep your head straight and level, facing the camera.'),
  neutralExpression('Relax your face and keep your mouth closed.'),
  faceSize(
      'Move closer or further away so your head fills about three quarters '
      'of the frame.'),
  eyeLine('Hold the phone at eye level.'),
  background(
      'Stand about 1 m in front of a plain, light wall. Face a window, with '
      'no light from behind or above you.'),
  fullyCaptured(
      'Step back a little so there is space above your head and below your '
      'chin.');

  const CheckKind(this.fixHint);

  /// Shown under the row only when the check failed. Calm, one sentence or
  /// two, no exclamation marks (store_assets/BRAND.md, tone of voice).
  final String fixHint;
}

@immutable
class ValidationCheck {
  const ValidationCheck({
    required this.kind,
    required this.label,
    required this.passed,
    required this.detail,
  });

  final CheckKind kind;
  final String label;
  final bool passed;
  final String detail;
}

@immutable
class ProcessedPhoto {
  const ProcessedPhoto({
    required this.spec,
    required this.jpegBytes,
    required this.widthPx,
    required this.heightPx,
    required this.checks,
  });

  final PhotoSpec spec;
  final Uint8List jpegBytes;
  final int widthPx;
  final int heightPx;
  final List<ValidationCheck> checks;

  bool get allPassed => checks.every((c) => c.passed);
  int get passedCount => checks.where((c) => c.passed).length;
  int get failedCount => checks.length - passedCount;
}
