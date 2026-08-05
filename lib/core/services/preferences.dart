import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resolved once in `main()` and injected as a `ProviderScope` override, so
/// everything downstream can read preferences synchronously. Without that the
/// result screen would render its export buttons before the entitlement flag
/// had loaded and briefly show a paid user the locked state.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main() or in a test.',
  ),
);
