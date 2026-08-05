import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:passport_photo_app/core/constants/app_info.dart';
import 'package:passport_photo_app/core/services/preferences.dart';
import 'package:passport_photo_app/features/purchase/entitlement_controller.dart';
import 'package:passport_photo_app/features/purchase/purchase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_store.dart';

/// The Pro flag: who is allowed to set it, and what the paywall is told while
/// it is being set.
///
/// The store is the source of truth and the local flag is only a cache, so the
/// two failure modes that matter are opposite: unlocking somebody who has not
/// paid, and failing to restore somebody who has. Both stores test the second
/// one during review.
void main() {
  late FakeStore store;
  late PurchaseService service;

  Future<ProviderContainer> boot({Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        purchaseServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Lets the store's async init and any stream delivery settle.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  setUp(() {
    store = FakeStore();
    service = PurchaseService(iap: store);
  });

  tearDown(() async {
    await service.dispose();
    await store.dispose();
  });

  group('initial state', () {
    test('starts locked on a fresh install', () async {
      final container = await boot();
      expect(container.read(entitlementProvider).unlocked, isFalse);
      expect(container.read(isProUnlockedProvider), isFalse);
    });

    test('reads the cached unlock so a paid user is never shown locked',
        () async {
      // Synchronous on purpose: the result screen decides between "Save
      // full-resolution photo" and "Save watermarked preview" on its first
      // build, and a paid user must not see the wrong one even for a frame.
      final container = await boot(prefs: {'pro_unlocked': true});
      expect(container.read(entitlementProvider).unlocked, isTrue);
    });

    test('picks up the storefront price once the store answers', () async {
      final container = await boot();
      expect(container.read(entitlementProvider).price, isNull);

      await settle();
      expect(container.read(entitlementProvider).price, '£4.99');
      expect(container.read(entitlementProvider).storeAvailable, isTrue);
    });

    test('leaves the price null when the store cannot be reached', () async {
      store.available = false;
      final container = await boot();
      await settle();

      expect(container.read(entitlementProvider).price, isNull);
      expect(container.read(entitlementProvider).storeAvailable, isFalse);
      // Still usable: everything except the export is free, so an offline
      // launch must not look broken.
      expect(container.read(entitlementProvider).errorMessage, isNull);
    });
  });

  group('purchase', () {
    test('goes busy, then unlocks when the store confirms', () async {
      final container = await boot();
      await settle();
      final controller = container.read(entitlementProvider.notifier);

      final pending = controller.purchase();
      expect(container.read(entitlementProvider).busy, isTrue);
      await pending;

      // Still busy: the sheet is up and the store has not answered yet.
      expect(container.read(entitlementProvider).busy, isTrue);
      expect(container.read(entitlementProvider).unlocked, isFalse);

      store.emit([
        purchaseUpdate(
          productId: AppInfo.proProductId,
          status: PurchaseStatus.purchased,
        ),
      ]);
      await settle();

      expect(container.read(entitlementProvider).unlocked, isTrue);
      expect(container.read(entitlementProvider).busy, isFalse);
    });

    test('writes the unlock through to preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          purchaseServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      container.read(entitlementProvider);
      await settle();

      store.emit([
        purchaseUpdate(
          productId: AppInfo.proProductId,
          status: PurchaseStatus.purchased,
        ),
      ]);
      await settle();

      // Survives the next launch without another round trip to the store.
      expect(preferences.getBool('pro_unlocked'), isTrue);
    });

    test('backing out of the sheet gives the buttons back, quietly', () async {
      final container = await boot();
      await settle();
      await container.read(entitlementProvider.notifier).purchase();

      store.emit([
        purchaseUpdate(
          productId: AppInfo.proProductId,
          status: PurchaseStatus.canceled,
        ),
      ]);
      await settle();

      expect(container.read(entitlementProvider).busy, isFalse);
      expect(container.read(entitlementProvider).unlocked, isFalse);
      // Cancelling is a choice, not a fault. An error toast here would be the
      // app scolding someone for changing their mind.
      expect(container.read(entitlementProvider).errorMessage, isNull);
    });

    test('a declined payment surfaces a message', () async {
      final container = await boot();
      await settle();
      await container.read(entitlementProvider.notifier).purchase();

      store.emit([
        purchaseUpdate(
          productId: AppInfo.proProductId,
          status: PurchaseStatus.error,
          error: IAPError(source: 'test', code: 'declined', message: 'nope'),
        ),
      ]);
      await settle();

      expect(container.read(entitlementProvider).busy, isFalse);
      expect(container.read(entitlementProvider).unlocked, isFalse);
      expect(
        container.read(entitlementProvider).errorMessage,
        contains('not been charged'),
      );
    });

    test('a sheet that will not open reports without staying busy', () async {
      final container = await boot();
      await settle();
      store.throwOnBuy = true;

      await container.read(entitlementProvider.notifier).purchase();

      expect(container.read(entitlementProvider).busy, isFalse);
      expect(
        container.read(entitlementProvider).errorMessage,
        contains('Could not start the purchase'),
      );
    });

    test('says nothing about a store error nobody was waiting for', () async {
      // A stale transaction resolving in the background has nothing to do with
      // anything the user just did, and a toast about it would be baffling.
      final container = await boot();
      await settle();

      store.emit([
        purchaseUpdate(
          productId: AppInfo.proProductId,
          status: PurchaseStatus.error,
          error: IAPError(source: 'test', code: 'stale', message: 'old'),
        ),
      ]);
      await settle();

      expect(container.read(entitlementProvider).errorMessage, isNull);
    });

    test('ignores a second tap while one purchase is in flight', () async {
      final container = await boot();
      await settle();
      final controller = container.read(entitlementProvider.notifier);

      await controller.purchase();
      await controller.purchase();

      final buys = store.calls.where((c) => c.startsWith('buyNonConsumable'));
      // A double tap must not put two payment sheets on the queue.
      expect(buys, hasLength(1));
    });

    test('does nothing when already unlocked', () async {
      final container = await boot(prefs: {'pro_unlocked': true});
      await settle();

      await container.read(entitlementProvider.notifier).purchase();

      expect(
        store.calls.where((c) => c.startsWith('buyNonConsumable')),
        isEmpty,
      );
    });

    test('acknowledgeError clears the message so it can be raised again',
        () async {
      final container = await boot();
      await settle();
      store.throwOnBuy = true;
      await container.read(entitlementProvider.notifier).purchase();
      expect(container.read(entitlementProvider).errorMessage, isNotNull);

      container.read(entitlementProvider.notifier).acknowledgeError();
      expect(container.read(entitlementProvider).errorMessage, isNull);
    });
  });

  group('restore', () {
    test('unlocks and returns null when the purchase comes back', () async {
      final container = await boot();
      await settle();

      final pending = container.read(entitlementProvider.notifier).restore();
      await settle();
      store.emit([
        purchaseUpdate(
          productId: AppInfo.proProductId,
          status: PurchaseStatus.restored,
        ),
      ]);

      expect(await pending, isNull);
      expect(container.read(entitlementProvider).unlocked, isTrue);
      expect(container.read(entitlementProvider).busy, isFalse);
    });

    test('reports a failed restore once, not twice', () async {
      // `restore()` returns the message to its caller, and the stream listener
      // sees the same outcome. If both spoke the user would get the same
      // failure twice — a snackbar and a banner saying the same thing.
      final container = await boot();
      await settle();
      store.throwOnRestore = true;

      final message =
          await container.read(entitlementProvider.notifier).restore();

      expect(message, contains('restore your purchase'));
      expect(container.read(entitlementProvider).errorMessage, isNull);
      expect(container.read(entitlementProvider).busy, isFalse);
    });
  });

  group('rebuild', () {
    test('a purchase completed after a rebuild still unlocks', () async {
      // CQ-7. Riverpod re-runs `build()` on the *same* notifier instance and
      // runs the previous build's `onDispose` callbacks first, so the teardown
      // flag was being set and never cleared. One rebuild used to leave the
      // controller permanently in its torn-down state: `_grant` would write the
      // preference and then return before touching `state`, so someone who had
      // just paid kept looking at the paywall until they restarted the app.
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      // A fresh service on each build, over the one scripted store. The
      // dependency has to genuinely change value or Riverpod skips rebuilding
      // its dependents, and then this test would pass without proving anything.
      final services = <PurchaseService>[];
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          purchaseServiceProvider.overrideWith((ref) {
            final rebuilt = PurchaseService(iap: store);
            services.add(rebuilt);
            ref.onDispose(rebuilt.dispose);
            return rebuilt;
          }),
        ],
      );
      addTearDown(container.dispose);

      container.read(entitlementProvider);
      await settle();

      container.invalidate(purchaseServiceProvider);
      container.read(entitlementProvider);
      await settle();
      expect(services, hasLength(2),
          reason: 'the premise: the notifier has to have been rebuilt');

      await container.read(entitlementProvider.notifier).purchase();
      store.emit([
        purchaseUpdate(
          productId: AppInfo.proProductId,
          status: PurchaseStatus.purchased,
        ),
      ]);
      await settle();

      expect(container.read(entitlementProvider).unlocked, isTrue);
      expect(container.read(entitlementProvider).busy, isFalse);
      expect(preferences.getBool('pro_unlocked'), isTrue);
    });
  });

  group('screenshot mode', () {
    test('does not grant the unlock in a normal build', () async {
      // The store screenshots are taken with the unlock seeded. That seeding is
      // conjoined with `!kReleaseMode`, so a release build folds it away — but
      // the suite runs without the define at all, which is the case this pins.
      expect(AppInfo.screenshotMode, isFalse);

      final container = await boot();
      expect(container.read(entitlementProvider).unlocked, isFalse);
    });
  });
}
