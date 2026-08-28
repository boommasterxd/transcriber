part of 'check_coverage.dart';

final class _LcovParser {
  _LcovParser(this.lines);

  final List<String> lines;
  final Map<String, _SourceCoverage> _sources = {};
  _SourceCoverage? _current;

  Map<String, _SourceCoverage> parse() {
    for (var index = 0; index < lines.length; index++) {
      try {
        _read(lines[index]);
      } on FormatException catch (error) {
        throw FormatException('LCOV line ${index + 1}: ${error.message}');
      }
    }
    if (_current != null) {
      throw const FormatException('LCOV ended before end_of_record.');
    }
    return _sources;
  }

  void _read(String line) {
    if (line.isEmpty) return;
    if (line.startsWith('SF:')) {
      if (_current != null) {
        throw const FormatException('nested SF record.');
      }
      final path = line.substring(3);
      if (path.isEmpty) throw const FormatException('empty SF path.');
      final canonical = File(path).absolute.path;
      if (_sources.containsKey(canonical)) {
        throw FormatException('duplicate source $path.');
      }
      _current = _SourceCoverage();
      _sources[canonical] = _current!;
      return;
    }
    if (line == 'end_of_record') {
      if (_current == null) {
        throw const FormatException('end_of_record without SF.');
      }
      _current = null;
      return;
    }
    if (line.startsWith('DA:')) {
      final fields = _fields(line.substring(3), 2, 'DA');
      final sourceLine = _integer(fields[0], 'DA line', 1);
      final hits = _integer(fields[1], 'DA hits', 0);
      final source = _requireSource('DA');
      if (source.lineHits.containsKey(sourceLine)) {
        throw FormatException('duplicate DA line $sourceLine.');
      }
      source.lineHits[sourceLine] = hits;
      return;
    }
    if (line.startsWith('BRDA:')) {
      final fields = _fields(line.substring(5), 4, 'BRDA');
      final sourceLine = _integer(fields[0], 'BRDA line', 1);
      final block = _integer(fields[1], 'BRDA block', 0);
      final branch = _integer(fields[2], 'BRDA branch', 0);
      final taken = fields[3] == '-' ? 0 : _integer(fields[3], 'BRDA hits', 0);
      final source = _requireSource('BRDA');
      final key = '$sourceLine,$block,$branch';
      if (source.nativeBranches.containsKey(key)) {
        throw FormatException('duplicate BRDA branch $key.');
      }
      source.nativeBranches[key] = taken;
      return;
    }
    if (line.startsWith('FNDA:')) {
      final fields = _fields(line.substring(5), 2, 'FNDA');
      final hits = _integer(fields[0], 'FNDA hits', 0);
      final name = fields.skip(1).join(',');
      final source = _requireSource('FNDA');
      if (source.nativeFunctions.containsKey(name)) {
        throw FormatException('duplicate FNDA function $name.');
      }
      source.nativeFunctions[name] = hits;
    }
  }

  _SourceCoverage _requireSource(String record) =>
      _current ?? (throw FormatException('$record outside an SF record.'));

  List<String> _fields(String value, int minimum, String record) {
    final fields = value.split(',');
    if (fields.length < minimum ||
        fields.take(minimum).any((field) => field.isEmpty)) {
      throw FormatException('malformed $record record.');
    }
    return fields;
  }

  int _integer(String value, String name, int minimum) {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < minimum) {
      throw FormatException('invalid $name.');
    }
    return parsed;
  }
}

final class _SourceCoverage {
  final Map<int, int> lineHits = {};
  final Map<String, int> nativeBranches = {}, nativeFunctions = {};

  bool get hasLines => lineHits.isNotEmpty;
  _Metric get lineCoverage => _Metric.fromHits(lineHits.values);
  _Metric functionCoverage(_SourceAnalysis source) => nativeFunctions.isNotEmpty
      ? _Metric.fromHits(nativeFunctions.values)
      : _coverageForSpans(source.functionSpans);
  _Metric branchCoverage(_SourceAnalysis source) => nativeBranches.isNotEmpty
      ? _Metric.fromHits(nativeBranches.values)
      : _coverageForSpans(source.branchSpans);

  _Metric _coverageForSpans(List<_LineSpan> spans) {
    var result = const _Metric();
    for (final span in spans) {
      final hits = lineHits.entries
          .where((entry) => span.contains(entry.key))
          .map((entry) => entry.value)
          .toList();
      if (hits.isNotEmpty) {
        result += _Metric(
          covered: hits.any((hit) => hit > 0) ? 1 : 0,
          total: 1,
        );
      }
    }
    return result;
  }
}

final class _Metric {
  const _Metric({this.covered = 0, this.total = 0});

  factory _Metric.fromHits(Iterable<int> hits) =>
      _Metric(covered: hits.where((hit) => hit > 0).length, total: hits.length);

  final int covered, total;

  _Metric operator +(_Metric other) =>
      _Metric(covered: covered + other.covered, total: total + other.total);
}
