import 'package:flutter/material.dart';

/// Brand tokens. The single source of truth is `store_assets/BRAND.md` — if a
/// value changes here it changes there too, because the icon, the splash and
/// the store creative are all built from the same numbers.
abstract final class BrandColors {
  /// Passport Blue — the tool itself: actions, selection, the mark.
  static const passportBlue = Color(0xFF1E5BD8);

  /// Ink Navy — the icon plate and every dark store background.
  static const inkNavy = Color(0xFF0C2350);

  /// Sky — Passport Blue lifted for dark surfaces.
  static const sky = Color(0xFFA9C6FF);

  /// Verify Green — a check that passed, and nothing else.
  static const verifyLight = Color(0xFF0F7A50);
  static const verifyDark = Color(0xFF4ED89A);

  /// Launch-screen backgrounds; these must equal the scaffold colour below or
  /// the app flashes on start.
  static const paper = Color(0xFFF7F9FC);
  static const night = Color(0xFF0D1524);
}

/// Colours that carry a meaning the Material scheme has no role for.
///
/// A compliance check that passed is green here rather than the primary blue:
/// the report is the reason someone trusts this app, and "passed" should not
/// look like "tappable". Colour is never the only signal — every row also has
/// its own icon and a written reason.
@immutable
class AppSemantics extends ThemeExtension<AppSemantics> {
  const AppSemantics({required this.pass});

  final Color pass;

  @override
  AppSemantics copyWith({Color? pass}) => AppSemantics(pass: pass ?? this.pass);

  @override
  AppSemantics lerp(ThemeExtension<AppSemantics>? other, double t) {
    if (other is! AppSemantics) return this;
    return AppSemantics(pass: Color.lerp(pass, other.pass, t)!);
  }
}

extension AppSemanticsX on ThemeData {
  AppSemantics get semantics => extension<AppSemantics>()!;
}

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: BrandColors.passportBlue,
    brightness: Brightness.light,
  ).copyWith(
    primary: BrandColors.passportBlue,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFDCE6FF),
    onPrimaryContainer: const Color(0xFF062A6B),
    // A cool, paper-neutral surface family. Material's own neutrals run warm
    // violet off a blue seed, which reads as a consumer app rather than a
    // document tool.
    surface: BrandColors.paper,
    onSurface: const Color(0xFF101A2C),
    onSurfaceVariant: const Color(0xFF48566E),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFF2F5FA),
    surfaceContainer: const Color(0xFFECF1F8),
    surfaceContainerHigh: const Color(0xFFE5ECF6),
    surfaceContainerHighest: const Color(0xFFDEE6F2),
    outline: const Color(0xFF7B8AA3),
    outlineVariant: const Color(0xFFC9D4E4),
  );
  return _base(scheme, const AppSemantics(pass: BrandColors.verifyLight));
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: BrandColors.passportBlue,
    brightness: Brightness.dark,
  ).copyWith(
    primary: BrandColors.sky,
    onPrimary: const Color(0xFF062A6B),
    primaryContainer: const Color(0xFF154099),
    onPrimaryContainer: const Color(0xFFD8E4FF),
    surface: BrandColors.night,
    onSurface: const Color(0xFFE5ECF8),
    onSurfaceVariant: const Color(0xFFA9B7CD),
    surfaceContainerLowest: const Color(0xFF070C17),
    surfaceContainerLow: const Color(0xFF121B2C),
    surfaceContainer: const Color(0xFF172236),
    surfaceContainerHigh: const Color(0xFF1E2B42),
    surfaceContainerHighest: const Color(0xFF26354F),
    outline: const Color(0xFF6D7C94),
    outlineVariant: const Color(0xFF2E3D55),
  );
  return _base(scheme, const AppSemantics(pass: BrandColors.verifyDark));
}

ThemeData _base(ColorScheme scheme, AppSemantics semantics) {
  final radius = BorderRadius.circular(14);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    extensions: [semantics],
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
  );
}
