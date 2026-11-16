import 'package:material_ui/material_ui.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';

Widget themed(Widget child) => MaterialApp(
  theme: ThemeData(
    extensions: <ThemeExtension<dynamic>>[AppPalette.light(AppAccent.violet)],
  ),
  home: child,
);
