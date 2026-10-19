part of 'check_coverage.dart';

const _gitSourceArguments =
    'ls-files --cached --others --exclude-standard -- lib';

final class CoverageReport {
  const CoverageReport({
    required this.coveredLines,
    required this.totalLines,
    required this.coveredBranches,
    required this.totalBranches,
    required this.coveredFunctions,
    required this.totalFunctions,
    required this.coveredSources,
    required this.totalSources,
    required this.missingSources,
    required this.nonInstrumentableSources,
    this.isPartial = false,
  });

  final int coveredLines, totalLines;
  final int coveredBranches, totalBranches;
  final int coveredFunctions, totalFunctions;
  final int coveredSources, totalSources;
  final List<String> missingSources;
  final Map<String, String> nonInstrumentableSources;
  final bool isPartial;

  int get maintainedSources => totalSources + nonInstrumentableSources.length;
  double get lineRate => _percentage(coveredLines, totalLines);
  double get statementRate => lineRate;
  double get branchRate => _percentage(coveredBranches, totalBranches);
  double get functionRate => _percentage(coveredFunctions, totalFunctions);

  factory CoverageReport.parse(
    List<String> lines, {
    Map<String, String>? sources,
    bool isPartial = false,
  }) => _CoverageBuilder(
    _LcovParser(lines).parse(),
    sources ?? discoverMaintainedSources(),
    isPartial,
  ).build();

  List<String> thresholdFailures() {
    final failures = <String>[];
    if (isPartial && maintainedSources == 0) return failures;
    if (missingSources.isNotEmpty) {
      final preview = missingSources.take(10).join(', ');
      final remainder = missingSources.length > 10
          ? ' and ${missingSources.length - 10} more'
          : '';
      failures.add(
        'Coverage is missing ${missingSources.length} executable maintained '
        'source files: $preview$remainder.',
      );
    }
    _check(failures, 'Line', lineRate, _lineThreshold, totalLines);
    _check(
      failures,
      'Statement proxy',
      statementRate,
      _statementThreshold,
      totalLines,
    );
    _check(
      failures,
      'Function proxy',
      functionRate,
      _functionThreshold,
      totalFunctions,
    );
    _check(failures, 'Branch', branchRate, _branchThreshold, totalBranches);
    return failures;
  }

  String summary() {
    if (isPartial && maintainedSources == 0) {
      return 'Partial coverage: the plan has no affected application sources. '
          'No application coverage was measured; full coverage was not checked.';
    }
    final classification = nonInstrumentableSources.entries
        .map((entry) => '${entry.key} (${entry.value})')
        .join(', ');
    final suffix = classification.isEmpty
        ? ''
        : ' Non-instrumentable sources: $classification.';
    final label = isPartial ? 'Partial coverage (selected scope)' : 'Coverage';
    return '$label: sources $coveredSources/$totalSources executable '
        '($maintainedSources maintained), lines ${lineRate.toStringAsFixed(2)}%, '
        'statements ${statementRate.toStringAsFixed(2)}%, '
        'functions ${functionRate.toStringAsFixed(2)}%, '
        'branches ${branchRate.toStringAsFixed(2)}%.$suffix';
  }

  static void _check(
    List<String> failures,
    String name,
    double actual,
    double required,
    int denominator,
  ) {
    if (denominator == 0) {
      failures.add('$name coverage has no instrumented records.');
    } else if (actual < required) {
      failures.add(
        '$name coverage is ${actual.toStringAsFixed(2)}%; required $required%.',
      );
    }
  }

  static double _percentage(int covered, int total) =>
      total == 0 ? 0 : covered * 100 / total;
}

Map<String, String> discoverMaintainedSources({Directory? root}) {
  final directory = root ?? Directory.current;
  final result = Process.runSync(
    'git',
    _gitSourceArguments.split(' '),
    workingDirectory: directory.path,
  );
  if (result.exitCode != 0) {
    throw StateError('Unable to enumerate maintained Dart sources.');
  }
  final paths = (result.stdout as String)
      .split('\n')
      .where((path) => path.endsWith('.dart'))
      .where((path) => File('${directory.path}/$path').existsSync())
      .toSet();
  if (paths.isEmpty) {
    throw StateError('No maintained Dart sources were found.');
  }
  return {
    for (final path in paths)
      File('${directory.path}/$path').absolute.path: path,
  };
}

final class _CoverageBuilder {
  _CoverageBuilder(this.reported, this.maintained, this.isPartial);

  final Map<String, _SourceCoverage> reported;
  final Map<String, String> maintained;
  final bool isPartial;

  CoverageReport build() {
    final executable = <String, _SourceAnalysis>{};
    final nonInstrumentable = <String, String>{};
    for (final entry in maintained.entries) {
      final analysis = _SourceAnalysis.parse(entry.key);
      if (analysis.nonInstrumentableReason case final reason?) {
        nonInstrumentable[entry.value] = reason;
      } else {
        executable[entry.key] = analysis;
      }
    }
    final missing =
        executable.keys
            .where((path) => !(reported[path]?.hasLines ?? false))
            .map((path) => maintained[path]!)
            .toList()
          ..sort();
    var lines = const _Metric();
    var functions = const _Metric();
    var branches = const _Metric();
    for (final entry in executable.entries) {
      final coverage = reported[entry.key];
      if (coverage == null) continue;
      lines += coverage.lineCoverage;
      functions += coverage.functionCoverage(entry.value);
      branches += coverage.branchCoverage(entry.value);
    }
    final sortedNonInstrumentable = Map.fromEntries(
      nonInstrumentable.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key)),
    );
    return CoverageReport(
      coveredLines: lines.covered,
      totalLines: lines.total,
      coveredBranches: branches.covered,
      totalBranches: branches.total,
      coveredFunctions: functions.covered,
      totalFunctions: functions.total,
      coveredSources: executable.length - missing.length,
      totalSources: executable.length,
      missingSources: missing,
      nonInstrumentableSources: sortedNonInstrumentable,
      isPartial: isPartial,
    );
  }
}
