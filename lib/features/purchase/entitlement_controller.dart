import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_info.dart';
import '../../core/services/preferences.dart';
import 'purchase_service.dart';

const String _unlockedKey = 'pro_unlocked';

@immutable
class EntitlementState {
  const EntitlementState({
    required this.unlocked,
    this.busy = false,
    this.price,
    this.storeAvailable = false,
    this.errorMessage,
  });

  /// True once Passport Photo Studio Pro has been bought or restored.
  final bool unlocked;

  /// A purchase or restore is in flight.
  final bool busy;

  /// The storefront's localised price, or null until the store answers.
  ///
  /// Null is a real state the paywall has to render, not a placeholder to
  /// paper over: inventing a price here would quote users an amount and a
  /// currency they will never be charged.
  final String? price;
  final bool storeAvailable;

  /// Something to tell the user about a purchase that failed after the store
  /// sheet was already up, which is too late to report as a return value. The
  /// paywall shows it, then calls [EntitlementController.acknowledgeError].
  final String? errorMessage;

  EntitlementState copyWith({
    bool? unlocked,
    bool? busy,
    String? price,
    bool? storeAvailable,
    String? errorMessage,
    bool clearError = false,
  }) =>
      EntitlementState(
        unlocked: unlocked ?? this.unlocked,
        busy: busy ?? this.busy,
        price: price ?? this.price,
        storeAvailable: storeAvailable ?? this.storeAvailable,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

/// Owns the Pro flag.
///
/// The store is the source of truth; the local flag is only a cache so the app
/// works offline and does not have to hit the store on every launch.
class EntitlementController extends Notifier<EntitlementState> {
  StreamSubscription<PurchaseResult>? _subscription;

  /// True while [restore] is awaiting the store itself.
  ///
  /// [PurchaseService.restore] watches the same stream and returns the terminal
  /// outcome to its caller, so the listener below must keep out of the way or
  /// the user would be told about the same failure twice.
  bool _restoring = false;

  /// Set once the provider is gone, so a slow store call that resolves after
  /// teardown does not write to a disposed notifier.
  ///
  /// Reset by [build], because Riverpod re-runs `build` on the *same* notifier
  /// instance and runs the `onDispose` callbacks before it. Without the reset a
  /// single rebuild would leave the controller permanently torn down, and the
  /// next completed purchase would be dropped in [_grant] instead of unlocking
  /// the app until the user restarted it.
  bool _disposed = false;

  static const _genericFailure = 'The purchase could not be completed.';

  @override
  EntitlementState build() {
    _disposed = false;
    final prefs = ref.watch(sharedPreferencesProvider);
    final service = ref.watch(purchaseServiceProvider);

    // Every terminal outcome of a started purchase arrives here, not as the
    // return value of buy(): by the time the store answers, that future has
    // long since completed.
    _subscription = service.results.listen(_onStoreResult);
    ref.onDispose(() {
      _disposed = true;
      _subscription?.cancel();
    });

    unawaited(_initStore(service));

    return EntitlementState(
      unlocked: AppInfo.screenshotMode || (prefs.getBool(_unlockedKey) ?? false),
    );
  }

  void _onStoreResult(PurchaseResult result) {
    switch (result.outcome) {
      case PurchaseOutcome.granted:
        unawaited(_grant());
      case PurchaseOutcome.pending:
        // The store sheet is up; stay busy until it resolves.
        break;
      case PurchaseOutcome.cancelled:
        // Backing out of the payment sheet is not an error — it just has to
        // give the buttons back.
        state = state.copyWith(busy: false, clearError: true);
      case PurchaseOutcome.failed:
      case PurchaseOutcome.nothingToRestore:
        // Only speak up when the user is actually waiting on us: a store error
        // with nothing in flight has nothing to do with anything they did.
        if (_restoring || !state.busy) return;
        state = state.copyWith(
          busy: false,
          errorMessage: result.message ?? _genericFailure,
        );
    }
  }

  Future<void> _initStore(PurchaseService service) async {
    await service.init();
    if (_disposed) return;
    state = state.copyWith(
      storeAvailable: service.storeAvailable,
      price: service.displayPrice,
    );
  }

  Future<void> _grant() async {
    await ref.read(sharedPreferencesProvider).setBool(_unlockedKey, true);
    if (_disposed) return;
    state = state.copyWith(unlocked: true, busy: false, clearError: true);
  }

  /// Starts a purchase. Everything after the sheet comes up is reported through
  /// [EntitlementState] — the unlock itself, or [EntitlementState.errorMessage].
  Future<void> purchase() async {
    if (state.unlocked || state.busy) return;
    state = state.copyWith(busy: true, clearError: true);
    final start = await ref.read(purchaseServiceProvider).buy();
    if (_disposed) return;
    if (start.status == PurchaseStart.failed) {
      state = state.copyWith(
        busy: false,
        errorMessage: start.message ?? _genericFailure,
      );
    }
    // Otherwise stay busy: the sheet is up and the store will answer on the
    // results stream.
  }

  /// Returns a message to show the user, or null when the restore succeeded.
  Future<String?> restore() async {
    if (state.busy) return null;
    state = state.copyWith(busy: true, clearError: true);
    _restoring = true;
    try {
      final result = await ref.read(purchaseServiceProvider).restore();
      if (result.outcome == PurchaseOutcome.granted) {
        await _grant();
        return null;
      }
      if (!_disposed) state = state.copyWith(busy: false);
      return result.message ?? 'No previous purchase was found on this account.';
    } finally {
      _restoring = false;
    }
  }

  /// Called by the paywall once it has shown [EntitlementState.errorMessage],
  /// so the same message can be raised again if it happens again.
  void acknowledgeError() {
    if (state.errorMessage != null) state = state.copyWith(clearError: true);
  }
}

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final service = PurchaseService();
  ref.onDispose(service.dispose);
  return service;
});

final entitlementProvider =
    NotifierProvider<EntitlementController, EntitlementState>(
  EntitlementController.new,
);

/// Convenience for the widgets and the export path, which only care about the
/// boolean.
final isProUnlockedProvider = Provider<bool>(
  (ref) => ref.watch(entitlementProvider.select((s) => s.unlocked)),
);
