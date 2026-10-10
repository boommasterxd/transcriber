import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/ui/screens/settings/widgets/settings_navigation_tile.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final accent in AppAccent.values) {
      _registerPaletteTest(brightness, accent);
    }
  }
}

void _registerPaletteTest(Brightness brightness, AppAccent accent) {
  testWidgets('category tints remain visible for $brightness and $accent', (
    tester,
  ) async {
    final palette = AppPalette.from(brightness, accent);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [palette]),
        home: Scaffold(
          body: Column(
            children: [
              for (final icon in [
                Icons.keyboard_outlined,
                Icons.tune_rounded,
                Icons.settings_outlined,
              ])
                SettingsNavigationTile(
                  title: 'Category',
                  icon: icon,
                  page: const SizedBox(),
                ),
            ],
          ),
        ),
      ),
    );
    final backgrounds = <Color>{};
    for (final icon in [
      Icons.keyboard_outlined,
      Icons.tune_rounded,
      Icons.settings_outlined,
    ]) {
      final finder = find.byIcon(icon);
      final foreground = tester.widget<Icon>(finder).color!;
      final container = tester.widget<Container>(
        find.ancestor(of: finder, matching: find.byType(Container)).first,
      );
      final background = (container.decoration! as BoxDecoration).color!;
      backgrounds.add(background);
      expect(_contrast(foreground, background), greaterThanOrEqualTo(3));
    }
    expect(backgrounds, hasLength(3));
    expect(tester.takeException(), isNull);
  });
}

double _contrast(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  return ((a > b ? a : b) + 0.05) / ((a > b ? b : a) + 0.05);
}
