import 'package:test/test.dart';

import '../../../tool/quality/check_coverage.dart';
import 'coverage_test_support.dart';

const _owner = '''
part 'fragment.dart';
int owner(bool flag) => flag ? 1 : 0;
''';
const _fragment = '''
part of 'owner.dart';
int fragment(bool flag) => flag ? 1 : 0;
''';

void main() {
  for (final partial in [false, true]) {
    group('${partial ? 'partial' : 'full'} maintained-part coverage', () {
      late CoverageFixture fixture;
      setUp(() {
        fixture = CoverageFixture.create({
          'owner.dart': _owner,
          'fragment.dart': _fragment,
        });
      });
      tearDown(() => fixture.dispose());

      CoverageReport report({bool includePart = true, int partHits = 1}) =>
          CoverageReport.parse(
            [
              ..._record(fixture, 'owner.dart', 1),
              if (includePart) ..._record(fixture, 'fragment.dart', partHits),
            ],
            sources: fixture.sources,
            isPartial: partial,
          );

      test('counts separately instrumented library and part metrics', () {
        final measured = report();
        expect(measured.coveredSources, 2);
        expect(measured.totalLines, 2);
        expect(measured.totalFunctions, 2);
        expect(measured.totalBranches, 4);
        expect(measured.nonInstrumentableSources, isEmpty);
        expect(measured.thresholdFailures(), isEmpty);
      });

      test('removing the part record fails the complete inventory', () {
        final measured = report(includePart: false);
        expect(measured.missingSources, ['lib/fragment.dart']);
        expect(measured.thresholdFailures(), [
          contains('Coverage is missing 1'),
        ]);
      });

      test('zeroing part hits lowers all four enforced metrics', () {
        final measured = report(partHits: 0);
        expect(measured.missingSources, isEmpty);
        expect(measured.lineRate, 50);
        expect(measured.statementRate, 50);
        expect(measured.functionRate, 50);
        expect(measured.branchRate, 50);
        expect(measured.thresholdFailures(), hasLength(4));
      });
    });
  }
  test('generated exclusion requires both its suffix and exact header', () {
    final fixture = CoverageFixture.create({
      'generated.g.dart':
          '// GENERATED CODE - DO NOT MODIFY BY HAND\n$_fragment',
      'maintained.g.dart': _fragment,
      'maintained.dart':
          '// GENERATED CODE - DO NOT MODIFY BY HAND\n$_fragment',
    });
    addTearDown(fixture.dispose);
    final measured = CoverageReport.parse([], sources: fixture.sources);
    expect(measured.nonInstrumentableSources, {
      'lib/generated.g.dart': 'generated Dart source',
    });
    expect(measured.missingSources, [
      'lib/maintained.dart',
      'lib/maintained.g.dart',
    ]);
  });
  test('includes records even for a structurally non-instrumentable unit', () {
    final fixture = CoverageFixture.create({'data.dart': 'const value = 1;'});
    addTearDown(fixture.dispose);
    final measured = CoverageReport.parse(
      fixture.record('data.dart', ['DA:1,0']),
      sources: fixture.sources,
    );
    expect(measured.nonInstrumentableSources, isEmpty);
    expect(measured.totalLines, 1);
    expect(measured.lineRate, 0);
  });
}

List<String> _record(CoverageFixture fixture, String source, int hits) =>
    fixture.record(source, [
      'DA:2,$hits',
      'BRDA:2,0,0,$hits',
      'BRDA:2,0,1,$hits',
    ]);
