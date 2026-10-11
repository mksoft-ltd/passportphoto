import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:passport_photo_app/core/constants/app_info.dart';

/// The paywall renders a "Privacy policy" button that opens
/// [AppInfo.privacyPolicyUrl], and the store listings carry their own copy of
/// the same URL in fastlane. If the two drift apart, one of them points at a
/// page a reviewer will tap and find dead or out of date. Nothing else in the
/// build compares these strings, so this test is the only thing that can catch
/// the drift.
void main() {
  const fastlaneUrlFiles = <String>[
    'ios/fastlane/metadata/en-GB/privacy_url.txt',
    'ios/fastlane/metadata/en-US/privacy_url.txt',
  ];

  for (final path in fastlaneUrlFiles) {
    test('$path matches AppInfo.privacyPolicyUrl', () {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path is missing.');
      expect(
        file.readAsStringSync().trim(),
        AppInfo.privacyPolicyUrl,
        reason: 'The in-app privacy link and the store privacy link must be '
            'the same URL, or one of them will be dead.',
      );
    });
  }

  test('the Play data-safety sheet quotes the same privacy URL', () {
    final sheet = File('android/fastlane/data_safety_answers.md');
    expect(sheet.existsSync(), isTrue);
    expect(
      sheet.readAsStringSync().contains(AppInfo.privacyPolicyUrl),
      isTrue,
      reason: 'data_safety_answers.md §1 is typed into the Play Console by '
          'hand; it must quote the same URL the app opens.',
    );
  });

  test('the privacy policy URL is an HTML page on the publisher\'s domain', () {
    // The policy is hosted by Froggy Eye Ltd, the seller of record, as a
    // rendered HTML page, not raw Markdown under a third-party code host.
    // It is rendered verbatim from PRIVACY_POLICY.md in this repo.
    final uri = Uri.parse(AppInfo.privacyPolicyUrl);
    expect(uri.scheme, 'https');
    expect(uri.host, 'passportphoto.froggyeye.com');
    expect(uri.path, '/privacy.html');
    expect(AppInfo.privacyPolicyUrl, isNot(contains('github')));
    expect(AppInfo.privacyPolicyUrl, isNot(contains('mksoft')));
    expect(File('PRIVACY_POLICY.md').existsSync(), isTrue,
        reason: 'The source the hosted page is rendered from must exist in '
            'this repo.');
  });
}
