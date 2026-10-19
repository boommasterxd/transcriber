import 'dart:io';

import 'check_coverage.dart';

export 'check_coverage.dart'
    show hasExecutableAppSources, mergeCoverageFiles, mergeLcovReports;

Future<void> main(List<String> arguments) async {
  try {
    if (arguments.length < 3 || arguments.first != '--output') {
      throw const FormatException(
        'Usage: merge_coverage.dart --output <path> <runtime-lcov> [...]',
      );
    }
    await mergeCoverageFiles(arguments.skip(2).toList(), arguments[1]);
  } on Exception catch (error) {
    stderr.writeln('Cannot merge coverage: $error');
    exitCode = 1;
  }
}
