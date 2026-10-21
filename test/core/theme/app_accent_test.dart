import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/theme/app_accent.dart';

void main() {
  group('AppAccent', () {
    test('exposes stable persisted ids for every accent', () {
      expect(AppAccent.violet.id, 'violet');
      expect(AppAccent.blue.id, 'blue');
      expect(AppAccent.emerald.id, 'emerald');
      expect(AppAccent.amber.id, 'amber');
      expect(AppAccent.magenta.id, 'magenta');
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
