import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_info.dart';
import 'preferences.dart';

/// The two calls the app makes to the OS rating machinery, behind a seam so
/// the gate in [ReviewPrompter] can be tested without a platform channel.
abstract class ReviewClient {
  Future<bool> isAvailable();
  Future<void> requestReview();

  /// Opens the store listing. Used only by the "Rate the app" row, which the
  /// user taps on purpose — it never goes through the gate.
  Future<void> openStoreListing();
}

class InAppReviewClient implements ReviewClient {
  const InAppReviewClient();

  @override
  Future<bool> isAvailable() => InAppReview.instance.isAvailable();

  @override
  Future<void> requestReview() => InAppReview.instance.requestReview();

  @override
  Future<void> openStoreListing() =>
      InAppReview.instance.openStoreListing(appStoreId: AppInfo.appStoreId);
}

/// Decides whether this is a good moment to show the OS rating sheet, and
/// shows it at most then.
///
/// The only moment it considers is just after a save that worked, of a photo
/// that passed every check — the point at which the app has visibly done its
/// job. Everything else is a reason not to ask:
///
/// * the first session after install (asked before there was a chance to form
///   a view);
/// * any session in which processing failed, a save failed, a purchase
///   errored, or the paywall was closed without buying — [suppressSession];
/// * the ten seconds after the paywall closes, so the sheet never lands on
///   top of a purchase that just finished;
/// * within [cooldown] of the last ask, and for good after [maxAsks].
///
/// A free user's saves are previews, so for them the trigger is the second
/// distinct session in which they saved a passing preview: one good result
/// could be luck, two on different days is someone the app is working for.
///
/// There is deliberately no pre-prompt asking whether they like the app, no
/// incentive, and nothing in the UI that calls [ReviewClient.requestReview]
/// directly.
class ReviewPrompter {
  ReviewPrompter({
    required SharedPreferences prefs,
    required ReviewClient client,
    DateTime Function()? now,
    Future<void> Function(Duration)? wait,
  })  : _prefs = prefs,
        _client = client,
        _now = now ?? DateTime.now,
        _wait = wait ?? Future<void>.delayed,
        _session = prefs.getInt(sessionCountKey) ?? 0;

  static const String sessionCountKey = 'review_session_count';
  static const String askCountKey = 'review_ask_count';
  static const String lastAskKey = 'review_last_ask_ms';
  static const String previewSessionsKey = 'review_preview_sessions';
  static const String lastPreviewSessionKey = 'review_last_preview_session';

  static const Duration cooldown = Duration(days: 120);
  static const int maxAsks = 3;
  static const int previewSessionsNeeded = 2;

  /// Long enough for the "saved" snackbar to be read before anything covers it.
  static const Duration settleDelay = Duration(milliseconds: 1500);
  static const Duration paywallQuietPeriod = Duration(seconds: 10);

  /// Counts one app session. Called once from `main()` before the first frame;
  /// the prompter itself only reads the count, so constructing one in a test
  /// or on a provider rebuild cannot inflate it.
  static Future<void> startSession(SharedPreferences prefs) =>
      prefs.setInt(sessionCountKey, (prefs.getInt(sessionCountKey) ?? 0) + 1);

  final SharedPreferences _prefs;
  final ReviewClient _client;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _wait;

  /// 1-based number of this session; 0 when `main()` never counted one.
  final int _session;

  bool _suppressed = false;
  bool _askedThisSession = false;
  DateTime? _paywallClosedAt;

  /// Nothing more will be asked in this session.
  void suppressSession() => _suppressed = true;

  /// Called by the paywall as it goes away. Closing it without the unlock is a
  /// "not now" to the app, which is the wrong moment to ask for a rating.
  void notePaywallClosed({required bool unlocked}) {
    _paywallClosedAt = _now();
    if (!unlocked) _suppressed = true;
  }

  /// Call after a save has succeeded and its confirmation is on screen.
  ///
  /// Returns true when the OS sheet was requested. [isMounted] is checked after
  /// [settleDelay], so leaving the screen in the meantime cancels the ask.
  Future<bool> onSaveSucceeded({
    required bool fullResolution,
    required bool allChecksPassed,
    required bool Function() isMounted,
  }) async {
    if (!allChecksPassed) return false;
    if (!fullResolution) {
      await _notePassingPreview();
      if ((_prefs.getInt(previewSessionsKey) ?? 0) < previewSessionsNeeded) {
        return false;
      }
    }
    if (!_eligible()) return false;

    await _wait(settleDelay);
    // Re-checked, not assumed: the user may have left, or opened the paywall
    // and closed it, during the delay.
    if (!isMounted() || !_eligible()) return false;

    try {
      if (!await _client.isAvailable()) return false;
      // Recorded before the request, so a platform error cannot turn into an
      // ask that is retried on every save.
      _askedThisSession = true;
      await _prefs.setInt(askCountKey, (_prefs.getInt(askCountKey) ?? 0) + 1);
      await _prefs.setInt(lastAskKey, _now().millisecondsSinceEpoch);
      await _client.requestReview();
      return true;
    } catch (_) {
      // The OS decides whether the sheet appears at all; a failure here is not
      // something the user needs to hear about.
      return _askedThisSession;
    }
  }

  bool _eligible() {
    if (_session <= 1 || _suppressed || _askedThisSession) return false;
    if ((_prefs.getInt(askCountKey) ?? 0) >= maxAsks) return false;
    final now = _now();
    final lastMs = _prefs.getInt(lastAskKey);
    if (lastMs != null &&
        now.difference(DateTime.fromMillisecondsSinceEpoch(lastMs)) <
            cooldown) {
      return false;
    }
    final closed = _paywallClosedAt;
    if (closed != null && now.difference(closed) < paywallQuietPeriod) {
      return false;
    }
    return true;
  }

  Future<void> _notePassingPreview() async {
    if (_session == 0 || _prefs.getInt(lastPreviewSessionKey) == _session) {
      return;
    }
    await _prefs.setInt(lastPreviewSessionKey, _session);
    await _prefs.setInt(
      previewSessionsKey,
      (_prefs.getInt(previewSessionsKey) ?? 0) + 1,
    );
  }
}

final reviewClientProvider =
    Provider<ReviewClient>((ref) => const InAppReviewClient());

final reviewPrompterProvider = Provider<ReviewPrompter>(
  (ref) => ReviewPrompter(
    prefs: ref.watch(sharedPreferencesProvider),
    client: ref.watch(reviewClientProvider),
  ),
);
