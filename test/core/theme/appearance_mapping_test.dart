import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/theme/app_theme_mode.dart';
import 'package:transcriber/data/models/appearance_settings.dart';

void main() {
  test('maps every persisted theme mode to its Flutter presentation', () {
    expect(AppThemeMode.system.flutterThemeMode, ThemeMode.system);
    expect(AppThemeMode.light.flutterThemeMode, ThemeMode.light);
    expect(AppThemeMode.dark.flutterThemeMode, ThemeMode.dark);
  });
}
