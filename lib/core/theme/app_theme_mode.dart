import 'package:flutter/material.dart' show ThemeMode;

import '../../data/models/appearance_settings.dart';

extension AppThemeModePresentation on AppThemeMode {
  ThemeMode get flutterThemeMode => switch (this) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
}
