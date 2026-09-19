import 'package:flutter_test/flutter_test.dart';
import 'package:passport_photo_app/core/demo/demo_data.dart';

import 'support/specs.dart';

/// The `SCREENSHOT_MODE` fixture is what the store listing photographs.
///
/// Two of the five shots are the compliance report, so a check that goes red in
/// the fixture ships a screenshot of the app failing its own test — and nothing
/// would catch it, because the harness captures whatever is on screen.
///
/// The eye-line check is computed from the drawing's own geometry
/// rather than hard-coded to `passed: true`, which is the right call and is
/// also why it can now drift: redrawing the portrait, or changing a spec's
/// eye-line band, could put it out of range. That is what these assert.
void main() {
  test('the demo fixture reports every check green, for every bundled spec',
      () {
    for (final spec in bundledSpecs()) {
      final checks = DemoData.checksFor(spec);
      expect(checks, hasLength(8), reason: spec.id);
      for (final c in checks) {
        expect(
          c.passed,
          isTrue,
          reason: '${spec.id}: "${c.label}" is red in the screenshot fixture — '
              '${c.detail}',
        );
      }
    }
  });

  test('the fixture eye line matches the portrait the fixture draws', () {
    // `renderDemoPortrait` puts the crown at 0.085 of the height and the chin at
    // 0.785, with the eyes 0.42 of the way down the head. If someone retunes the
    // drawing without retuning the constant, the report beside it starts quoting
    // a measurement of a different picture.
    const crown = 0.085;
    const chin = 0.785;
    const eyeWithinHead = 0.42;
    final fromBottom = 1 - (crown + eyeWithinHead * (chin - crown));

    expect(
      DemoData.portraitEyeLineFromBottom,
      closeTo(fromBottom, 0.001),
      reason: 'DemoData.portraitEyeLineFromBottom no longer describes the '
          'portrait renderDemoPortrait actually draws',
    );
  });
}
