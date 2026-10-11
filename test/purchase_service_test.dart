import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:passport_photo_app/core/constants/app_info.dart';
import 'package:passport_photo_app/features/purchase/purchase_service.dart';

import 'support/fake_store.dart';

/// The billing layer. Nothing here had coverage before stage 3, and it is the
/// one part of the app where a bug costs the user money or costs the founder a
/// store rejection.
///
/// The shape being tested: `buy()` can only report whether the payment sheet
/// came up. Whether the user then paid, backed out or was declined arrives
/// later on [PurchaseService.results], because by the time the store answers
/// the future returned by `buy()` has long since completed.
void main() {
  late FakeStore store;
  late PurchaseService service;

  setUp(() {
    store = FakeStore();
    service = PurchaseService(iap: store);
  });

  tearDown(() async {
    await service.dispose();
    await store.dispose();
  });

  group('init', () {
    test('records availability and the storefront price', () async {
      await service.init();

      expect(service.storeAvailable, isTrue);
      expect(service.displayPrice, '£4.99');
      expect(service.product?.id, AppInfo.proProductId);
    });

    test('asks for the product id the consoles will be told to create', () {
      // A mismatch here is invisible in code review and shows up as a paywall
      // with no price after the app has shipped.
      expect(AppInfo.proProductId, 'com.froggyeye.passportphoto.pro');
    });

    test('asks the App Store for its own product id on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(AppInfo.proProductId, 'com.froggyeye.passportphoto.pro2');
    });

    test('does not query products when the store is unavailable', () async {
      store.available = false;
      await service.init();

      expect(service.storeAvailable, isFalse);
      expect(service.displayPrice, isNull);
      expect(store.queryCount, 0);
    });

    test('survives an availability check that throws', () async {
      store.throwOnAvailability = true;
      await service.init();

      expect(service.storeAvailable, isFalse);
    });

    test('survives a product query that throws', () async {
      store.throwOnQuery = true;
      await service.init();

      // Available, but with no price to show. The paywall has to render this.
      expect(service.storeAvailable, isTrue);
      expect(service.displayPrice, isNull);
    });

    test('leaves the price null when the product does not exist yet', () async {
      // The state before the IAP is created in App Store Connect and the Play
      // Console. The service must not invent a figure: quoting a price the
      // user will never be charged is a store rejection.
      store.product = null;
      await service.init();

      expect(service.storeAvailable, isTrue);
      expect(service.displayPrice, isNull);
    });

    test('subscribes to the purchase stream only once', () async {
      await service.init();
      await service.init();

      final granted = <PurchaseResult>[];
      service.results.listen(granted.add);
      store.emit([
        purchaseUpdate(
          productId: AppInfo.proProductId,
          status: PurchaseStatus.purchased,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      // A second subscription would deliver the same update twice, and the
      // entitlement controller would write the unlock flag twice.
      expect(granted, hasLength(1));
    });
  });

  group('buy', () {
    test('reports only that the sheet came up', () async {
      await service.init();
      final result = await service.buy();

      expect(result.status, PurchaseStart.started);
      expect(result.message, isNull);
      expect(
        store.calls,
        contains('buyNonConsumable(${AppInfo.proProductId})'),
      );
    });

    test('initialises itself when called before init', () async {
      final result = await service.buy();

      expect(result.status, PurchaseStart.started);
      expect(store.calls.first, 'isAvailable');
    });

    test('re-queries the product if the first query came back empty', () async {
      store.product = null;
      await service.init();
      expect(service.displayPrice, isNull);

      // The product has since been created in the console.
      store.product = fakeProduct;
      final result = await service.buy();

      expect(store.queryCount, 2);
      expect(result.status, PurchaseStart.started);
    });

    test('fails with a message naming the right store', () async {
      store.product = null;
      await service.init();

      final result = await service.buy();

      expect(result.status, PurchaseStart.failed);
      // The suite runs on the host, which is not iOS, so the Play branch is
      // the one exercised here. Naming the wrong storefront in the UI puts a
      // competitor's brand in front of a reviewer.
      expect(result.message, contains('Google Play'));
      expect(result.message, isNot(contains('App Store')));
    });

    test('reports a sheet that will not open, without throwing', () async {
      await service.init();
      store.throwOnBuy = true;

      final result = await service.buy();

      expect(result.status, PurchaseStart.failed);
      expect(result.message, contains('Could not start the purchase'));
    });
  });

  group('the purchase stream', () {
    Future<List<PurchaseResult>> collect(
      Future<void> Function() act, {
      int expected = 1,
    }) async {
      final results = <PurchaseResult>[];
      final sub = service.results.listen(results.add);
      await act();
      // Two microtask turns: one for the stream, one for the completePurchase
      // the handler awaits.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();
      return results;
    }

    test('a purchase grants, and is finished with the store', () async {
      await service.init();
      final results = await collect(() async {
        store.emit([
          purchaseUpdate(
            productId: AppInfo.proProductId,
            status: PurchaseStatus.purchased,
          ),
        ]);
      });

      expect(results.single.outcome, PurchaseOutcome.granted);
      // Not finishing the transaction is how apps end up refunding: the store
      // re-delivers it on every launch and, on iOS, eventually reverses it.
      expect(store.completed, hasLength(1));
    });

    test('a restore grants too', () async {
      await service.init();
      final results = await collect(() async {
        store.emit([
          purchaseUpdate(
            productId: AppInfo.proProductId,
            status: PurchaseStatus.restored,
          ),
        ]);
      });

      expect(results.single.outcome, PurchaseOutcome.granted);
    });

    test('a pending purchase is reported but not granted', () async {
      await service.init();
      final results = await collect(() async {
        store.emit([
          purchaseUpdate(
            productId: AppInfo.proProductId,
            status: PurchaseStatus.pending,
            pendingCompletePurchase: false,
          ),
        ]);
      });

      expect(results.single.outcome, PurchaseOutcome.pending);
      expect(store.completed, isEmpty);
    });

    test('a cancellation is not an error', () async {
      await service.init();
      final results = await collect(() async {
        store.emit([
          purchaseUpdate(
            productId: AppInfo.proProductId,
            status: PurchaseStatus.canceled,
          ),
        ]);
      });

      expect(results.single.outcome, PurchaseOutcome.cancelled);
      expect(results.single.message, isNull);
    });

    test('a failure says the user has not been charged', () async {
      await service.init();
      final results = await collect(() async {
        store.emit([
          purchaseUpdate(
            productId: AppInfo.proProductId,
            status: PurchaseStatus.error,
            error: IAPError(
              source: 'test',
              code: 'boom',
              message: 'internal',
            ),
          ),
        ]);
      });

      expect(results.single.outcome, PurchaseOutcome.failed);
      expect(results.single.message, contains('not been charged'));
      // Still finished, or the failed transaction stalls the queue behind it.
      expect(store.completed, hasLength(1));
    });

    test('an unknown product is finished but not granted', () async {
      // A leftover transaction from another product id — a renamed IAP, or a
      // sandbox account with history. It must not unlock Pro, and it must not
      // be left in the queue.
      await service.init();
      final results = await collect(() async {
        store.emit([
          purchaseUpdate(
            productId: 'com.froggyeye.somethingelse',
            status: PurchaseStatus.purchased,
          ),
        ]);
      });

      expect(results, isEmpty);
      expect(store.completed, hasLength(1));
      expect(
        store.completed.single.productID,
        'com.froggyeye.somethingelse',
      );
    });

    test('a batch of updates is handled in full', () async {
      await service.init();
      final results = await collect(() async {
        store.emit([
          purchaseUpdate(
            productId: 'com.froggyeye.somethingelse',
            status: PurchaseStatus.purchased,
          ),
          purchaseUpdate(
            productId: AppInfo.proProductId,
            status: PurchaseStatus.purchased,
          ),
        ]);
      });

      expect(results.single.outcome, PurchaseOutcome.granted);
      expect(store.completed, hasLength(2));
    });

    test('a stream error is surfaced, not swallowed', () async {
      await service.init();
      final results = await collect(() async {
        store.emitError(StateError('connection dropped'));
      });

      expect(results.single.outcome, PurchaseOutcome.failed);
      expect(results.single.message, contains('store connection'));
    });

    test('a completePurchase that throws does not stall the batch', () async {
      await service.init();
      // Two updates; the first throws on completion. The second must still be
      // reported, or one bad transaction blocks every later purchase.
      final results = <PurchaseResult>[];
      final sub = service.results.listen(results.add);
      store.emit([
        purchaseUpdate(
          productId: AppInfo.proProductId,
          status: PurchaseStatus.purchased,
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      store.emit([
        purchaseUpdate(
          productId: AppInfo.proProductId,
          status: PurchaseStatus.restored,
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();

      expect(results, hasLength(2));
    });
  });

  group('restore', () {
    test('returns granted when the store re-delivers the purchase', () async {
      await service.init();

      final pending = service.restore();
      // The store answers on the stream, after restorePurchases() returned.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      store.emit([
        purchaseUpdate(
          productId: AppInfo.proProductId,
          status: PurchaseStatus.restored,
        ),
      ]);

      final result = await pending;
      expect(result.outcome, PurchaseOutcome.granted);
    });

    test('does not resolve on a pending update', () async {
      // A deferred purchase awaiting a parent's approval sends `pending`
      // first. Treating that as the answer would tell the user there was
      // nothing to restore while the store was still working.
      await service.init();

      var settled = false;
      final pending = service.restore().then((r) {
        settled = true;
        return r;
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
      store.emit([
        purchaseUpdate(
          productId: AppInfo.proProductId,
          status: PurchaseStatus.pending,
          pendingCompletePurchase: false,
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(settled, isFalse);

      store.emit([
        purchaseUpdate(
          productId: AppInfo.proProductId,
          status: PurchaseStatus.restored,
        ),
      ]);
      expect((await pending).outcome, PurchaseOutcome.granted);
    });

    test('reports a store it could not reach', () async {
      await service.init();
      store.throwOnRestore = true;

      final result = await service.restore();

      expect(result.outcome, PurchaseOutcome.failed);
      expect(result.message, contains('restore your purchase'));
    });

    test(
      'a restore with nothing to find times out rather than hanging',
      () async {
        // Both stores stay silent when there is nothing to return, so the only
        // way out of `restore()` is its own 12-second timeout. Without it the
        // paywall's "Restore purchases" button spins forever, which is a
        // dead end a reviewer will find — restore is the one flow both stores
        // explicitly test.
        //
        // Really waiting, rather than on a fake clock: `fake_async` is not a
        // declared dependency and one slow test is cheaper than another entry
        // in pubspec.
        await service.init();

        final started = DateTime.now();
        final result = await service.restore();
        final waited = DateTime.now().difference(started);

        expect(result.outcome, PurchaseOutcome.nothingToRestore);
        expect(result.message, contains('No previous purchase'));
        expect(waited.inSeconds, greaterThanOrEqualTo(11));
      },
      timeout: const Timeout(Duration(seconds: 40)),
      tags: 'slow',
    );
  });

  group('dispose', () {
    test('stops listening and closes the results stream', () async {
      await service.init();
      await service.dispose();

      // A second dispose must not throw — the provider tears down on hot
      // restart as well as on shutdown.
      await service.dispose();
    });
  });
}
