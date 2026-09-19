/// The rules the camera cannot see, and the one expression rule it can.
///
/// Two separate things came out of the same review on 2026-09-19.
///
/// **Glasses and head coverings were absent entirely.** Several specs' `notes`
/// asserted "No glasses" as prose, nothing carried it as data, nothing showed
/// it at the moment it mattered, and `assets/specs/SOURCES.md` — whose opening
/// rule is that every number has a citation — said nothing about where any of
/// it came from. It still cannot be *checked*: ML Kit's `Face` carries head
/// Euler angles, eye-open and smiling probabilities, landmarks and contours,
/// and nothing about eyewear. So the rules are published, not measured, and a
/// spec whose rules were never confirmed says exactly that.
///
/// **Neutral expression could always have been checked and never was.**
/// `smilingProbability` arrives on every detection and was read by nothing.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:passport_photo_app/core/models/photo_spec.dart';

import 'support/crop_harness.dart';
import 'support/specs.dart';

void main() {
  late final List<PhotoSpec> specs;

  setUpAll(() {
    final raw = File('assets/specs/photo_specs.json').readAsStringSync();
    final data = json.decode(raw) as Map<String, dynamic>;
    specs = (data['specs'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PhotoSpec.fromJson)
        .toList();
  });

  PhotoSpec byId(String id) => specs.firstWhere((s) => s.id == id);

  group('the bundled rules match what the authorities publish', () {
    test('the US requires glasses off', () {
      // Not accepted since 1 November 2016, bar a signed medical statement.
      expect(byId('us_passport').glasses, GlassesRule.notAllowed);
      expect(byId('us_visa').glasses, GlassesRule.notAllowed);
    });

    test('Australia and India also require glasses off', () {
      expect(byId('au_passport').glasses, GlassesRule.notAllowed);
      expect(byId('in_passport').glasses, GlassesRule.notAllowed);
      expect(byId('in_visa').glasses, GlassesRule.notAllowed);
    });

    test('the UK, Canada and Germany allow them subject to conditions', () {
      expect(byId('uk_passport').glasses, GlassesRule.allowedIfClear);
      expect(byId('ca_passport').glasses, GlassesRule.allowedIfClear);
      expect(byId('de_passport').glasses, GlassesRule.allowedIfClear);
    });

    test('every spec with a rule also carries the source it came from', () {
      for (final spec in specs.where((s) => s.accessoryRulesVerified)) {
        expect(spec.rulesSource, isNotNull, reason: spec.id);
        expect(spec.rulesSource, startsWith('https://'), reason: spec.id);
        expect(spec.accessoryNotes, isNotNull, reason: spec.id);
      }
    });

    test('a spec whose rules were never confirmed says so, both fields', () {
      // Half-verified would be the worst outcome: the screen would present a
      // confirmed head-covering rule and an invented glasses one identically.
      for (final spec in specs) {
        final glassesKnown = spec.glasses != GlassesRule.unverified;
        final coveringKnown =
            spec.headCovering != HeadCoveringRule.unverified;
        expect(glassesKnown, coveringKnown,
            reason: '${spec.id} is verified for one rule but not the other');
      }
    });

    test('nothing claims a rule it has no source for', () {
      for (final spec in specs) {
        if (spec.rulesSource == null) {
          expect(spec.glasses, GlassesRule.unverified, reason: spec.id);
          expect(spec.headCovering, HeadCoveringRule.unverified,
              reason: spec.id);
        }
      }
    });

    test('the Chinese passport is left unverified, unlike the visa', () {
      // The consulate page the visa rule comes from is about visas. The
      // passport is a different instrument and the secondary sources for it
      // contradict each other, so it is not asserted.
      expect(byId('cn_visa').glasses, GlassesRule.allowedIfClear);
      expect(byId('cn_passport').glasses, GlassesRule.unverified);
    });
  });

  group('backgrounds are not all white, and that is correct', () {
    test('the UK asks for off-white, not white', () {
      // gov.uk: "be taken against a plain light-coloured background".
      expect(byId('uk_passport').background, BackgroundColor.offWhite);
    });

    test('Germany and the Netherlands ask for light grey', () {
      // Pure white is commonly rejected for the German biometric photo.
      expect(byId('de_passport').background, BackgroundColor.lightGrey);
      expect(byId('nl_passport').background, BackgroundColor.lightGrey);
    });

    test('the US asks for white', () {
      expect(byId('us_passport').background, BackgroundColor.white);
    });
  });

  group('neutral expression', () {
    test('a neutral face passes', () async {
      final photo = await runProcessor(spec: ukPassport());
      final check =
          photo.checks.firstWhere((c) => c.label == 'Neutral expression');
      expect(check.passed, isTrue, reason: check.detail);
    });

    test('a smiling face fails', () async {
      final subject = const SyntheticSubject();
      final photo = await runProcessor(
        spec: ukPassport(),
        faces: [subject.faceWith(smiling: 0.95)],
      );
      final check =
          photo.checks.firstWhere((c) => c.label == 'Neutral expression');
      expect(check.passed, isFalse);
      expect(check.detail, contains('smiling'));
    });

    test('a detector that will not classify never fails the photo', () async {
      // `smilingProbability` is nullable on ML Kit's `Face`. Null must read as
      // "not smiling", never as a failure the user cannot act on.
      final subject = const SyntheticSubject();
      final photo = await runProcessor(
        spec: ukPassport(),
        faces: [subject.faceWith(smiling: null)],
      );
      final check =
          photo.checks.firstWhere((c) => c.label == 'Neutral expression');
      expect(check.passed, isTrue, reason: check.detail);
    });
  });
}
