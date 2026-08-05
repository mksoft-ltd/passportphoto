import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:passport_photo_app/app/router.dart';
import 'package:passport_photo_app/app/theme.dart';
import 'package:passport_photo_app/core/constants/app_info.dart';
import 'package:passport_photo_app/core/services/preferences.dart';
import 'package:passport_photo_app/features/purchase/entitlement_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Drives the app through the five store screenshots.
///
/// Run it per device, always with the harness flag — without it the app comes
/// up with no photo and no spec, and the shots are of an empty tool:
///
/// ```
/// flutter drive \
///   --driver=test_driver/integration_test.dart \
///   --target=integration_test/screenshots_test.dart \
///   --dart-define=SCREENSHOT_MODE=true \
///   -d <device id>
/// ```
///
/// `SCREENSHOT_MODE` seeds the UK passport spec, a finished crop with all six
/// compliance checks green, and the unlocked state. The paywall shot needs the
/// opposite, so it runs in a second launch with the entitlement overridden
/// back to locked — otherwise it would photograph the thank-you panel instead
/// of the offer.
///
/// Shots, in the order they are pitched to someone reading the store listing:
///
/// | file | what it shows |
/// |---|---|
/// | `01_result` | the finished photo and its compliance report |
/// | `02_sheet` | the 4x6" print sheet you take to a shop |
/// | `03_home` | the tool, with a document already chosen |
/// | `04_picker` | every country, none of them locked |
/// | `05_pro` | the one-time unlock |
///
/// The numbering is marketing priority, not the order the shots are taken —
/// they are filenames. It comes from stage 2, and
/// `store_assets/screenshots/render.sh` hard-codes the same five slugs and
/// reads them from `raw/<ios|android>/`, so renaming anything here renders a
/// "capture missing" placeholder there instead. Stage 5 (`docs/ASO.md` §5)
/// swapped positions 3 and 4 — the privacy shot outranks the country-count
/// shot, which is the comparison this app loses — and rewrote every headline;
/// `render.sh` and `screens.js` were renamed to match.
///
/// Captured in light appearance deliberately (`themeMode: ThemeMode.light`):
/// the whole set is framed as a white app screen on navy, and a dark capture
/// breaks the set. See `store_assets/BRAND.md`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Android renders into an image before it can be captured; on iOS the
    // plugin grabs the screen directly.
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
    }
  });

  /// Real time for the fixture render and the layout to settle.
  ///
  /// Deliberately not `pumpAndSettle`: the seeded photo is drawn in a
  /// background isolate and the review screen shows a spinner while it works,
  /// so the tree is not idle when the work is outstanding and is not finished
  /// when it first goes idle.
  Future<void> settle(WidgetTester tester, {int cycles = 16}) async {
    for (var i = 0; i < cycles; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
  }

  /// Brings the app up on its real router and hands back a handle to it, so
  /// the screens that take a source path as `extra` can be reached without a
  /// photo library.
  Future<GoRouter> launch(WidgetTester tester, {bool asFreeUser = false}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = buildRouter();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (asFreeUser) entitlementProvider.overrideWith(_FreeUser.new),
      ],
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
          routerConfig: router,
        ),
      ),
    );
    await settle(tester);
    return router;
  }

  testWidgets('captures the tool, the specs, the result and the sheet',
      (tester) async {
    expect(
      AppInfo.screenshotMode,
      isTrue,
      reason: 'run this with --dart-define=SCREENSHOT_MODE=true, or the shots '
          'will be of an app with no photo in it',
    );

    final router = await launch(tester);

    // 03_home - the tool, with the UK passport already selected.
    expect(find.text(AppInfo.appName), findsOneWidget);
    expect(
      find.text('United Kingdom · Passport'),
      findsOneWidget,
      reason: 'the seeded spec did not load, so the card is empty',
    );
    await binding.takeScreenshot('03_home');

    // 04_picker - where the "every country, nothing locked" claim in the
    // listing is actually visible: no lock badges anywhere.
    router.push('/picker');
    await settle(tester, cycles: 20);
    expect(find.text('Choose document'), findsOneWidget);
    // Not a specific country: the list is a lazy `ListView.separated`, so
    // anything past the first screenful is not built and cannot be found.
    expect(
      find.byType(ListTile),
      findsWidgets,
      reason: 'the specs asset had not loaded, so the picker is still a '
          'spinner',
    );
    await binding.takeScreenshot('04_picker');

    router.pop();
    await settle(tester, cycles: 8);

    // 01_result - the finished photo with its compliance report, and the lead
    // shot: the report is the reason to trust the app.
    //
    // `/result` takes the source path as `extra`; under screenshot mode the
    // processor returns the fixture and never looks at the path, so any
    // non-null string reaches the same screen a real photo would.
    router.push('/result', extra: 'demo');
    await settle(tester, cycles: 24);
    expect(find.text('Review'), findsOneWidget);

    // Every check green, asserted without pinning how many there are. The
    // count has already changed once — an eye-line check was added in the
    // audit round, turning "6 / 6" into "7 / 7" — and a harness that pins the
    // number fails for the one reason that does not matter while staying
    // silent about the one that does. What matters is that no red cross is in
    // the lead marketing shot.
    expect(find.byIcon(Icons.error_rounded), findsNothing,
        reason: 'a failing check is in the screenshot of the compliance '
            'report, which is the shot that sells the app');
    final tally = find.textContaining(RegExp(r'^\d+ / \d+ passed$'));
    expect(tally, findsOneWidget);
    final counts = RegExp(r'(\d+) / (\d+) passed')
        .firstMatch((tally.evaluate().single.widget as Text).data!)!;
    expect(counts.group(1), counts.group(2),
        reason: 'the fixture is meant to pass every check');
    expect(int.parse(counts.group(2)!), greaterThanOrEqualTo(6));
    await binding.takeScreenshot('01_result');

    // 02_sheet - the print sheet, which is what Pro actually buys.
    router.push('/sheet', extra: 'demo');
    await settle(tester, cycles: 24);
    expect(find.text('4×6" print sheet'), findsOneWidget);
    await binding.takeScreenshot('02_sheet');
  });

  testWidgets('captures the one-time unlock', (tester) async {
    expect(AppInfo.screenshotMode, isTrue);

    // Seeded state has Pro already granted, which would photograph the
    // thank-you panel. This launch is a user who has not paid.
    final router = await launch(tester, asFreeUser: true);

    router.push('/pro');
    await settle(tester);
    expect(find.text(AppInfo.proDisplayName), findsOneWidget);

    // The offer and the button sit below the fold on a phone, and a paywall
    // screenshot without its price is worth nothing — this shot is also
    // Apple's mandatory review screenshot for the IAP — so scroll them into
    // view before capturing.
    // Stop at the button rather than at "Restore purchase" below it: scrolling
    // the last few rows into view also pushes the table's "Free / Pro" column
    // headers off the top, and a comparison table whose columns are unlabelled
    // is worse than useless in a store listing.
    await tester.scrollUntilVisible(
      find.text('Unlock Pro — $_harnessPrice'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await settle(tester, cycles: 8);

    expect(find.text('Unlock Pro — $_harnessPrice'), findsOneWidget);
    expect(find.text('Restore purchase'), findsOneWidget);
    await binding.takeScreenshot('05_pro');
  });
}

/// The price the paywall capture shows.
///
/// A simulator is not signed in to a sandbox account and the IAP does not
/// exist in either console yet, so `queryProductDetails` returns nothing and
/// the real button falls back to a bare "Unlock Pro" — the service
/// deliberately does not invent a figure. So the harness supplies the price the
/// product will be created at: £4.99, per `PIPELINE.md`.
///
/// GBP because the publishing entity is UK-based and the listing's primary
/// language is English (U.K.); both locales share one screenshot set.
///
/// **This lives in `integration_test/` and ships in no build.** If the price
/// tier changes, this constant and the captured shot both have to change with
/// it — re-capture against a sandbox account at stage 7 so the figure is
/// genuinely store-resolved rather than seeded.
const String _harnessPrice = '£4.99';

/// The entitlement a not-yet-paying user has, so the paywall shows the offer
/// rather than the thank-you panel the seeded unlocked state would produce.
class _FreeUser extends EntitlementController {
  @override
  EntitlementState build() => const EntitlementState(
        unlocked: false,
        price: _harnessPrice,
        storeAvailable: true,
      );
}
