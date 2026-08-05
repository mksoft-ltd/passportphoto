import 'package:flutter/material.dart';

enum BackgroundColor { white, offWhite, lightGrey, lightBlue }

extension BackgroundColorX on BackgroundColor {
  Color get color {
    switch (this) {
      case BackgroundColor.white:
        return const Color(0xFFFFFFFF);
      case BackgroundColor.offWhite:
        return const Color(0xFFF5F1E8);
      case BackgroundColor.lightGrey:
        return const Color(0xFFE3E3E3);
      case BackgroundColor.lightBlue:
        return const Color(0xFFD6E4F0);
    }
  }

  String get label {
    switch (this) {
      case BackgroundColor.white:
        return 'White';
      case BackgroundColor.offWhite:
        return 'Off-white';
      case BackgroundColor.lightGrey:
        return 'Light grey';
      case BackgroundColor.lightBlue:
        return 'Light blue';
    }
  }

  static BackgroundColor parse(String raw) {
    switch (raw) {
      case 'white':
        return BackgroundColor.white;
      case 'off-white':
        return BackgroundColor.offWhite;
      case 'light-grey':
        return BackgroundColor.lightGrey;
      case 'light-blue':
        return BackgroundColor.lightBlue;
      default:
        return BackgroundColor.white;
    }
  }
}

@immutable
class PhotoSpec {
  const PhotoSpec({
    required this.id,
    required this.countryCode,
    required this.countryName,
    required this.documentType,
    required this.widthMm,
    required this.heightMm,
    required this.dpi,
    required this.faceHeightMinMm,
    required this.faceHeightMaxMm,
    required this.eyeLineFromBottomMinMm,
    required this.eyeLineFromBottomMaxMm,
    required this.background,
    required this.format,
    this.fileSizeMinKb,
    this.fileSizeMaxKb,
    this.notes,
  });

  final String id;
  final String countryCode;
  final String countryName;
  final String documentType;
  final double widthMm;
  final double heightMm;
  final int dpi;
  final double faceHeightMinMm;
  final double faceHeightMaxMm;

  /// Eye line measured **up from the bottom edge**, which is how ICAO Doc 9303,
  /// UK HMPO and 22 CFR 51.604 all state it. Reading these as a distance down
  /// from the top is what put the chin below the bottom edge on 19 of the 30
  /// bundled specs before 2026-08-05; the name says the convention so that the
  /// mistake cannot be made silently a second time.
  final double eyeLineFromBottomMinMm;
  final double eyeLineFromBottomMaxMm;
  final BackgroundColor background;
  final String format;
  final int? fileSizeMinKb;
  final int? fileSizeMaxKb;
  final String? notes;

  /// Output pixel width.
  int get widthPx => (widthMm / 25.4 * dpi).round();

  /// Output pixel height.
  int get heightPx => (heightMm / 25.4 * dpi).round();

  double get aspectRatio => widthMm / heightMm;

  /// Smallest permitted face height (chin to crown), as a fraction of the photo
  /// height.
  double get faceHeightMinFraction => faceHeightMinMm / heightMm;

  /// Largest permitted face height (chin to crown), as a fraction of the photo
  /// height.
  double get faceHeightMaxFraction => faceHeightMaxMm / heightMm;

  /// Preferred face height (chin to crown) as a fraction of photo height, taken
  /// as the midpoint of the allowed range.
  double get targetFaceHeightFraction =>
      (faceHeightMinFraction + faceHeightMaxFraction) / 2.0;

  /// Lowest permitted eye line, as a fraction of the photo height measured **up
  /// from the bottom edge**.
  double get eyeLineFromBottomMinFraction => eyeLineFromBottomMinMm / heightMm;

  /// Highest permitted eye line, as a fraction of the photo height measured
  /// **up from the bottom edge**.
  double get eyeLineFromBottomMaxFraction => eyeLineFromBottomMaxMm / heightMm;

  /// Preferred eye line, as a fraction of the photo height measured **up from
  /// the bottom edge**.
  double get targetEyeLineFromBottomFraction =>
      (eyeLineFromBottomMinFraction + eyeLineFromBottomMaxFraction) / 2.0;

  factory PhotoSpec.fromJson(Map<String, dynamic> json) {
    return PhotoSpec(
      id: json['id'] as String,
      countryCode: json['countryCode'] as String,
      countryName: json['countryName'] as String,
      documentType: json['documentType'] as String,
      widthMm: (json['widthMm'] as num).toDouble(),
      heightMm: (json['heightMm'] as num).toDouble(),
      dpi: (json['dpi'] as num).toInt(),
      faceHeightMinMm: (json['faceHeightMinMm'] as num).toDouble(),
      faceHeightMaxMm: (json['faceHeightMaxMm'] as num).toDouble(),
      // `eyeLineFromTop*` is the old spelling of the same from-the-bottom
      // figure, kept readable only so spec fixtures written before the rename
      // keep parsing. Nothing in `assets/specs/` uses it any more.
      eyeLineFromBottomMinMm: ((json['eyeLineFromBottomMinMm'] ??
              json['eyeLineFromTopMinMm']) as num)
          .toDouble(),
      eyeLineFromBottomMaxMm: ((json['eyeLineFromBottomMaxMm'] ??
              json['eyeLineFromTopMaxMm']) as num)
          .toDouble(),
      background: BackgroundColorX.parse(json['background'] as String),
      format: json['format'] as String? ?? 'JPEG',
      fileSizeMinKb: (json['fileSizeMinKb'] as num?)?.toInt(),
      fileSizeMaxKb: (json['fileSizeMaxKb'] as num?)?.toInt(),
      notes: json['notes'] as String?,
    );
  }

  String get displayLabel => '$countryName · $documentType';
  String get sizeLabel =>
      '${widthMm.toStringAsFixed(widthMm.truncateToDouble() == widthMm ? 0 : 1)} × '
      '${heightMm.toStringAsFixed(heightMm.truncateToDouble() == heightMm ? 0 : 1)} mm '
      '@ ${dpi}dpi';
}
