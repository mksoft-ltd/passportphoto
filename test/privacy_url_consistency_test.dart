import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:passport_photo_app/core/constants/app_info.dart';

/// The paywall renders a "Privacy policy" button that opens
/// [AppInfo.privacyPolicyUrl], and the store listings carry their own copy of
/// the same URL in fastlane. Only one repository can be pushed, so if the two
/// drift apart — as they did, the constant naming `passport_photo_app` while
/// every metadata file named `passportphoto` — whichever one loses points at a
/// GitHub 404 that a reviewer will tap. Nothing else in the build compares
/// these strings, so this test is the only thing that can catch the drift.
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

  test('the privacy policy URL points at the repository that gets pushed', () {
    // `mksoft-ltd/passportphoto` is the canonical repo name across all store
    // metadata. Any other spelling has never been created.
    expect(AppInfo.privacyPolicyUrl, contains('mksoft-ltd/passportphoto/'));
    expect(AppInfo.privacyPolicyUrl, endsWith('PRIVACY_POLICY.md'));
    expect(File('PRIVACY_POLICY.md').existsSync(), isTrue,
        reason: 'The file the URL resolves to must exist in this repo.');
  });
}
