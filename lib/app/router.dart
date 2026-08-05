import 'package:go_router/go_router.dart';

import '../features/export/print_sheet_screen.dart';
import '../features/photo_capture/capture_screen.dart';
import '../features/photo_capture/home_screen.dart';
import '../features/photo_capture/result_screen.dart';
import '../features/purchase/paywall_screen.dart';
import '../features/specs/country_picker_screen.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/picker', builder: (_, _) => const CountryPickerScreen()),
      GoRoute(path: '/capture', builder: (_, _) => const CaptureScreen()),
      GoRoute(path: '/pro', builder: (_, _) => const PaywallScreen()),
      GoRoute(
        path: '/result',
        builder: (context, state) {
          final path = state.extra as String?;
          if (path == null) {
            return const HomeScreen();
          }
          return ResultScreen(sourcePath: path);
        },
      ),
      GoRoute(
        path: '/sheet',
        builder: (context, state) {
          final path = state.extra as String?;
          if (path == null) {
            return const HomeScreen();
          }
          return PrintSheetScreen(sourcePath: path);
        },
      ),
    ],
  );
}
