import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTheme', () {
    test('builds a Material 3 light theme from the selected accent', () {
      final theme = AppTheme.build(Brightness.light, AppAccent.amber);
      final palette = AppPalette.light(AppAccent.amber);

      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, palette.accent);
      expect(theme.colorScheme.onPrimary, palette.onAccent);
      expect(theme.colorScheme.surface, palette.surface);
      expect(theme.scaffoldBackgroundColor, palette.bg);
      expect(theme.splashFactory, InkRipple.splashFactory);
      final extension = theme.extension<AppPalette>();
      expect(extension, isNotNull);
      expect(extension!.accent, palette.accent);
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
      expect(theme.snackBarTheme.backgroundColor, palette.ink);
      expect(theme.snackBarTheme.actionTextColor, palette.accent);
      expect(theme.snackBarTheme.elevation, 6);
      expect(
        theme.snackBarTheme.insetPadding,
        const EdgeInsets.fromLTRB(16, 16, 16, 20),
      );
      expect(
        (theme.snackBarTheme.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(18),
      );
    });

    test('builds a Material 3 dark theme with dark typography colors', () {
      final theme = AppTheme.build(Brightness.dark, AppAccent.violet);
      final palette = AppPalette.dark(AppAccent.violet);

      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, palette.accent);
      expect(theme.colorScheme.surface, palette.surface);
      expect(theme.scaffoldBackgroundColor, palette.bg);
      expect(theme.textTheme.bodyMedium?.color, palette.body);
      expect(theme.textTheme.displayLarge?.color, palette.ink);
      final extension = theme.extension<AppPalette>();
      expect(extension, isNotNull);
      expect(extension!.brightness, palette.brightness);
      expect(theme.snackBarTheme.backgroundColor, palette.ink);
      expect(theme.snackBarTheme.actionTextColor, palette.accent);
    });

    test('exposes the design-system corner radii', () {
      expect(AppTheme.radiusPill, 9999);
      expect(AppTheme.radiusCard, 22);
      expect(AppTheme.radiusSheet, 30);
    });

    test('creates the default mono style', () {
      final style = AppTheme.mono(color: const Color(0xFF123456));

      expect(style.color, const Color(0xFF123456));
      expect(style.fontSize, 12);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.fontFamily, 'monospace');
    });

    test('creates a mono style with custom size and weight', () {
      final style = AppTheme.mono(
        color: const Color(0xFF654321),
        size: 18,
        weight: FontWeight.w300,
      );

      expect(style.color, const Color(0xFF654321));
      expect(style.fontSize, 18);
      expect(style.fontWeight, FontWeight.w300);
      expect(style.fontFamily, 'monospace');
    });
  });
}
