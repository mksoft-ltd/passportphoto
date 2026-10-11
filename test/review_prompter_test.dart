import 'package:flutter_test/flutter_test.dart';
import 'package:passport_photo_app/core/services/review_prompter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The rating prompt's gate. Every rule is a reason *not* to ask, so each test
/// starts from a state that would ask and changes exactly one thing.
void main() {
  late SharedPreferences prefs;
  late _FakeReviewClient client;
  late DateTime now;
  late List<Duration> waits;

  Future<ReviewPrompter> prompterIn({
    required int session,
    Map<String, Object> extra = const {},
  }) async {
    SharedPreferences.setMockInitialValues({
      ReviewPrompter.sessionCountKey: session,
      ...extra,
    });
    prefs = await SharedPreferences.getInstance();
    return ReviewPrompter(
      prefs: prefs,
      client: client,
      now: () => now,
      // The settle delay advances the fake clock instead of sleeping.
      wait: (d) async {
        waits.add(d);
        now = now.add(d);
      },
    );
  }

  Future<bool> fullResSave(ReviewPrompter p, {bool passed = true}) =>
      p.onSaveSucceeded(
        fullResolution: true,
        allChecksPassed: passed,
        isMounted: () => true,
      );

  setUp(() {
    client = _FakeReviewClient();
    now = DateTime(2026, 10, 11, 12);
    waits = [];
  });

  group('asks', () {
    test('after a passing full-resolution save in a later session', () async {
      final p = await prompterIn(session: 2);
      expect(await fullResSave(p), isTrue);
      expect(client.requests, 1);
      expect(waits, [ReviewPrompter.settleDelay]);
      expect(prefs.getInt(ReviewPrompter.askCountKey), 1);
      expect(prefs.getInt(ReviewPrompter.lastAskKey),
          now.millisecondsSinceEpoch);
    });

    test('a free user on the second session with a passing preview',
        () async {
      var p = await prompterIn(session: 1);
      expect(
        await p.onSaveSucceeded(
            fullResolution: false, allChecksPassed: true, isMounted: () => true),
        isFalse,
      );
      // Same session again: still one distinct session.
      await p.onSaveSucceeded(
          fullResolution: false, allChecksPassed: true, isMounted: () => true);
      expect(prefs.getInt(ReviewPrompter.previewSessionsKey), 1);

      await ReviewPrompter.startSession(prefs);
      p = ReviewPrompter(
          prefs: prefs, client: client, now: () => now, wait: (_) async {});
      expect(
        await p.onSaveSucceeded(
            fullResolution: false, allChecksPassed: true, isMounted: () => true),
        isTrue,
      );
      expect(client.requests, 1);
    });
  });

  group('never asks', () {
    test('in the first session', () async {
      final p = await prompterIn(session: 1);
      expect(await fullResSave(p), isFalse);
      expect(client.requests, 0);
    });

    test('when main() never counted a session', () async {
      SharedPreferences.setMockInitialValues({});
      final p = ReviewPrompter(
        prefs: await SharedPreferences.getInstance(),
        client: client,
        now: () => now,
        wait: (_) async {},
      );
      expect(await fullResSave(p), isFalse);
    });

    test('when a check failed on this photo', () async {
      final p = await prompterIn(session: 5);
      expect(await fullResSave(p, passed: false), isFalse);
      expect(client.requests, 0);
    });

    test('for a free user on only one preview session', () async {
      final p = await prompterIn(session: 5);
      expect(
        await p.onSaveSucceeded(
            fullResolution: false, allChecksPassed: true, isMounted: () => true),
        isFalse,
      );
    });

    test('a failing preview does not count towards the free trigger',
        () async {
      final p = await prompterIn(session: 5);
      await p.onSaveSucceeded(
          fullResolution: false, allChecksPassed: false, isMounted: () => true);
      expect(prefs.getInt(ReviewPrompter.previewSessionsKey), isNull);
    });

    test('in a suppressed session (processing error, save failure, '
        'purchase error)', () async {
      final p = await prompterIn(session: 3)..suppressSession();
      expect(await fullResSave(p), isFalse);
    });

    test('after the paywall was closed without buying', () async {
      final p = await prompterIn(session: 3)
        ..notePaywallClosed(unlocked: false);
      now = now.add(const Duration(minutes: 30));
      expect(await fullResSave(p), isFalse);
    });

    test('within 10 s of the paywall closing, even after a purchase',
        () async {
      final p = await prompterIn(session: 3)
        ..notePaywallClosed(unlocked: true);
      // 1.5 s settle on top of this still lands inside the quiet period.
      now = now.add(const Duration(seconds: 5));
      expect(await fullResSave(p), isFalse);

      now = now.add(const Duration(seconds: 10));
      expect(await fullResSave(p), isTrue);
    });

    test('if the screen went away during the settle delay', () async {
      final p = await prompterIn(session: 3);
      expect(
        await p.onSaveSucceeded(
            fullResolution: true, allChecksPassed: true, isMounted: () => false),
        isFalse,
      );
      expect(client.requests, 0);
    });

    test('twice in one session', () async {
      final p = await prompterIn(session: 3);
      expect(await fullResSave(p), isTrue);
      now = now.add(const Duration(days: 365));
      expect(await fullResSave(p), isFalse);
    });

    test('within the 120-day cooldown', () async {
      final last = now.subtract(const Duration(days: 119));
      final p = await prompterIn(session: 9, extra: {
        ReviewPrompter.askCountKey: 1,
        ReviewPrompter.lastAskKey: last.millisecondsSinceEpoch,
      });
      expect(await fullResSave(p), isFalse);
    });

    test('again once the cooldown has passed — positive control', () async {
      final last = now.subtract(const Duration(days: 121));
      final p = await prompterIn(session: 9, extra: {
        ReviewPrompter.askCountKey: 1,
        ReviewPrompter.lastAskKey: last.millisecondsSinceEpoch,
      });
      expect(await fullResSave(p), isTrue);
      expect(prefs.getInt(ReviewPrompter.askCountKey), 2);
    });

    test('after three asks, however long ago', () async {
      final p = await prompterIn(session: 40, extra: {
        ReviewPrompter.askCountKey: 3,
        ReviewPrompter.lastAskKey:
            DateTime(2020).millisecondsSinceEpoch,
      });
      expect(await fullResSave(p), isFalse);
    });

    test('when the platform says reviews are unavailable', () async {
      client.available = false;
      final p = await prompterIn(session: 3);
      expect(await fullResSave(p), isFalse);
      expect(prefs.getInt(ReviewPrompter.askCountKey), isNull);
    });
  });

  test('a platform error is swallowed and still counts as the ask', () async {
    client.throwOnRequest = true;
    final p = await prompterIn(session: 3);
    expect(await fullResSave(p), isTrue);
    expect(prefs.getInt(ReviewPrompter.askCountKey), 1);
    expect(await fullResSave(p), isFalse);
  });

  test('startSession counts up from zero', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await ReviewPrompter.startSession(prefs);
    await ReviewPrompter.startSession(prefs);
    expect(prefs.getInt(ReviewPrompter.sessionCountKey), 2);
  });
}

class _FakeReviewClient implements ReviewClient {
  bool available = true;
  bool throwOnRequest = false;
  int requests = 0;
  int listings = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async {
    requests++;
    if (throwOnRequest) throw StateError('platform');
  }

  @override
  Future<void> openStoreListing() async => listings++;
}
