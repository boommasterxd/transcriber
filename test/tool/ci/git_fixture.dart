import 'dart:convert';
import 'dart:io';

import '../../../tool/ci/test_selection.dart';

class GitFixture {
  GitFixture(this.directory);

  final Directory directory;
  late String base;

  static Future<GitFixture> create() async {
    final fixture = GitFixture(
      await Directory.systemTemp.createTemp('transcriber-test-selection-'),
    );
    await fixture.git(['init', '--initial-branch=main']);
    await fixture.git(['config', 'user.name', 'Test Fixture']);
    await fixture.git(['config', 'user.email', 'fixture@example.invalid']);
    await fixture.write({
      'pubspec.yaml': 'name: transcriber\n',
      'lib/first.dart': fixtureSource('first', 1),
      'lib/second.dart': fixtureSource('second', 2),
      'test/first_test.dart': "import 'package:transcriber/first.dart';\n",
      'test/second_test.dart': "import '../lib/second.dart';\n",
    });
    fixture.base = await fixture.commit();
    return fixture;
  }

  Future<void> write(Map<String, String> files) async {
    for (final entry in files.entries) {
      final file = File('${directory.path}/${entry.key}');
      await file.parent.create(recursive: true);
      await file.writeAsString(entry.value);
    }
  }

  Future<String> git(List<String> arguments) async {
    final result = await Process.run(
      'git',
      arguments,
      workingDirectory: directory.path,
      environment: {
        'GIT_CONFIG_NOSYSTEM': '1',
        'GIT_CONFIG_GLOBAL': '/dev/null',
      },
    );
    if (result.exitCode != 0) {
      throw StateError('Git fixture failed: ${result.stderr}');
    }
    return (result.stdout as String).trim();
  }

  Future<String> commit() async {
    await git(['add', '--all']);
    await git(['commit', '--quiet', '-m', 'test: update fixture']);
    return git(['rev-parse', 'HEAD']);
  }

  Future<Map<String, Object?>> plan(Map<String, String> changes) async {
    await write(changes);
    final head = await commit();
    return createTestPlan(root: directory.path, base: base, head: head);
  }

  Future<void> remove(String path) async {
    await File('${directory.path}/$path').delete();
  }

  Future<void> dispose() async {
    await directory.delete(recursive: true);
  }
}

String fixtureSource(String name, int value) =>
    'int $name(bool condition) => condition ? $value : 0;\n';

Future<String> flutterSdkPath() async {
  final config =
      jsonDecode(await File('.dart_tool/package_config.json').readAsString())
          as Map<String, dynamic>;
  return Uri.parse(config['flutterRoot'] as String).toFilePath();
}
