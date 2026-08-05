import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Driver for the screenshot run, so the captured bytes land on disk.
///
/// `binding.takeScreenshot` only hands the bytes to a driver — running the
/// same target with `flutter test` produces no files at all, silently. It has
/// to be `flutter drive`:
///
/// ```
/// flutter drive \
///   --driver=test_driver/integration_test.dart \
///   --target=integration_test/screenshots_test.dart \
///   --dart-define=SCREENSHOT_MODE=true \
///   -d <device id>
/// ```
///
/// Files are written to `store_assets/screenshots/raw/<name>.png`, but
/// `store_assets/screenshots/render.sh` reads them from
/// `raw/<ios|android>/`, so set `SCREENSHOT_DIR` accordingly:
///
/// ```
/// SCREENSHOT_DIR=store_assets/screenshots/raw/ios flutter drive ...
/// ```
///
/// That is also how a second device's set avoids overwriting the first.
Future<void> main() async {
  final directory = Directory(
    Platform.environment['SCREENSHOT_DIR'] ?? 'store_assets/screenshots/raw',
  );

  await integrationDriver(
    onScreenshot:
        (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      await directory.create(recursive: true);
      final file = File('${directory.path}/$name.png');
      await file.writeAsBytes(bytes);
      stdout.writeln('screenshot: ${file.path}');
      return true;
    },
  );
}
