import 'package:flutter/material.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';

Widget buildProcessingTestApp(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      extensions: <ThemeExtension<dynamic>>[AppPalette.light(AppAccent.violet)],
    ),
    home: Scaffold(body: child),
  );
}
