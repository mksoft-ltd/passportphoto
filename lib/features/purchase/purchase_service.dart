import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/constants/app_info.dart';

enum PurchaseOutcome { granted, cancelled, pending, failed, nothingToRestore }

@immutable
class PurchaseResult {
  const PurchaseResult(this.outcome, [this.message]);

  final PurchaseOutcome outcome;
  final String? message;
}

/// All [PurchaseService.buy] can know synchronously: the store sheet either
/// came up or it did not.
///
/// Deliberately narrower than [PurchaseOutcome]. Whether the user then paid,
/// backed out or was declined is only ever known later, on
/// [PurchaseService.results], so there is no way to write a caller that
/// mistakes "the sheet is up" for "the purchase went through".
enum PurchaseStart { started, failed }

@immutable
class StartPurchaseResult {
  const StartPurchaseResult(this.status, [this.message]);

  final PurchaseStart status;

  /// Why the sheet could not be shown, for the user. Null when [status] is
  /// [PurchaseStart.started].
  final String? message;
}

/// Wraps the native `in_app_purchase` plugin for the single non-consumable Pro
/// unlock. No third-party billing SDK is involved.
class PurchaseService {
  PurchaseService({InAppPurchase? iap}) : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final _results = StreamController<PurchaseResult>.broadcast();

  ProductDetails? _product;
  bool _storeAvailable = false;

  /// Whichever store is actually billing this user. Naming the wrong one puts a
  /// competitor's brand in the UI — a Play reviewer who hits the failure path
  /// below should not be told about the App Store.
  static String get _storeName =>
      !kIsWeb && Platform.isIOS ? 'The App Store' : 'Google Play';

  /// Emits whenever the store tells us something about a purchase.
  Stream<PurchaseResult> get results => _results.stream;
  ProductDetails? get product => _product;
  bool get storeAvailable => _storeAvailable;

  /// The storefront's own localised price string, or null when the store has
  /// not answered yet.
  ///
  /// Deliberately has no fallback. A literal here would be in the wrong
  /// currency for most of the world the moment the query fails, and Play has
  /// rejected apps for quoting a price the user will never be charged. The
  /// paywall renders a plain "Unlock Pro" instead.
  String? get displayPrice => _product?.price;

  Future<void> init() async {
    _subscription ??= _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) {
        debugPrint('PassportPhoto: purchase stream error: $e');
        _results.add(const PurchaseResult(
          PurchaseOutcome.failed,
          'The store connection was interrupted. Please try again.',
        ));
      },
    );
    try {
      _storeAvailable = await _iap.isAvailable();
    } catch (e) {
      debugPrint('PassportPhoto: store availability check failed: $e');
      _storeAvailable = false;
    }
    if (_storeAvailable) await _loadProduct();
  }

  Future<void> _loadProduct() async {
    try {
      final response = await _iap.queryProductDetails({AppInfo.proProductId});
      if (response.productDetails.isNotEmpty) {
        _product = response.productDetails.first;
      } else {
        debugPrint('PassportPhoto: Pro product not found: ${response.notFoundIDs}');
      }
    } catch (e) {
      debugPrint('PassportPhoto: queryProductDetails failed: $e');
    }
  }

  /// Puts the store's payment sheet up. The outcome arrives on [results].
  Future<StartPurchaseResult> buy() async {
    if (!_storeAvailable) {
      await init();
    } else if (_product == null) {
      await _loadProduct();
    }
    final product = _product;
    if (product == null) {
      return StartPurchaseResult(
        PurchaseStart.failed,
        '$_storeName is not reachable right now. Please try again later.',
      );
    }
    try {
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      return const StartPurchaseResult(PurchaseStart.started);
    } catch (e) {
      debugPrint('PassportPhoto: buyNonConsumable failed: $e');
      return const StartPurchaseResult(
        PurchaseStart.failed,
        'Could not start the purchase. Please try again.',
      );
    }
  }

  /// Restores a previous purchase. Successful restores arrive on the purchase
  /// stream; if nothing shows up shortly we report that there was nothing to
  /// restore rather than leaving the user on a spinner.
  Future<PurchaseResult> restore() async {
    if (!_storeAvailable) await init();
    final completer = Completer<PurchaseResult>();
    late final StreamSubscription<PurchaseResult> watcher;
    watcher = _results.stream.listen((result) {
      if (!completer.isCompleted && result.outcome != PurchaseOutcome.pending) {
        completer.complete(result);
      }
    });
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('PassportPhoto: restorePurchases failed: $e');
      await watcher.cancel();
      return const PurchaseResult(
        PurchaseOutcome.failed,
        'Could not reach the store to restore your purchase.',
      );
    }
    final result = await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => const PurchaseResult(
        PurchaseOutcome.nothingToRestore,
        'No previous purchase was found on this account.',
      ),
    );
    await watcher.cancel();
    return result;
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != AppInfo.proProductId) {
        // Unknown product: still finish it so the queue does not stall.
        if (purchase.pendingCompletePurchase) await _complete(purchase);
        continue;
      }
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _results.add(const PurchaseResult(PurchaseOutcome.pending));
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _results.add(const PurchaseResult(PurchaseOutcome.granted));
        case PurchaseStatus.canceled:
          _results.add(const PurchaseResult(PurchaseOutcome.cancelled));
        case PurchaseStatus.error:
          debugPrint('PassportPhoto: purchase error: ${purchase.error}');
          _results.add(const PurchaseResult(
            PurchaseOutcome.failed,
            'The purchase did not go through. You have not been charged.',
          ));
      }
      if (purchase.pendingCompletePurchase) await _complete(purchase);
    }
  }

  Future<void> _complete(PurchaseDetails purchase) async {
    try {
      await _iap.completePurchase(purchase);
    } catch (e) {
      debugPrint('PassportPhoto: completePurchase failed: $e');
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _results.close();
  }
}
