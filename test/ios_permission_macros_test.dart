import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `permission_handler_apple` gates every one of its nineteen permission
/// strategies behind a preprocessor macro, and **every macro defaults to 0**:
///
/// ```objc
/// #ifndef PERMISSION_CAMERA
///     #define PERMISSION_CAMERA 0
/// #endif
/// ```
///
/// With `PERMISSION_CAMERA` unset, `AudioVideoPermissionStrategy` compiles to
/// `@implementation AudioVideoPermissionStrategy @end` — a class declared as
/// conforming to `PermissionStrategy` that implements none of it.
/// `PermissionManager` does not check `respondsToSelector:`; it constructs the
/// strategy and calls straight through, Objective-C raises
/// `NSInvalidArgumentException`, Flutter does not catch Objective-C exceptions,
/// and the app takes a SIGABRT. Every iOS user reached that on the app's
/// primary flow — tapping "Take a new photo" — for the whole of stage 1-4.
///
/// This is invisible to `flutter analyze`, to `flutter test`, to
/// `flutter build ios`, and to the screenshot harness (`SCREENSHOT_MODE` seeds
/// a fixture and never opens the camera). The build was green the entire time.
/// The only static evidence is `otool -oV` on the built framework reporting
/// `baseMethods 0x0`.
///
/// So the Podfile is pinned here, where a dependency bump or a regenerated
/// Podfile fails a test instead of shipping a crash. This does not replace
/// exercising the flow on a simulator — no unit test can see the runtime
/// behaviour — but it does stop the configuration silently reverting.
void main() {
  late final String podfile;

  setUpAll(() {
    podfile = File('ios/Podfile').readAsStringSync();
  });

  test('the Podfile enables the camera permission strategy', () {
    expect(
      podfile,
      contains('GCC_PREPROCESSOR_DEFINITIONS'),
      reason: 'permission_handler_apple needs the macro block in post_install, '
          'or every permission strategy compiles to an empty class.',
    );
    expect(
      podfile,
      contains('PERMISSION_CAMERA=1'),
      reason: 'Permission.camera.request() sends an unrecognized selector '
          'without this, and the app aborts.',
    );
    expect(
      podfile,
      contains(r'$(inherited)'),
      reason: r'dropping $(inherited) discards the definitions CocoaPods and '
          'Flutter set for each configuration.',
    );
  });

  test('no permission beyond the camera is compiled in', () {
    // The app declares three usage strings and asks for one runtime
    // permission. Every other macro left at 0 keeps Contacts, Location,
    // Microphone, Speech, Media Library, Sensors, Bluetooth, Notifications and
    // AppTrackingTransparency out of the binary — an absence the store privacy
    // answers depend on, and one a reviewer can check with `otool`.
    final enabled = RegExp(r'PERMISSION_[A-Z_]+=1')
        .allMatches(podfile)
        .map((m) => m.group(0))
        .toSet();
    expect(
      enabled,
      {'PERMISSION_CAMERA=1'},
      reason: 'a new permission macro was enabled. Update '
          'docs/PRODUCT_SPEC.md and the store privacy answers with it.',
    );
  });

  test('the generated Pods project carries the macro', () {
    // The Podfile is the intent; this is the artefact the compiler reads. They
    // diverge whenever someone edits the Podfile and forgets `pod install`,
    // which is exactly the state that shipped.
    final pods = File('ios/Pods/Pods.xcodeproj/project.pbxproj');
    if (!pods.existsSync()) {
      markTestSkipped('ios/Pods not installed — run `cd ios && pod install`.');
      return;
    }
    expect(
      pods.readAsStringSync(),
      contains('PERMISSION_CAMERA=1'),
      reason: 'the Podfile says PERMISSION_CAMERA=1 but the generated project '
          'does not. Run `cd ios && pod install`.',
    );
  });
}
