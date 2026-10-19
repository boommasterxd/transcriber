part of 'check_coverage.dart';

bool hasExecutableAppSources(Iterable<String> sources, {String? root}) {
  final directory = Directory(
    root ?? Directory.current.path,
  ).resolveSymbolicLinksSync();
  var executable = false;
  for (final source in sources) {
    if (!source.startsWith('lib/')) {
      throw const FormatException('Expected a local application source path.');
    }
    final path = _coverageSourcePath(source, directory);
    if (_SourceAnalysis.parse(path).nonInstrumentableReason == null) {
      executable = true;
    }
  }
  return executable;
}

Future<void> mergeCoverageFiles(
  List<String> inputs,
  String output, {
  String? root,
}) async {
  if (inputs.isEmpty ||
      inputs.length > 2 ||
      inputs.toSet().length != inputs.length) {
    throw const FormatException(
      'Expected one or two distinct runtime reports.',
    );
  }
  final reports = <List<String>>[];
  final canonicalInputs = <String>{};
  for (final input in inputs) {
    final file = File(input);
    if (!canonicalInputs.add(await file.resolveSymbolicLinks())) {
      throw const FormatException(
        'Runtime reports must refer to distinct files.',
      );
    }
    reports.add(await _readRuntimeCoverage(file));
  }
  final merged = mergeLcovReports(reports, root: root);
  final target = File(output);
  await target.parent.create(recursive: true);
  await target.writeAsString(merged, flush: true);
}

Future<List<String>> _readRuntimeCoverage(File file) async {
  const limit = 32 * 1024 * 1024;
  final bytes = await file
      .openRead(0, limit + 1)
      .fold(BytesBuilder(copy: false), (buffer, chunk) => buffer..add(chunk));
  if (bytes.length > limit) {
    throw const FormatException('Runtime coverage exceeds its size limit.');
  }
  return const LineSplitter().convert(utf8.decode(bytes.takeBytes()));
}

String mergeLcovReports(List<List<String>> reports, {String? root}) {
  if (reports.isEmpty || reports.length > 2) {
    throw const FormatException('Expected one or two runtime reports.');
  }
  final directory = Directory(
    root ?? Directory.current.path,
  ).resolveSymbolicLinksSync();
  final merged = <String, _SourceCoverage>{};
  for (final report in reports) {
    final parsed = _parseRuntimeCoverage(report, directory);
    if (parsed.isEmpty || !parsed.values.any((source) => source.hasLines)) {
      throw const FormatException(
        'An expected runtime has no coverage records.',
      );
    }
    for (final entry in parsed.entries) {
      final previous = merged[entry.key];
      if (previous == null) {
        merged[entry.key] = entry.value;
      } else {
        _mergeSourceCoverage(previous, entry.value);
      }
    }
  }
  return _writeMergedCoverage(merged);
}

Map<String, _SourceCoverage> _parseRuntimeCoverage(
  List<String> lines,
  String root,
) {
  final normalized = <String>[];
  final summaries = <String, Map<String, int>>{};
  String? current;
  for (final line in lines) {
    if (line.startsWith('SF:')) {
      final canonical = _coverageSourcePath(line.substring(3), root);
      current = canonical;
      summaries.putIfAbsent(current, () => {});
      normalized.add('SF:$canonical');
    } else if (_summaryRecord.hasMatch(line)) {
      if (current == null) {
        throw const FormatException('Coverage summary outside a source.');
      }
      final fields = line.split(':');
      if (summaries[current]!.containsKey(fields[0])) {
        throw const FormatException('Duplicate runtime coverage summary.');
      }
      summaries[current]![fields[0]] = int.parse(fields[1]);
    } else {
      _validateRuntimeRecord(line, current);
      normalized.add(line);
      if (line == 'end_of_record') current = null;
    }
  }
  final parsed = _LcovParser(normalized).parse();
  for (final entry in summaries.entries) {
    _validateSummaries(entry.value, parsed[entry.key]!);
  }
  return parsed;
}

String _coverageSourcePath(String source, String root) {
  final canonical = File(paths.join(root, source)).resolveSymbolicLinksSync();
  if (!paths.isWithin(root, canonical) || !canonical.endsWith('.dart')) {
    throw const FormatException('Coverage source escapes the project.');
  }
  return canonical;
}

final _summaryRecord = RegExp(r'^(LF|LH|BRF|BRH):[0-9]+$');
final _runtimeRecord = RegExp(
  r'^(DA:[1-9][0-9]*,[0-9]+|BRDA:[1-9][0-9]*,[0-9]+,[0-9]+,([0-9]+|-))$',
);

void _validateRuntimeRecord(String line, String? current) {
  if (line.isEmpty || line == 'end_of_record') return;
  if (line.startsWith('TN:') && current == null) return;
  if (!_runtimeRecord.hasMatch(line)) {
    throw const FormatException(
      'Unsupported or malformed runtime coverage record.',
    );
  }
}

void _validateSummaries(Map<String, int> summaries, _SourceCoverage source) {
  final expected = {
    'LF': source.lineHits.length,
    'LH': source.lineHits.values.where((hit) => hit > 0).length,
    'BRF': source.nativeBranches.length,
    'BRH': source.nativeBranches.values.where((hit) => hit > 0).length,
  };
  if (summaries.entries.any((entry) => expected[entry.key] != entry.value)) {
    throw const FormatException(
      'Runtime coverage summary does not match its records.',
    );
  }
}

void _mergeSourceCoverage(_SourceCoverage target, _SourceCoverage other) {
  final keys = target.nativeBranches.keys.toSet();
  if (keys.length != other.nativeBranches.length ||
      !keys.containsAll(other.nativeBranches.keys)) {
    throw const FormatException(
      'Runtime coverage has incompatible branch layouts.',
    );
  }
  _unionHits(target.lineHits, other.lineHits);
  _unionHits(target.nativeBranches, other.nativeBranches);
}

void _unionHits<T>(Map<T, int> target, Map<T, int> other) {
  for (final entry in other.entries) {
    final previous = target[entry.key] ?? 0;
    target[entry.key] = previous > entry.value ? previous : entry.value;
  }
}

String _writeMergedCoverage(Map<String, _SourceCoverage> sources) {
  final output = StringBuffer();
  for (final path in sources.keys.toList()..sort()) {
    final source = sources[path]!;
    output.writeln('SF:$path');
    for (final line in source.lineHits.keys.toList()..sort()) {
      output.writeln('DA:$line,${source.lineHits[line]}');
    }
    for (final branch in source.nativeBranches.keys.toList()..sort()) {
      output.writeln('BRDA:$branch,${source.nativeBranches[branch]}');
    }
    output.writeln('LF:${source.lineHits.length}');
    output.writeln(
      'LH:${source.lineHits.values.where((hit) => hit > 0).length}',
    );
    output.writeln('end_of_record');
  }
  return output.toString();
}
