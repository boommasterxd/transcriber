import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/theme/app_accent.dart';

void main() {
  group('AppAccent', () {
    test('exposes stable ids and base colors for every accent', () {
      expect(AppAccent.violet.id, 'violet');
      expect(AppAccent.violet.color, const Color(0xFF6C5CE7));
      expect(AppAccent.blue.id, 'blue');
      expect(AppAccent.blue.color, const Color(0xFF2F7BF6));
      expect(AppAccent.emerald.id, 'emerald');
      expect(AppAccent.emerald.color, const Color(0xFF12A36B));
      expect(AppAccent.amber.id, 'amber');
      expect(AppAccent.amber.color, const Color(0xFFE8883A));
      expect(AppAccent.magenta.id, 'magenta');
      expect(AppAccent.magenta.color, const Color(0xFFC13D9E));
    });

    test('resolves each persisted id', () {
      for (final accent in AppAccent.values) {
        expect(AppAccent.fromId(accent.id), same(accent));
      }
    });

    test('falls back to blue for null and unknown ids', () {
      expect(AppAccent.fromId(null), AppAccent.blue);
      expect(AppAccent.fromId('not-an-accent'), AppAccent.blue);
      expect(AppAccent.fromId('BLUE'), AppAccent.blue);
    });
  });
}
