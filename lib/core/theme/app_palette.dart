import 'package:flutter/material.dart';

import 'app_accent.dart';
import 'color_utils.dart';

/// Semantic colors derived from the selected brightness and accent.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette._(this.brightness, this.accent);

  final Brightness brightness;
  final Color accent;

  bool get isDark => brightness == Brightness.dark;

  /// Contrasting outline colors for keyboard focus on accent-colored controls.
  List<Color> get focusIndicatorColors => isDark ? [surface, ink] : [ink];

  Color get accentDeep => mixSrgb(accent, const Color(0xFF000000), 0.80);
  Color get accentSoft => isDark
      ? mixSrgb(accent, const Color(0xFF1B1828), 0.24)
      : mixSrgb(accent, const Color(0xFFFFFFFF), 0.11);
  Color get accentSoft2 => isDark
      ? mixSrgb(accent, const Color(0xFF1B1828), 0.15)
      : mixSrgb(accent, const Color(0xFFFFFFFF), 0.06);
  Color get onAccent => const Color(0xFFFFFFFF);
  Color get bg => isDark ? const Color(0xFF100E18) : const Color(0xFFF7F6FB);
  Color get surface =>
      isDark ? const Color(0xFF1B1828) : const Color(0xFFFFFFFF);
  Color get ink => isDark ? const Color(0xFFF3F1FA) : const Color(0xFF16131F);
  Color get body => isDark ? const Color(0xFFC4C0D2) : const Color(0xFF3A3645);
  Color get muted => isDark ? const Color(0xFF837F92) : const Color(0xFF8C889A);
  Color get faint => isDark ? const Color(0xFF5A566C) : const Color(0xFFB6B2C2);
  Color get line => isDark ? const Color(0xFF262234) : const Color(0xFFF1EFF6);
  Color get line2 => isDark ? const Color(0xFF322E42) : const Color(0xFFE4E1EE);
  Color get chip => isDark ? const Color(0xFF272338) : const Color(0xFFF2F0F7);
  Color get coral => const Color(0xFFFF6B57);
  Color get coralInk =>
      isDark ? const Color(0xFFFF8B79) : const Color(0xFFE8543C);
  Color get coralSoft =>
      isDark ? const Color(0xFF33232E) : const Color(0xFFFFF4F1);
  Color get mint => const Color(0xFF12B886);
  Color get mintSoft =>
      isDark ? const Color(0xFF14302A) : const Color(0xFFE6FAF1);
  Color get skel1 => isDark ? const Color(0xFF262234) : const Color(0xFFECEAF5);
  Color get skel2 => isDark ? const Color(0xFF322E44) : const Color(0xFFF8F7FC);
  Color get waveOff =>
      isDark ? const Color(0xFF3A3550) : const Color(0xFFDAD5EA);
  Color get shadow =>
      isDark ? const Color(0x73000000) : const Color(0x0F141028);
  Color get shadowLg =>
      isDark ? const Color(0x8C000000) : const Color(0x1A141028);
  Color get chatBg =>
      isDark ? const Color(0xFF0B141A) : const Color(0xFFE7E0D6);
  Color get chatBubble =>
      isDark ? const Color(0xFF1F2C34) : const Color(0xFFFFFFFF);
  Color get chatInk =>
      isDark ? const Color(0xFFE9E6EC) : const Color(0xFF16131F);

  factory AppPalette.light(AppAccent accent) =>
      AppPalette._(Brightness.light, accent.color);

  factory AppPalette.dark(AppAccent accent) =>
      AppPalette._(Brightness.dark, accent.color);

  factory AppPalette.from(Brightness brightness, AppAccent accent) =>
      AppPalette._(brightness, accent.color);

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
