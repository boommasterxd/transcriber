import 'package:test/test.dart';

import '../../../tool/quality/parameter_count.dart';

void main() {
  final declarations = <String, String Function(String)>{
    'function': (parameters) => 'void run($parameters) {}',
    'method': (parameters) => 'class Value { void run($parameters) {} }',
    'constructor': (parameters) => 'class Value { Value($parameters); }',
    'named constructor': (parameters) =>
        'class Value { Value.named($parameters); }',
    'factory': (parameters) =>
        'class Value { factory Value($parameters) = Other; }',
    'copyWith': (parameters) =>
        'class Value { Value copyWith($parameters) => this; }',
    'closure': (parameters) => 'final run = ($parameters) => 1;',
    'function type': (parameters) =>
        'typedef Run = void Function($parameters);',
    'callback': (parameters) => 'void run(void callback($parameters)) {}',
  };
  for (final entry in declarations.entries) {
    for (final named in [false, true]) {
      test('${entry.key} counts ${named ? 'named' : 'positional'} limits', () {
        final accepted = entry.value(_parameters(6, named));
        final rejected = entry.value(_parameters(7, named));
        expect(parameterCountViolations(accepted, 'fixture.dart'), isEmpty);
        expect(parameterCountViolations(rejected, 'fixture.dart'), [
          contains('has 7 parameters (limit 6)'),
        ]);
      });
    }
  }
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

String _parameters(int count, bool named) {
  final parameters = [
    for (var index = 0; index < count; index++) 'int p$index',
  ].join(', ');
  return named ? '{$parameters}' : parameters;
}
