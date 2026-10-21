import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';

void main() {
  _registerPaletteFactories();
  _registerFocusIndicatorColors();
  _registerPaletteInterpolation();
  _registerPaletteContextAccessor();
}

void _registerFocusIndicatorColors() {
  test('focus outlines contrast with each accent and the app background', () {
    for (final brightness in Brightness.values) {
      for (final accent in AppAccent.values) {
        final palette = AppPalette.from(brightness, accent);
        final colors = palette.focusIndicatorColors;

        expect(
          contrastRatio(colors.first, palette.accent),
          greaterThanOrEqualTo(3),
        );
        expect(contrastRatio(colors.last, palette.bg), greaterThanOrEqualTo(3));
      }
    }
  });
}

double contrastRatio(Color a, Color b) {
  final lighter = a.computeLuminance() > b.computeLuminance() ? a : b;
  final darker = identical(lighter, a) ? b : a;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}

void _registerPaletteFactories() {
  group('AppPalette factories', () {
    test('from selects the palette matching brightness', () {
      expect(
        AppPalette.from(Brightness.light, AppAccent.violet).isDark,
        isFalse,
      );
      expect(AppPalette.from(Brightness.dark, AppAccent.violet).isDark, isTrue);
    });
  });
}

void _registerPaletteInterpolation() {
  group('AppPalette interpolation', () {
    test('copyWith returns the immutable palette unchanged', () {
      final palette = AppPalette.light(AppAccent.blue);

      expect(identical(palette.copyWith(), palette), isTrue);
    });

    test('lerp keeps this for incompatible extensions and lower t', () {
      final palette = AppPalette.light(AppAccent.blue);
      final other = AppPalette.dark(AppAccent.amber);

      expect(identical(palette.lerp(null, 1), palette), isTrue);
      expect(identical(palette.lerp(other, 0), palette), isTrue);
      expect(identical(palette.lerp(other, 0.49), palette), isTrue);
    });

    test('lerp switches to the other palette at and above midpoint', () {
      final palette = AppPalette.light(AppAccent.blue);
      final other = AppPalette.dark(AppAccent.amber);

      expect(identical(palette.lerp(other, 0.5), other), isTrue);
      expect(identical(palette.lerp(other, 1), other), isTrue);
    });
  });
}

void _registerPaletteContextAccessor() {
  group('AppPalette context accessor', () {
    testWidgets(
      'BuildContext palette accessor reads the registered extension',
      (tester) async {
        final palette = AppPalette.dark(AppAccent.violet);
        AppPalette? received;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: <ThemeExtension<dynamic>>[palette]),
            home: Builder(
              builder: (context) {
                received = context.palette;
                return const SizedBox();
              },
            ),
          ),
        );

        expect(identical(received, palette), isTrue);
      },
    );
  });
}
