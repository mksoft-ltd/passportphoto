import 'dart:convert';
import 'dart:io';

import 'package:passport_photo_app/core/models/photo_spec.dart';

/// Spec fixtures for the unit suite.
///
/// The JSON maps are written out rather than read from
/// `assets/specs/photo_specs.json`, so a test that says "a 35x45 mm photo at
/// 600 dpi is 827x1063 px" keeps meaning that even if the bundled asset is
/// edited. Tests that are *about* the bundled asset use [bundledSpecs].

const Map<String, dynamic> ukPassportJson = {
  'id': 'uk_passport',
  'countryCode': 'GB',
  'countryName': 'United Kingdom',
  'documentType': 'Passport',
  'widthMm': 35.0,
  'heightMm': 45.0,
  'dpi': 600,
  'faceHeightMinMm': 29.0,
  'faceHeightMaxMm': 34.0,
  // ICAO-derived, 50-70% of a 45 mm photo. See assets/specs/SOURCES.md — HMPO
  // publishes a head height and no eye line, and the 30-36 mm this replaced was
  // the head-height rule copied into the eye-line field.
  'eyeLineFromBottomMinMm': 22.5,
  'eyeLineFromBottomMaxMm': 31.5,
  'background': 'off-white',
  'format': 'JPEG',
  'notes': 'Plain cream/light grey background. No smiling, mouth closed.',
};

const Map<String, dynamic> usPassportJson = {
  'id': 'us_passport',
  'countryCode': 'US',
  'countryName': 'United States',
  'documentType': 'Passport',
  'widthMm': 51.0,
  'heightMm': 51.0,
  'dpi': 300,
  'faceHeightMinMm': 25.0,
  'faceHeightMaxMm': 35.0,
  // Published verbatim: 22 CFR / travel.state.gov, 1-1/8 to 1-3/8 inch from the
  // bottom of a 2x2 inch photo. The one spec with a real national eye line.
  'eyeLineFromBottomMinMm': 28.0,
  'eyeLineFromBottomMaxMm': 35.0,
  'background': 'white',
  'format': 'JPEG',
  'fileSizeMinKb': 54,
  'fileSizeMaxKb': 10240,
};

const Map<String, dynamic> caPassportJson = {
  'id': 'ca_passport',
  'countryCode': 'CA',
  'countryName': 'Canada',
  'documentType': 'Passport',
  'widthMm': 50.0,
  'heightMm': 70.0,
  'dpi': 300,
  'faceHeightMinMm': 31.0,
  'faceHeightMaxMm': 36.0,
  // ICAO-derived, 50-70% of a 70 mm photo. IRCC publishes no eye line.
  'eyeLineFromBottomMinMm': 35.0,
  'eyeLineFromBottomMaxMm': 49.0,
  'background': 'white',
  'format': 'JPEG',
};

PhotoSpec ukPassport() => PhotoSpec.fromJson(ukPassportJson);
PhotoSpec usPassport() => PhotoSpec.fromJson(usPassportJson);
PhotoSpec caPassport() => PhotoSpec.fromJson(caPassportJson);

/// Every spec the app actually ships, read from the bundled asset.
List<PhotoSpec> bundledSpecs() {
  final raw = File('assets/specs/photo_specs.json').readAsStringSync();
  final data = json.decode(raw) as Map<String, dynamic>;
  return (data['specs'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .map(PhotoSpec.fromJson)
      .toList();
}
