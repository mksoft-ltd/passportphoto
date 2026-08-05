import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passport_photo_app/core/constants/app_info.dart';

/// Screenshot mode grants the paid unlock. If the `!kReleaseMode` term were
/// ever dropped, a release build made with `--dart-define=SCREENSHOT_MODE=true`
/// would ship the in-app purchase free to every user — and nothing about the
/// app would look wrong, so no manual check would catch it.
void main() {
  test('screenshot mode is off unless the define is set', () {
    // The suite runs without the define, so this is the normal-build case.
    expect(AppInfo.screenshotMode, isFalse);
  });

  test('screenshot mode is gated on !kReleaseMode in source', () {
    final source = File('lib/core/constants/app_info.dart').readAsStringSync();
    expect(
      source.contains('!kReleaseMode &&'),
      isTrue,
      reason: 'AppInfo.screenshotMode must be conjoined with !kReleaseMode so '
          'release builds fold it to false and tree-shake the seeding.',
    );
    // Sanity check that the constant this guard talks about still comes from
    // foundation, i.e. the import has not been dropped along with the term.
    expect(kReleaseMode, isFalse);
  });
}
