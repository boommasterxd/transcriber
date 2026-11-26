import 'package:test/test.dart';

import '../../../tool/quality/parameter_count.dart';

void main() {
  test('rejects a positional callback and a named constructor above the limit', () {
    const positional =
        'void run(void callback(int a, int b, int c, int d, int e, int f, int g)) {}';
    const named =
        'class Value { Value.named({int? a, int? b, int? c, int? d, int? e, int? f}); }';
    expect(parameterCountViolations(positional, 'callback.dart'), [
      contains('has 7 parameters (limit 6)'),
    ]);
    expect(parameterCountViolations(named, 'constructor.dart'), isEmpty);
    expect(
      parameterCountViolations(
        named.replaceFirst('int? f}', 'int? f, int? g}'),
        'constructor.dart',
      ),
      [contains('has 7 parameters (limit 6)')],
    );
  });
  test('malformed source cannot silently pass parameter enforcement', () {
    expect(
      () => parameterCountViolations('void incomplete(', 'broken.dart'),
      throwsFormatException,
    );
  });
  test(
    'records zero-parameter functions and nested closures independently',
    () {
      final measurements = measureParameters(
        'void run() { final nested = (int first, int second) => first; }',
        'nested.dart',
      );
      expect(measurements.map((measurement) => measurement.value), [0, 2]);
    },
  );
}
