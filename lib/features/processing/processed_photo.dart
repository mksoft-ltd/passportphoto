import 'package:flutter/foundation.dart';

import '../../core/models/photo_spec.dart';

@immutable
class ValidationCheck {
  const ValidationCheck({
    required this.label,
    required this.passed,
    required this.detail,
  });

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
}
