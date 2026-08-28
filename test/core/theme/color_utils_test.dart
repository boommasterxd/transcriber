import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/theme/color_utils.dart';

void main() {
  group('mixSrgb', () {
    const red = Color(0xFFFF0000);
    const blue = Color(0xFF0000FF);

    test('returns the first color at amount one and the second at zero', () {
      expect(mixSrgb(red, blue, 1), red);
      expect(mixSrgb(red, blue, 0), blue);
    });

    test('interpolates channels in sRGB with integer rounding', () {
      expect(mixSrgb(red, blue, 0.5), const Color(0xFF800080));
      expect(
        mixSrgb(const Color(0xFF010203), const Color(0xFF000000), 0.5),
        const Color(0xFF010102),
      );
    });

    test('clamps amounts outside the interpolation range', () {
      expect(mixSrgb(red, blue, -0.25), blue);
      expect(mixSrgb(red, blue, 1.25), red);
    });

    test('always returns an opaque color regardless of input alpha', () {
      final result = mixSrgb(
        const Color(0x40102030),
        const Color(0x80405060),
        0.25,
      );

      expect(result, const Color(0xFF344454));
      expect(result.a, 1);
    });
  });
}
