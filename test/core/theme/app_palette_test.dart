import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';

void main() {
  _registerPaletteFactories();
  _registerPaletteInterpolation();
  _registerPaletteContextAccessor();
}

void _registerPaletteFactories() {
  group('AppPalette factories', () {
    test('builds the light palette with semantic light colors', () {
      final palette = AppPalette.light(AppAccent.emerald);

      expect(palette.brightness, Brightness.light);
      expect(palette.isDark, isFalse);
      expect(palette.accent, AppAccent.emerald.color);
      expect(palette.accentDeep, const Color(0xFF0E8256));
      expect(palette.accentSoft, const Color(0xFFE5F5EF));
      expect(palette.accentSoft2, const Color(0xFFF1F9F6));
      expect(palette.onAccent, const Color(0xFFFFFFFF));
      expect(palette.bg, const Color(0xFFF7F6FB));
      expect(palette.surface, const Color(0xFFFFFFFF));
      expect(palette.ink, const Color(0xFF16131F));
      expect(palette.body, const Color(0xFF3A3645));
      expect(palette.muted, const Color(0xFF8C889A));
      expect(palette.faint, const Color(0xFFB6B2C2));
      expect(palette.line, const Color(0xFFF1EFF6));
      expect(palette.line2, const Color(0xFFE4E1EE));
      expect(palette.chip, const Color(0xFFF2F0F7));
      expect(palette.coral, const Color(0xFFFF6B57));
      expect(palette.coralInk, const Color(0xFFE8543C));
      expect(palette.coralSoft, const Color(0xFFFFF4F1));
      expect(palette.mint, const Color(0xFF12B886));
      expect(palette.mintSoft, const Color(0xFFE6FAF1));
      expect(palette.skel1, const Color(0xFFECEAF5));
      expect(palette.skel2, const Color(0xFFF8F7FC));
      expect(palette.waveOff, const Color(0xFFDAD5EA));
      expect(palette.shadow, const Color(0x0F141028));
      expect(palette.shadowLg, const Color(0x1A141028));
      expect(palette.chatBg, const Color(0xFFE7E0D6));
      expect(palette.chatBubble, const Color(0xFFFFFFFF));
      expect(palette.chatInk, const Color(0xFF16131F));
    });

    test('builds the dark palette with semantic dark colors', () {
      final palette = AppPalette.dark(AppAccent.magenta);

      expect(palette.brightness, Brightness.dark);
      expect(palette.isDark, isTrue);
      expect(palette.accent, AppAccent.magenta.color);
      expect(palette.accentDeep, const Color(0xFF9A317E));
      expect(palette.accentSoft, const Color(0xFF432144));
      expect(palette.accentSoft2, const Color(0xFF341E3A));
      expect(palette.onAccent, const Color(0xFFFFFFFF));
      expect(palette.bg, const Color(0xFF100E18));
      expect(palette.surface, const Color(0xFF1B1828));
      expect(palette.ink, const Color(0xFFF3F1FA));
      expect(palette.body, const Color(0xFFC4C0D2));
      expect(palette.muted, const Color(0xFF837F92));
      expect(palette.faint, const Color(0xFF5A566C));
      expect(palette.line, const Color(0xFF262234));
      expect(palette.line2, const Color(0xFF322E42));
      expect(palette.chip, const Color(0xFF272338));
      expect(palette.coral, const Color(0xFFFF6B57));
      expect(palette.coralInk, const Color(0xFFFF8B79));
      expect(palette.coralSoft, const Color(0xFF33232E));
      expect(palette.mint, const Color(0xFF12B886));
      expect(palette.mintSoft, const Color(0xFF14302A));
      expect(palette.skel1, const Color(0xFF262234));
      expect(palette.skel2, const Color(0xFF322E44));
      expect(palette.waveOff, const Color(0xFF3A3550));
      expect(palette.shadow, const Color(0x73000000));
      expect(palette.shadowLg, const Color(0x8C000000));
      expect(palette.chatBg, const Color(0xFF0B141A));
      expect(palette.chatBubble, const Color(0xFF1F2C34));
      expect(palette.chatInk, const Color(0xFFE9E6EC));
    });

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
