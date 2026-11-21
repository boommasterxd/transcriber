import 'dart:convert';
import 'dart:io';

import 'test_selection.dart';

Future<void> main(List<String> arguments) async {
  try {
    final options = _options(arguments);
    final plan = await createTestPlan(
      root: Directory.current.path,
      base: options['--base']!,
      head: options['--head']!,
    );
    final output = File(options['--output']!);
    await output.parent.create(recursive: true);
    await output.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(plan)}\n',
    );
    stdout.writeln('Flutter test mode: ${plan['mode']}. ${plan['reason']}');
  } on Exception catch (error) {
    stderr.writeln('Cannot create test plan: $error');
    exitCode = 1;
  }
}

Map<String, String> _options(List<String> arguments) {
  const keys = {'--base', '--head', '--output'};
  if (arguments.length != 6) {
    throw const FormatException('Expected --base, --head, --output.');
  }
  final options = <String, String>{};
  for (var index = 0; index < arguments.length; index += 2) {
    final key = arguments[index];
    if (!keys.contains(key) || options.containsKey(key)) {
      throw const FormatException('Unknown or duplicate option.');
    }
    options[key] = arguments[index + 1];
  }
  return options;
}
