part of 'check_coverage.dart';

final class CoverageOptions {
  const CoverageOptions._(this.lcovPath, this.scopePlan);

  factory CoverageOptions.parse(List<String> arguments) {
    var lcovPath = 'coverage/lcov.info';
    String? scopePlan;
    var hasPath = false;
    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      if (argument == '--scope-plan') {
        if (scopePlan != null || index + 1 == arguments.length) {
          throw const FormatException('Expected one --scope-plan <path>.');
        }
        scopePlan = arguments[++index];
        if (scopePlan.isEmpty || scopePlan.startsWith('-')) {
          throw const FormatException('Invalid coverage scope plan path.');
        }
      } else if (!hasPath && argument.isNotEmpty && !argument.startsWith('-')) {
        lcovPath = argument;
        hasPath = true;
      } else {
        throw const FormatException(
          'Usage: check_coverage.dart [lcov-path] [--scope-plan <path>]',
        );
      }
    }
    return CoverageOptions._(lcovPath, scopePlan);
  }

  final String lcovPath;
  final String? scopePlan;
}

final class CoverageScope {
  const CoverageScope._(this.sources, this.isPartial);

  final Map<String, String> sources;
  final bool isPartial;

  static Future<CoverageScope> load(String? planPath, {Directory? root}) async {
    final directory = root ?? Directory.current;
    if (planPath == null) {
      return CoverageScope._(discoverMaintainedSources(root: directory), false);
    }
    final plan = await validateTestPlan(
      root: directory.path,
      input: jsonDecode(File(planPath).readAsStringSync()),
    );
    final maintained = discoverMaintainedSources(root: directory);
    if (plan['mode'] == 'full') return CoverageScope._(maintained, false);
    final paths = (plan['affectedSources']! as List).cast<String>().toSet();
    final selected = Map<String, String>.fromEntries(
      maintained.entries.where((entry) => paths.contains(entry.value)),
    );
    if (selected.length != paths.length) {
      throw const FormatException('Coverage scope contains unknown sources.');
    }
    return CoverageScope._(selected, true);
  }
}
