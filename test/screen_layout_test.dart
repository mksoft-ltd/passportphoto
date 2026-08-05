import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passport_photo_app/app/theme.dart';
import 'package:passport_photo_app/core/models/photo_spec.dart';
import 'package:passport_photo_app/core/services/preferences.dart';
import 'package:passport_photo_app/features/photo_capture/home_screen.dart';
import 'package:passport_photo_app/features/processing/processing_providers.dart';
import 'package:passport_photo_app/features/purchase/entitlement_controller.dart';
import 'package:passport_photo_app/features/purchase/paywall_screen.dart';
import 'package:passport_photo_app/features/specs/country_picker_screen.dart';
import 'package:passport_photo_app/features/specs/specs_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/crop_harness.dart';
import 'support/specs.dart';

/// Renders every screen at the sizes the app has to survive.
///
/// A RenderFlex overflow is reported as a test failure, so these catch the
/// layout breaking on a small phone or in landscape — neither of which is
/// visible while developing on one simulator, and both of which are what a
/// store reviewer's screenshot ends up showing.
///
/// The app is iPhone-only (`TARGETED_DEVICE_FAMILY = 1`), so the tablet sizes
/// the house pattern uses are left out; landscape stays, because iOS rotates
/// an iPhone app unless it is pinned, and a 320-wide phone stays because the
/// SE is still supported by the deployment target.
void main() {
  const sizes = <String, Size>{
    // iPhone SE 1st gen / 5s. In scope because the deployment target is iOS
    // 15.5, which those devices run.
    'small phone portrait': Size(320, 568),
    // iPhone SE 2nd/3rd gen and 8 — the smallest phone Apple still sells.
    'SE phone portrait': Size(375, 667),
    'phone portrait': Size(393, 852),
    'large phone portrait': Size(430, 932),
    'phone landscape': Size(852, 393),
  };

  Future<ProviderContainer> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    required Size size,
    bool unlocked = false,
    String? price = '£4.99',
    PhotoSpec? selectedSpec,
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Closing an ML Kit detector over a platform channel would throw when
        // the container is torn down.
        faceDetectorServiceProvider.overrideWithValue(StubFaceDetector()),
        entitlementProvider.overrideWith(
          () => _FixedEntitlement(unlocked: unlocked, price: price),
        ),
        // Read from disk rather than through `rootBundle`, so the list is
        // there on the first frame instead of behind a spinner that never
        // settles in a widget test.
        allSpecsProvider.overrideWith((ref) async => bundledSpecs()),
        if (selectedSpec != null)
          selectedSpecProvider.overrideWith((ref) => selectedSpec),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildLightTheme(), home: screen),
      ),
    );
    await tester.pump();
    return container;
  }

  sizes.forEach((label, size) {
    // The home screen's body used to be a `Column` with a `Spacer` inside a
    // `Padding`, with nothing scrollable around it. A `Spacer` cannot go below
    // zero, so once the fixed content was taller than the viewport the column
    // overflowed rather than scrolling — 51 px in landscape on every iPhone,
    // and 74-90 px at 320x568. Both are reachable: `Info.plist` allows
    // landscape, and the iOS 15.5 deployment target still covers the 320-wide
    // SE and 5s.
    //
    // Fixed in `home_screen.dart` (2026-08-05, stage 2): the body is now a
    // `SingleChildScrollView` over a `ConstrainedBox`/`IntrinsicHeight`, so the
    // `Spacer` still anchors the privacy footer to the bottom where there is
    // room and the screen scrolls where there is not. The skip these three
    // carried is gone, which is what now keeps that from regressing.
    group('at $label', () {
      group('home', () {
        testWidgets('the home screen lays out', (tester) async {
          await pumpScreen(
            tester,
            const HomeScreen(),
            size: size,
            selectedSpec: ukPassport(),
          );

          expect(find.text('Passport Photo Studio'), findsOneWidget);
          expect(find.text('Take a new photo'), findsOneWidget);
          expect(find.text('Pick from gallery'), findsOneWidget);
        });

        testWidgets('the home screen lays out before a spec is chosen', (
          tester,
        ) async {
          // First launch: the specs asset has not resolved yet, so the card
          // shows its placeholder and both actions are disabled. The longest
          // strings on this screen are the placeholders, so this is the tighter
          // of the two cases.
          await pumpScreen(tester, const HomeScreen(), size: size);
          expect(find.text('Choose a country & document'), findsOneWidget);
        });

        testWidgets('the home screen lays out unlocked', (tester) async {
          await pumpScreen(
            tester,
            const HomeScreen(),
            size: size,
            unlocked: true,
            selectedSpec: ukPassport(),
          );
          expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
        });
      });

      testWidgets('the paywall lays out', (tester) async {
        await pumpScreen(tester, const PaywallScreen(), size: size);

        expect(find.text('Passport Photo Studio Pro'), findsOneWidget);
        await _scrollTo(tester, find.text('Restore purchase'));
        expect(find.text('Unlock Pro — £4.99'), findsOneWidget);
        // Both stores require restore to be reachable without buying first.
        expect(find.text('Restore purchase'), findsOneWidget);
      });

      testWidgets('the paywall lays out with no price yet', (tester) async {
        // Offline, or the product has not propagated to the storefront. The
        // button must not invent a figure, so it renders a shorter label —
        // worth checking at every size rather than assuming a narrower string
        // is always safe.
        await pumpScreen(
          tester,
          const PaywallScreen(),
          size: size,
          price: null,
        );

        await _scrollTo(tester, find.text('Restore purchase'));
        expect(find.text('Unlock Pro'), findsOneWidget);
        expect(find.textContaining('Unlock Pro —'), findsNothing);
      });

      testWidgets('the paywall lays out once bought', (tester) async {
        // The thank-you panel replaces the whole offer, so it is a different
        // tree rather than a variation on the same one.
        await pumpScreen(
          tester,
          const PaywallScreen(),
          size: size,
          unlocked: true,
        );

        expect(find.text('Passport Photo Studio Pro'), findsOneWidget);
        expect(find.text('Restore purchase'), findsNothing);
        expect(find.text('Unlock Pro — £4.99'), findsNothing);
      });

      testWidgets('the country picker lays out', (tester) async {
        await pumpScreen(tester, const CountryPickerScreen(), size: size);
        // The list resolves from a bundled asset, which needs a real frame.
        await tester.pumpAndSettle();

        expect(find.text('Choose document'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('United Kingdom'), findsWidgets);
      });

      testWidgets('the country picker lays out with no matches', (
        tester,
      ) async {
        await pumpScreen(tester, const CountryPickerScreen(), size: size);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'zzzzzz');
        await tester.pumpAndSettle();

        expect(find.text('No matches.'), findsOneWidget);
      });
    });
  });

  group('text scaling', () {
    // Accessibility text sizes are where a Column of fixed-height rows breaks
    // first, and the App Store's accessibility guidance expects the app to
    // stay usable at them.
    testWidgets('the paywall survives the largest accessible text size', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          faceDetectorServiceProvider.overrideWithValue(StubFaceDetector()),
          entitlementProvider.overrideWith(
            () => _FixedEntitlement(unlocked: false, price: '£4.99'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: PaywallScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Passport Photo Studio Pro'), findsOneWidget);
    });
  });
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  if (tester.any(target)) return;
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).last,
  );
}

/// A settled entitlement, so the layout under test does not depend on a store
/// round trip that never completes off-device.
class _FixedEntitlement extends EntitlementController {
  _FixedEntitlement({required this.unlocked, required this.price});

  final bool unlocked;
  final String? price;

  @override
  EntitlementState build() => EntitlementState(
    unlocked: unlocked,
    price: price,
    storeAvailable: price != null,
  );
}
