import 'package:flutter/material.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_theme.dart';

/// The same settings theme and text scaling for navigation and form tests.
Widget settingsTestApp({
  required Widget home,
  TextScaler textScaler = TextScaler.noScaling,
}) => MaterialApp(
  theme: AppTheme.build(Brightness.light, AppAccent.blue),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: child!,
  ),
  home: home,
);
