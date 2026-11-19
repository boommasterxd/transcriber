import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';

void main() {
  _registerPaletteFactories();
  _registerFocusIndicatorColors();
  _registerTextContrast();
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

void _registerTextContrast() {
  for (final brightness in Brightness.values) {
    for (final accent in AppAccent.values) {
      test(
        'text contrast is readable in ${brightness.name} ${accent.name}',
        () => _expectReadableText(AppPalette.from(brightness, accent)),
      );
    }
  }
}

void _expectReadableText(AppPalette palette) {
  for (final (foreground, background) in [
    (palette.onAccent, palette.accent),
    (palette.accentDeep, palette.accentSoft),
    (palette.accentDeep, palette.bg),
    (palette.coralInk, palette.coralSoft),
    (palette.mintInk, palette.mintSoft),
    (palette.mintInk, palette.chip),
    for (final surface in [palette.bg, palette.surface, palette.chip]) ...[
      (palette.muted, surface),
      (palette.faint, surface),
    ],
  ]) {
    expect(
      contrastRatio(foreground, background),
      greaterThanOrEqualTo(4.5),
      reason: '$foreground on $background',
    );
  }
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
