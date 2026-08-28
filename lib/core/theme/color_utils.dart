import 'dart:ui';

/// Mixes [a] and [b] in sRGB space, returning a color that is [amount] of [a]
/// and `1 - amount` of [b]. Mirrors the CSS `color-mix(in srgb, a X%, b)` used
/// throughout the original design.
Color mixSrgb(Color a, Color b, double amount) {
  final t = amount.clamp(0.0, 1.0);
  double lerp(double x, double y) => x * t + y * (1 - t);
  return Color.fromARGB(
    255,
    lerp(a.r * 255, b.r * 255).round(),
    lerp(a.g * 255, b.g * 255).round(),
    lerp(a.b * 255, b.b * 255).round(),
  );
}
