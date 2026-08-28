import 'package:flutter/material.dart';

import 'app_accent.dart';
import 'color_utils.dart';

/// Semantic color tokens for a given brightness + accent, registered as a
/// [ThemeExtension] so any widget can read them via `context.palette`.
///
/// These mirror the CSS custom properties (`--bg`, `--surface`, `--accent`, …)
/// from the original Transcriber design exactly.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.accent,
    required this.accentDeep,
    required this.accentSoft,
    required this.accentSoft2,
    required this.onAccent,
    required this.bg,
    required this.surface,
    required this.ink,
    required this.body,
    required this.muted,
    required this.faint,
    required this.line,
    required this.line2,
    required this.chip,
    required this.coral,
    required this.coralInk,
    required this.coralSoft,
    required this.mint,
    required this.mintSoft,
    required this.skel1,
    required this.skel2,
    required this.waveOff,
    required this.shadow,
    required this.shadowLg,
    required this.chatBg,
    required this.chatBubble,
    required this.chatInk,
  });

  final Brightness brightness;

  final Color accent;
  final Color accentDeep;
  final Color accentSoft;
  final Color accentSoft2;
  final Color onAccent;

  final Color bg;
  final Color surface;
  final Color ink;
  final Color body;
  final Color muted;
  final Color faint;
  final Color line;
  final Color line2;
  final Color chip;

  final Color coral;
  final Color coralInk;
  final Color coralSoft;
  final Color mint;
  final Color mintSoft;

  final Color skel1;
  final Color skel2;
  final Color waveOff;
  final Color shadow;
  final Color shadowLg;

  final Color chatBg;
  final Color chatBubble;
  final Color chatInk;

  bool get isDark => brightness == Brightness.dark;

  factory AppPalette.light(AppAccent accent) {
    const white = Color(0xFFFFFFFF);
    final a = accent.color;
    return AppPalette(
      brightness: Brightness.light,
      accent: a,
      accentDeep: mixSrgb(a, const Color(0xFF000000), 0.80),
      accentSoft: mixSrgb(a, white, 0.11),
      accentSoft2: mixSrgb(a, white, 0.06),
      onAccent: white,
      bg: const Color(0xFFF7F6FB),
      surface: white,
      ink: const Color(0xFF16131F),
      body: const Color(0xFF3A3645),
      muted: const Color(0xFF8C889A),
      faint: const Color(0xFFB6B2C2),
      line: const Color(0xFFF1EFF6),
      line2: const Color(0xFFE4E1EE),
      chip: const Color(0xFFF2F0F7),
      coral: const Color(0xFFFF6B57),
      coralInk: const Color(0xFFE8543C),
      coralSoft: const Color(0xFFFFF4F1),
      mint: const Color(0xFF12B886),
      mintSoft: const Color(0xFFE6FAF1),
      skel1: const Color(0xFFECEAF5),
      skel2: const Color(0xFFF8F7FC),
      waveOff: const Color(0xFFDAD5EA),
      shadow: const Color(0x0F141028),
      shadowLg: const Color(0x1A141028),
      chatBg: const Color(0xFFE7E0D6),
      chatBubble: white,
      chatInk: const Color(0xFF16131F),
    );
  }

  factory AppPalette.dark(AppAccent accent) {
    const surface = Color(0xFF1B1828);
    final a = accent.color;
    return AppPalette(
      brightness: Brightness.dark,
      accent: a,
      accentDeep: mixSrgb(a, const Color(0xFF000000), 0.80),
      accentSoft: mixSrgb(a, surface, 0.24),
      accentSoft2: mixSrgb(a, surface, 0.15),
      onAccent: const Color(0xFFFFFFFF),
      bg: const Color(0xFF100E18),
      surface: surface,
      ink: const Color(0xFFF3F1FA),
      body: const Color(0xFFC4C0D2),
      muted: const Color(0xFF837F92),
      faint: const Color(0xFF5A566C),
      line: const Color(0xFF262234),
      line2: const Color(0xFF322E42),
      chip: const Color(0xFF272338),
      coral: const Color(0xFFFF6B57),
      coralInk: const Color(0xFFFF8B79),
      coralSoft: const Color(0xFF33232E),
      mint: const Color(0xFF12B886),
      mintSoft: const Color(0xFF14302A),
      skel1: const Color(0xFF262234),
      skel2: const Color(0xFF322E44),
      waveOff: const Color(0xFF3A3550),
      shadow: const Color(0x73000000),
      shadowLg: const Color(0x8C000000),
      chatBg: const Color(0xFF0B141A),
      chatBubble: const Color(0xFF1F2C34),
      chatInk: const Color(0xFFE9E6EC),
    );
  }

  factory AppPalette.from(Brightness brightness, AppAccent accent) =>
      brightness == Brightness.dark
      ? AppPalette.dark(accent)
      : AppPalette.light(accent);

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppPaletteX on BuildContext {
  /// Convenience accessor for the active [AppPalette].
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
