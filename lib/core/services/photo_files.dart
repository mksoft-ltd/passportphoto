import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Deletion points for the photo files the app causes to exist.
///
/// The photograph this app handles is a government identity document, and
/// `PRIVACY_POLICY.md` tells the user in writing that "the only copies that
/// persist are the ones you explicitly save to your own photo gallery". Nothing
/// in the codebase deleted anything until 2026-08-05, so that sentence was
/// false three times over: the picker's copy, the camera's still, and a
/// duplicate of every export.
///
/// The export duplicate is gone (see `ExportService._save`). The other two are
/// made by plugins, in the app's own cache, and this is where they are cleaned
/// up. The rule worth keeping past this fix: every file the app creates from a
/// face photo gets a named owner and a deletion point in the same commit that
/// creates it.
class PhotoFiles {
  const PhotoFiles._();

  /// Files this old are from a session that has ended.
  static const Duration _staleAfter = Duration(hours: 1);

  static const Set<String> _imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.heic',
    '.heif',
  };

  /// Deletes a source photo the app is finished with.
  ///
  /// [path] is always a plugin-made copy inside the app's own cache directory —
  /// `ImagePicker.pickImage` copies the chosen library image before returning
  /// its path, and `CameraController.takePicture` writes the still to the
  /// temporary directory. Neither is the user's library original, so this
  /// cannot delete a photo the user still has.
  ///
  /// Never throws: a file already gone, or on a read-only path, is not
  /// something the result screen should surface.
  static Future<void> discardSource(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best effort. The launch sweep is the backstop.
    }
  }

  /// Deletes image files left in the app's temporary directory by an earlier
  /// session — a crash, or a kill during processing, skips [discardSource].
  ///
  /// Scoped to the app's own temp directory (`NSTemporaryDirectory()` on iOS,
  /// `Context.getCacheDir()` on Android), which is app-private on both
  /// platforms and which the OS is already free to empty under storage
  /// pressure. Only files older than [_staleAfter] are touched, so a photo the
  /// running app is still working with is never pulled out from under it.
  static Future<void> sweepStale() async {
    try {
      final dir = await getTemporaryDirectory();
      if (!await dir.exists()) return;
      final cutoff = DateTime.now().subtract(_staleAfter);
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.path.toLowerCase();
        if (!_imageExtensions.any(name.endsWith)) continue;
        try {
          if ((await entity.stat()).modified.isBefore(cutoff)) {
            await entity.delete();
          }
        } catch (_) {
          // Another process may have it, or it may have gone already.
        }
      }
    } catch (_) {
      // Housekeeping. It must never stop the app from starting.
    }
  }
}
