import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:passport_photo_app/app/router.dart';
import 'package:passport_photo_app/app/theme.dart';
import 'package:passport_photo_app/core/constants/app_info.dart';
import 'package:passport_photo_app/core/services/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Exercises the camera permission request on a real iOS runtime.
///
/// ## Why this exists
///
/// `permission_handler_apple` compiles each of its nineteen permission
/// strategies behind a preprocessor macro that defaults to `0`. With
/// `PERMISSION_CAMERA` unset — which is how this app was configured through
/// stages 1 to 4 — `AudioVideoPermissionStrategy` compiles to a class with an
/// empty method table, `PermissionManager` calls straight through without a
/// `respondsToSelector:` check, and `Permission.camera.request()` raises
/// `NSInvalidArgumentException: unrecognized selector sent to instance`.
/// Flutter does not catch Objective-C exceptions, so the app takes a SIGABRT
/// the first time anyone taps "Take a new photo" — the primary way into the
/// product.
///
/// **Every gate was green while that was true.** `flutter analyze`,
/// `flutter test`, `flutter build ios` and the screenshot harness are all blind
/// to it: the empty class links fine, and `SCREENSHOT_MODE` seeds a fixture
/// instead of opening the camera. The failure only exists at runtime.
///
/// So this test does the one thing that catches it: it calls the real thing on
/// a real runtime. If the strategy is empty again, the Objective-C exception
/// tears down the test process and this fails loudly rather than reaching an
/// assertion at all — which is the point. `test/ios_permission_macros_test.dart`
/// pins the build configuration in the fast suite; this proves the
/// configuration actually works.
///
/// ## Running it
///
/// ```
/// xcrun simctl privacy booted reset camera com.froggyeye.passportphotostudio
/// flutter test integration_test/camera_permission_test.dart -d <simulator id>
/// ```
///
/// ## What "pass" looks like on a simulator
///
/// A simulator has no camera hardware, so `availableCameras()` comes back empty
/// and the screen settles on its "no camera is available" recovery state. That
/// is the correct outcome and it is still decisive evidence: reaching *any*
/// resolved state means the permission call returned instead of aborting the
/// process. On real hardware the same run ends on the live preview instead.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Real wall-clock time. The permission request is a platform round trip and
  /// `pumpAndSettle` would return before it resolves.
  Future<void> settle(WidgetTester tester, {int cycles = 30}) async {
    for (var i = 0; i < cycles; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }

  testWidgets('requesting the camera permission does not abort the app',
      (tester) async {
    expect(
      AppInfo.screenshotMode,
      isFalse,
      reason: 'SCREENSHOT_MODE seeds a fixture and never opens the camera, so '
          'this test proves nothing under it. Run without the dart-define.',
    );

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          title: AppInfo.appName,
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: ThemeMode.light,
          routerConfig: buildRouter(),
        ),
      ),
    );
    await settle(tester);

    // The specs asset has to have loaded and seeded a selection, or the tile is
    // disabled and the tap does nothing — which would make this test pass
    // without testing anything. Outside SCREENSHOT_MODE the seed is
    // `icao_generic`, whose card reads "ICAO Standard (Generic) · Passport".
    final tile = find.text('Take a new photo');
    expect(tile, findsOneWidget);
    expect(
      find.textContaining(' · '),
      findsWidgets,
      reason: 'no spec is selected, so the capture tile is disabled and the '
          'tap below would be a no-op',
    );

    await tester.tap(tile);
    // Everything past here runs only if `Permission.camera.request()` returned.
    await settle(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'the capture screen never resolved — the permission request '
            'did not complete');

    // Any of these is a pass; each means the strategy answered rather than
    // raising. On a simulator there is no camera device, so the "no camera"
    // recovery state is the expected one; on hardware it is the live preview.
    final livePreview = find.byType(CameraPreview).evaluate().isNotEmpty;
    final noCamera =
        find.textContaining('No camera is available').evaluate().isNotEmpty;
    final permissionRecovery =
        find.textContaining('permission to use the camera').evaluate().isNotEmpty ||
            find.textContaining('Camera access is needed').evaluate().isNotEmpty;

    expect(
      livePreview || noCamera || permissionRecovery,
      isTrue,
      reason: 'the capture screen settled into no recognised state — neither a '
          'preview, nor the no-camera message, nor a permission recovery',
    );

    // And whichever state it is, there is a way onward. A dead end here is
    // CQ-5: before 2026-08-05 a denied permission left the screen showing one
    // sentence with no action on it, permanently, on the app's primary flow.
    if (!livePreview) {
      expect(
        find.text('Pick from gallery instead'),
        findsOneWidget,
        reason: 'the capture screen failed with no route onward',
      );
    }

    debugPrint(
      'CAMERA-PERMISSION-PROBE: livePreview=$livePreview noCamera=$noCamera '
      'permissionRecovery=$permissionRecovery platform=${Platform.operatingSystem}',
    );
  });
}
