import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:test/test.dart';

import '../../../tool/quality/coverage_source_kind.dart';

void main() {
  final contracts = [
    'abstract interface class Port { void run(); }',
    'typedef Callback = void Function();',
    'typedef void Callback();',
  ];
  for (final source in contracts) {
    test('classifies a contract-only unit: $source', () {
      final unit = parseString(content: source).unit;
      expect(
        nonInstrumentableSourceReason(unit),
        'abstract interfaces and typedefs only',
      );
    });
  }
  test('classifies real part fragments before their declarations', () {
    final unit = parseString(
      content: '''
part of 'owner.dart';
int choose(bool flag) => flag ? 1 : 0;
''',
    ).unit;
    expect(nonInstrumentableSourceReason(unit), 'part fragment');
  });
  final maintained = [
    '',
    'const value = 1;',
    'enum Mode { first, second }',
    'class Value { int read() => 1; }',
    'abstract class Port { int read() => 1; }',
    'abstract class Port { int value = 1; }',
  ];
  for (final source in maintained) {
    test('keeps ordinary maintained units instrumentable: $source', () {
      expect(
        nonInstrumentableSourceReason(parseString(content: source).unit),
        isNull,
      );
    });
  }
}
