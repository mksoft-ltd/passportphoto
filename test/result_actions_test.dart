import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:passport_photo_app/app/theme.dart';
import 'package:passport_photo_app/core/demo/demo_data.dart';
import 'package:passport_photo_app/core/services/preferences.dart';
import 'package:passport_photo_app/core/services/review_prompter.dart';
import 'package:passport_photo_app/features/export/export_service.dart';
import 'package:passport_photo_app/features/export/print_sheet_screen.dart';
import 'package:passport_photo_app/features/photo_capture/result_screen.dart';
import 'package:passport_photo_app/features/processing/photo_processor.dart';
import 'package:passport_photo_app/features/processing/processed_photo.dart';
import 'package:passport_photo_app/features/processing/processing_providers.dart';
import 'package:passport_photo_app/features/purchase/entitlement_controller.dart';
import 'package:passport_photo_app/features/purchase/paywall_screen.dart';
import 'package:passport_photo_app/features/specs/specs_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/specs.dart';

/// The result screen's buttons, its verdict line, and where they lead.
///
/// The CTAs are chosen by outcome: a passing photo sells the print-ready file,
/// a failing one does not, and both routes back to the camera keep the
/// document the user picked.
void main() {
  const sourcePath = '/tmp/result_actions_source.jpg';
  final spec = ukPassport();

  Uint8List jpeg() => Uint8List.fromList(img.encodeJpg(
      img.Image(width: spec.widthPx, height: spec.heightPx),
      quality: 60));

  /// [failing] kinds are flipped to failed; everything else passes.
  ProcessedPhoto photo({Set<CheckKind> failing = const {}}) => ProcessedPhoto(
        spec: spec,
        jpegBytes: jpeg(),
        widthPx: spec.widthPx,
        heightPx: spec.heightPx,
        checks: [
          for (final c in DemoData.checksFor(spec))
            ValidationCheck(
              kind: c.kind,
              label: c.label,
              passed: !failing.contains(c.kind),
              detail: c.detail,
            ),
        ],
      );

  late ProviderContainer container;
  late _FakeExport export;
  late GoRouter router;

  Future<void> pump(
    WidgetTester tester, {
    ProcessedPhoto? result,
    Object? error,
    bool unlocked = false,
    String? price = '£4.99',
    int session = 0,
  }) async {
    // Tall enough that every button is laid out without scrolling.
    tester.view.physicalSize = const Size(393, 2400) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(
        {ReviewPrompter.sessionCountKey: session});
    final prefs = await SharedPreferences.getInstance();

    // Created here, not lazily by the provider, so a test that never saves
    // still gets a fresh, empty fake rather than the previous test's.
    export = _FakeExport(() => container.read(isProUnlockedProvider));
    container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      entitlementProvider
          .overrideWith(() => _Entitlement(unlocked: unlocked, price: price)),
      selectedSpecProvider.overrideWith((ref) => spec),
      processedPhotoProvider(sourcePath).overrideWith((ref) async {
        if (error != null) throw error;
        return result!;
      }),
      exportServiceProvider.overrideWithValue(export),
      reviewClientProvider.overrideWithValue(_NoReviews()),
    ]);
    addTearDown(container.dispose);

    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        // Stands in for the camera: shows which document it was opened for,
        // which is the thing "Fix and re-shoot" has to preserve.
        GoRoute(
          path: '/capture',
          builder: (_, _) => Consumer(
            builder: (_, ref, _) =>
                Text('capture:${ref.watch(selectedSpecProvider)?.id}'),
          ),
        ),
        GoRoute(
          path: '/result',
          builder: (_, _) => const ResultScreen(sourcePath: sourcePath),
        ),
        GoRoute(path: '/pro', builder: (_, _) => const PaywallScreen()),
        GoRoute(
          path: '/sheet',
          builder: (_, _) => const PrintSheetScreen(sourcePath: sourcePath),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: buildLightTheme(),
        routerConfig: router,
      ),
    ));
    router.push('/result');
    await tester.pumpAndSettle();
  }

  Finder filled(String text) => find.descendant(
      of: find.byWidgetPredicate((w) => w is FilledButton),
      matching: find.text(text));

  group('a photo that passed every check', () {
    testWidgets('free: the print-ready photo is the primary action, with the '
        'store price', (tester) async {
      await pump(tester, result: photo());

      expect(filled('Get the print-ready photo — £4.99'), findsOneWidget);
      expect(
        find.descendant(
            of: find.byWidgetPredicate((w) => w is TextButton),
            matching: find.text('Save watermarked preview')),
        findsOneWidget,
      );
      expect(find.text('Fix and re-shoot'), findsNothing);
      expect(find.text('All 8 checks passed for United Kingdom Passport'),
          findsOneWidget);
    });

    testWidgets('free, price not loaded: no figure is invented',
        (tester) async {
      await pump(tester, result: photo(), price: null);
      expect(filled('Get the print-ready photo'), findsOneWidget);
      expect(find.textContaining('£'), findsNothing);
    });

    testWidgets('Pro: full-resolution save stays the primary action',
        (tester) async {
      await pump(tester, result: photo(), unlocked: true);
      expect(filled('Save full-resolution photo'), findsOneWidget);
      expect(find.textContaining('Get the print-ready photo'), findsNothing);
      expect(find.text('Free saves are watermarked'), findsNothing);
    });
  });

  group('a photo that failed a check', () {
    testWidgets('no upsell; fixing it is the primary action; preview save '
        'still there', (tester) async {
      await pump(tester,
          result: photo(failing: {CheckKind.background, CheckKind.eyeLine}));

      expect(filled('Fix and re-shoot'), findsOneWidget);
      expect(find.text('Free saves are watermarked'), findsNothing);
      expect(find.textContaining('Get the print-ready photo'), findsNothing);
      expect(find.text('Save watermarked preview'), findsOneWidget);
      expect(find.text('Pick another photo'), findsOneWidget);
      expect(find.text('2 of 8 checks need attention'), findsOneWidget);
    });

    testWidgets('one failure reads in the singular', (tester) async {
      await pump(tester, result: photo(failing: {CheckKind.eyesOpen}));
      expect(find.text('1 of 8 checks needs attention'), findsOneWidget);
    });

    testWidgets('failed checks are listed first, each with its fix',
        (tester) async {
      await pump(tester,
          result: photo(failing: {CheckKind.background, CheckKind.eyeLine}));

      final backgroundY = tester.getTopLeft(find.text('Background')).dy;
      final eyeLineY = tester.getTopLeft(find.text('Eye line within spec')).dy;
      final firstPassY =
          tester.getTopLeft(find.text('Single face detected')).dy;
      expect(eyeLineY, lessThan(firstPassY));
      expect(backgroundY, lessThan(firstPassY));

      expect(find.text('How to fix: ${CheckKind.background.fixHint}'),
          findsOneWidget);
      expect(find.text('How to fix: ${CheckKind.eyeLine.fixHint}'),
          findsOneWidget);
      // Only under the failed rows.
      expect(find.textContaining('How to fix:'), findsNWidgets(2));
    });

    testWidgets('"Fix and re-shoot" opens the camera for the same document, '
        'with Home behind it', (tester) async {
      await pump(tester, result: photo(failing: {CheckKind.background}));

      await tester.tap(find.text('Fix and re-shoot'));
      await tester.pumpAndSettle();

      expect(find.text('capture:uk_passport'), findsOneWidget);
      expect(router.canPop(), isTrue);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });
  });

  testWidgets('every hint is calm, short and never claims approval', (_) async {
    for (final kind in CheckKind.values) {
      expect(kind.fixHint, isNot(contains('!')), reason: kind.name);
      expect(kind.fixHint.length, lessThan(140), reason: kind.name);
      expect(
        kind.fixHint.toLowerCase(),
        isNot(matches(RegExp(r'approv|accept|complian|certif|guarantee'))),
        reason: kind.name,
      );
    }
  });

  group('processing error', () {
    testWidgets('"Try again" opens the camera for the same document',
        (tester) async {
      await pump(tester, error: PhotoProcessingFailure('No face found.'));

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('capture:uk_passport'), findsOneWidget);
    });

    testWidgets('"Pick another photo" goes home', (tester) async {
      await pump(tester, error: PhotoProcessingFailure('No face found.'));

      await tester.tap(find.text('Pick another photo'));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('suppresses the rating prompt for the session',
        (tester) async {
      await pump(tester,
          error: PhotoProcessingFailure('No face found.'), session: 5);
      final asked = await container.read(reviewPrompterProvider).onSaveSucceeded(
          fullResolution: true, allChecksPassed: true, isMounted: () => true);
      expect(asked, isFalse);
    });
  });

  group('resuming the save after the paywall', () {
    testWidgets('buying Pro closes the paywall and saves the full-resolution '
        'photo without another tap', (tester) async {
      await pump(tester, result: photo());

      await tester.tap(find.text('Get the print-ready photo — £4.99'));
      await tester.pumpAndSettle();
      expect(find.byType(PaywallScreen), findsOneWidget);

      (container.read(entitlementProvider.notifier) as _Entitlement).unlock();
      await tester.pumpAndSettle();

      expect(find.byType(PaywallScreen), findsNothing);
      expect(export.saves, [true],
          reason: 'one save, made with the unlock in place');
      expect(find.text('Full-resolution photo saved to your gallery.'),
          findsOneWidget);
    });

    testWidgets('print sheet: buying Pro from the gate saves the sheet',
        (tester) async {
      await pump(tester, result: photo());
      router.push('/sheet');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unlock Pro to save this sheet'));
      await tester.pumpAndSettle();
      expect(find.byType(PaywallScreen), findsOneWidget);

      // The sheet preview watches the entitlement and rebuilds on unlock; the
      // save must survive that rebuild.
      (container.read(entitlementProvider.notifier) as _Entitlement).unlock();
      await tester.pumpAndSettle();

      expect(find.byType(PaywallScreen), findsNothing);
      expect(export.sheetSaves, [false, true]);
      expect(find.text('Print sheet saved to your gallery.'), findsOneWidget);
    });

    testWidgets('closing the paywall saves nothing', (tester) async {
      await pump(tester, result: photo());

      await tester.tap(find.text('Get the print-ready photo — £4.99'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(PaywallScreen), findsNothing);
      expect(export.saves, isEmpty);
      expect(find.byType(ResultScreen), findsOneWidget);
    });

    testWidgets('a paywall opened while already Pro does not close itself',
        (tester) async {
      await pump(tester, result: photo(), unlocked: true);
      router.push('/pro');
      await tester.pumpAndSettle();
      expect(find.text('Pro is active'), findsOneWidget);
      expect(find.text('Rate the app'), findsOneWidget);
    });
  });
}

class _Entitlement extends EntitlementController {
  _Entitlement({required this.unlocked, required this.price});

  final bool unlocked;
  final String? price;

  @override
  EntitlementState build() => EntitlementState(
        unlocked: unlocked,
        price: price,
        storeAvailable: price != null,
      );

  /// What a completed purchase does to the state, without a store.
  void unlock() => state = state.copyWith(unlocked: true);
}

/// Records each save as whether it was made unlocked, and writes nothing.
class _FakeExport implements ExportService {
  _FakeExport(this._isUnlocked);

  final bool Function() _isUnlocked;
  final saves = <bool>[];

  @override
  Future<ExportResult> savePhoto(ProcessedPhoto photo) async {
    final unlocked = _isUnlocked();
    saves.add(unlocked);
    return ExportResult(
      outcome: unlocked ? ExportOutcome.saved : ExportOutcome.savedPreview,
      message: unlocked
          ? 'Full-resolution photo saved to your gallery.'
          : 'Watermarked preview saved.',
    );
  }

  final sheetSaves = <bool>[];

  @override
  Future<ExportResult> savePrintSheet(ProcessedPhoto photo) async {
    final unlocked = _isUnlocked();
    sheetSaves.add(unlocked);
    return unlocked
        ? const ExportResult(
            outcome: ExportOutcome.saved,
            message: 'Print sheet saved to your gallery.')
        : const ExportResult(
            outcome: ExportOutcome.requiresPro,
            message: 'The 4×6" print sheet is part of Pro.');
  }

  @override
  Future<Uint8List> buildSheetPreview(ProcessedPhoto photo) async =>
      Uint8List.fromList(
          img.encodeJpg(img.Image(width: 60, height: 40), quality: 60));
}

class _NoReviews implements ReviewClient {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<void> requestReview() async {}

  @override
  Future<void> openStoreListing() async {}
}
