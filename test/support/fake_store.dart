import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
// `InAppPurchase.getPlatformAddition` is bound to a type that
// `in_app_purchase` does not re-export, and an override has to name its
// bound. Imported directly rather than added to pubspec: it is already in the
// lockfile as a dependency of `in_app_purchase`, and this file is test-only.
// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:passport_photo_app/core/constants/app_info.dart';

/// A store you can script, standing in for `InAppPurchase`.
///
/// A hand-written double rather than a mocking package: the interesting
/// behaviour here is *ordering* — a purchase result arrives on a stream long
/// after the call that started it returned — and a fake with a real
/// StreamController expresses that directly, where a `when(...).thenAnswer`
/// would only describe the calls.
class FakeStore implements InAppPurchase {
  FakeStore({
    this.available = true,
    this.product = fakeProduct,
    this.throwOnQuery = false,
    this.throwOnBuy = false,
    this.throwOnRestore = false,
    this.throwOnAvailability = false,
  });

  bool available;

  /// Null means the store answered but had no such product — the case where
  /// the IAP has not been created in the console yet.
  ProductDetails? product;

  bool throwOnQuery;
  bool throwOnBuy;
  bool throwOnRestore;
  bool throwOnAvailability;

  final _controller = StreamController<List<PurchaseDetails>>.broadcast();

  /// What the service asked the store to do, in order.
  final List<String> calls = <String>[];

  /// Purchases the service told the store it had finished with.
  final List<PurchaseDetails> completed = <PurchaseDetails>[];

  int queryCount = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<bool> isAvailable() async {
    calls.add('isAvailable');
    if (throwOnAvailability) throw StateError('store unreachable');
    return available;
  }

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    calls.add('queryProductDetails(${identifiers.join(",")})');
    queryCount++;
    if (throwOnQuery) throw StateError('query failed');
    final found = product;
    return ProductDetailsResponse(
      productDetails: found == null ? const [] : [found],
      notFoundIDs: found == null ? identifiers.toList() : const [],
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    calls.add('buyNonConsumable(${purchaseParam.productDetails.id})');
    if (throwOnBuy) throw StateError('sheet failed to open');
    return true;
  }

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    calls.add('buyConsumable');
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    calls.add('completePurchase(${purchase.productID})');
    completed.add(purchase);
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    calls.add('restorePurchases');
    if (throwOnRestore) throw StateError('restore failed');
  }

  @override
  Future<String> countryCode() async => 'GB';

  @override
  T getPlatformAddition<T extends InAppPurchasePlatformAddition?>() =>
      throw UnimplementedError();

  /// Pushes an update the way a real store would — asynchronously, after the
  /// call that triggered it has already returned.
  void emit(List<PurchaseDetails> purchases) => _controller.add(purchases);

  void emitError(Object error) => _controller.addError(error);

  Future<void> dispose() => _controller.close();
}

/// A purchase update, built the way the plugin delivers one.
PurchaseDetails purchaseUpdate({
  required String productId,
  required PurchaseStatus status,
  bool pendingCompletePurchase = true,
  IAPError? error,
}) {
  return PurchaseDetails(
    productID: productId,
    purchaseID: 'txn-1',
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local',
      serverVerificationData: 'server',
      source: 'test',
    ),
    transactionDate: '0',
    status: status,
  )
    ..pendingCompletePurchase = pendingCompletePurchase
    ..error = error;
}

/// The Pro unlock as the storefront would describe it once the product exists
/// in App Store Connect and the Play Console.
const ProductDetails fakeProduct = _FakeProduct();

class _FakeProduct implements ProductDetails {
  const _FakeProduct();

  @override
  String get id => AppInfo.proProductId;
  @override
  String get title => 'Passport Photo Studio Pro';
  @override
  String get description => 'Full-resolution export and the 4x6 print sheet.';
  @override
  String get price => '£4.99';
  @override
  double get rawPrice => 4.99;
  @override
  String get currencyCode => 'GBP';
  @override
  String get currencySymbol => '£';
}
