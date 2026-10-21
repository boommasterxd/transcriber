import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTheme', () {
    test('builds a light theme and registers its palette', () {
      final theme = AppTheme.build(Brightness.light, AppAccent.amber);

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.brightness, Brightness.light);
      final extension = theme.extension<AppPalette>();
      expect(extension, isNotNull);
      expect(extension!.brightness, Brightness.light);
    });

    test('builds a dark theme and registers its palette', () {
      final theme = AppTheme.build(Brightness.dark, AppAccent.violet);
      final palette = AppPalette.dark(AppAccent.violet);

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.brightness, Brightness.dark);
      final extension = theme.extension<AppPalette>();
      expect(extension, isNotNull);
      expect(extension!.brightness, palette.brightness);
    });
  });
}
