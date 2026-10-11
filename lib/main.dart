import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/services/photo_files.dart';
import 'core/services/preferences.dart';
import 'core/services/review_prompter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // Backstop for photos left behind by a session that crashed or was killed
  // mid-processing. Deliberately not awaited — it is housekeeping, and the
  // first frame should not wait on a directory walk.
  unawaited(PhotoFiles.sweepStale());
  // The rating prompt never asks in the first session, so it needs to know
  // which one this is. SharedPreferences updates its cache synchronously, so
  // nothing that reads the count can see it before this write.
  unawaited(ReviewPrompter.startSession(prefs));
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const PassportPhotoApp(),
    ),
  );
}
