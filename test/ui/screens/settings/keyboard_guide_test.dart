import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/core/theme/app_theme.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/ui/screens/settings/widgets/keyboard_guide.dart';

import '../../../support/app_test_fakes.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('guide uses readable secondary text in $brightness', (
      tester,
    ) async {
      final palette = AppPalette.from(brightness, AppAccent.blue);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsControllerProvider.overrideWith(TestSettingsController.new),
          ],
          child: MaterialApp(
            theme: AppTheme.build(brightness, AppAccent.blue),
            home: Scaffold(
              backgroundColor: palette.bg,
              body: const SingleChildScrollView(child: KeyboardGuide()),
            ),
          ),
        ),
      );
      final texts = tester.widgetList<Text>(
        find.descendant(
          of: find.byType(KeyboardGuide),
          matching: find.byType(Text),
        ),
      );
      expect(texts, isNotEmpty);
      for (final text in texts) {
        final color = text.style!.color!;
        final contrast = _contrast(color, palette.bg);
        expect(contrast, greaterThanOrEqualTo(4.5));
        expect(contrast, lessThan(_contrast(palette.body, palette.bg)));
      }
    });
  }
}

double _contrast(Color text, Color background) {
  final luminance = text.computeLuminance();
  final backdrop = background.computeLuminance();
  return (max(luminance, backdrop) + 0.05) / (min(luminance, backdrop) + 0.05);
}
