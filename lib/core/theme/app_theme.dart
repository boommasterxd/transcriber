import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_accent.dart';
import 'app_palette.dart';

/// Builds the [ThemeData] for a given brightness + accent. Typography uses
/// Plus Jakarta Sans (UI) with JetBrains Mono available for numeric/mono text.
class AppTheme {
  const AppTheme._();

  static const double radiusPill = 9999;
  static const double radiusCard = 22;
  static const double radiusSheet = 30;

  static ThemeData build(Brightness brightness, AppAccent accent) {
    final palette = AppPalette.from(brightness, accent);
    final baseScheme = ColorScheme.fromSeed(
      seedColor: accent.color,
      brightness: brightness,
    ).copyWith(
      surface: palette.surface,
      primary: palette.accent,
      onPrimary: palette.onAccent,
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(
      brightness == Brightness.dark
          ? ThemeData.dark().textTheme
          : ThemeData.light().textTheme,
    ).apply(bodyColor: palette.body, displayColor: palette.ink);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: baseScheme,
      scaffoldBackgroundColor: palette.bg,
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      // Rounded, floating snackbars/toasts that match the app's surfaces.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.ink,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: palette.bg,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: palette.accent,
        elevation: 6,
        insetPadding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      extensions: <ThemeExtension<dynamic>>[palette],
    );
  }

  /// Mono font used for timers, timestamps and masked keys.
  static TextStyle mono({
    required Color color,
    double size = 12,
    FontWeight weight = FontWeight.w600,
  }) =>
      GoogleFonts.jetBrainsMono(color: color, fontSize: size, fontWeight: weight);
}
