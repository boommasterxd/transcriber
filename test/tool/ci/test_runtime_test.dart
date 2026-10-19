import 'dart:io';

import 'package:test/test.dart';

import '../../../tool/ci/test_runtime.dart';
import 'git_fixture.dart';

late GitFixture fixture;

void main() {
  setUp(() async => fixture = await GitFixture.create());
  tearDown(() => fixture.dispose());
  registerMarkerTests();
  registerInventoryTests();
  registerConfigurationTests();
  registerPathBoundaryTests();
}

void registerConfigurationTests() {
  for (final config in [
    'flutter_test_config.dart',
    'test/flutter_test_config.dart',
    'test/nested/flutter_test_config.dart',
  ]) {
    test('honors an applicable Flutter configuration: $config', () async {
      await fixture.write({
        'test/nested/first_test.dart':
            "import 'package:test/test.dart'; import 'package:transcriber/first.dart';",
        config:
            "import 'package:transcriber/second.dart';\n"
            'Future<void> testExecutable(Future<void> Function() main) => main();',
      });
      final runtime = await TestRuntimes.classify(fixture.directory.path, [
        'test/nested/first_test.dart',
      ]);
      expect(runtime.dart, isEmpty);
      expect(runtime.flutter, ['test/nested/first_test.dart']);
      expect(runtime.flutterSources, {'lib/first.dart', 'lib/second.dart'});
    });
  }
  for (final sibling in [false, true]) {
    test(
      'ignores a configuration outside the applicable ancestry: $sibling',
      () async {
        await fixture.write({
          'test/nested/first_test.dart': "import 'package:test/test.dart';",
          if (!sibling) 'test/nested/pubspec.yaml': 'name: nested\n',
          sibling
                  ? 'test/sibling/flutter_test_config.dart'
                  : 'test/flutter_test_config.dart':
              'Future<void> testExecutable(Future<void> Function() main) => main();',
        });
        final runtime = await TestRuntimes.classify(fixture.directory.path, [
          'test/nested/first_test.dart',
        ]);
        expect(runtime.dart, ['test/nested/first_test.dart']);
        expect(runtime.flutter, isEmpty);
      },
    );
  }
}

void registerMarkerTests() {
  final sources = {
    'explicit Dart marker': ("import 'package:test/test.dart';", true),
    'no marker': ('void main() {}', false),
    'Flutter marker': (
      "import 'package:flutter_test/flutter_test.dart';",
      false,
    ),
    'both markers': (
      "import 'package:test/test.dart'; import 'package:flutter_test/flutter_test.dart';",
      false,
    ),
    'Dart UI import': (
      "import 'package:test/test.dart'; import 'dart:ui';",
      false,
    ),
    'unparseable source': (
      "import 'package:test/test.dart'; void main( {",
      false,
    ),
  };
  for (final entry in sources.entries) {
    test('classifies ${entry.key} without omitting a test', () async {
      await fixture.write({'test/first_test.dart': entry.value.$1});
      final runtime = await TestRuntimes.classify(fixture.directory.path, [
        'test/first_test.dart',
      ]);
      expect(runtime.dart, entry.value.$2 ? ['test/first_test.dart'] : isEmpty);
      expect(
        runtime.flutter,
        entry.value.$2 ? isEmpty : ['test/first_test.dart'],
      );
    });
  }
}

void registerInventoryTests() {
  test(
    'prioritizes transitive local Flutter dependencies over Dart marker',
    () async {
      await fixture.write({
        'test/first_test.dart':
            "import 'package:test/test.dart'; import '../lib/first.dart';",
        'lib/first.dart': "export 'second.dart';",
        'lib/second.dart': "import 'package:flutter/foundation.dart';",
      });
      final runtime = await TestRuntimes.classify(fixture.directory.path, [
        'test/first_test.dart',
      ]);
      expect(runtime.dart, isEmpty);
      expect(runtime.flutter, ['test/first_test.dart']);
    },
  );

  test(
    'discovers and partitions the complete local inventory exactly once',
    () async {
      await fixture.write({
        'test/first_test.dart': "import 'package:test/test.dart';",
      });
      final inventory = discoverTests(fixture.directory.path);
      final runtime = await TestRuntimes.classify(
        fixture.directory.path,
        inventory,
      );
      expect(runtime.dart, ['test/first_test.dart']);
      expect(runtime.flutter, ['test/second_test.dart']);
    },
  );

  for (final inventory in [
    <String>[],
    ['test/first_test.dart', 'test/first_test.dart'],
    ['../outside_test.dart'],
  ]) {
    test('rejects an invalid test inventory: $inventory', () async {
      await expectLater(
        TestRuntimes.classify(fixture.directory.path, inventory),
        throwsFormatException,
      );
    });
  }
}

void registerPathBoundaryTests() {
  test('rejects a symbolic link in the discovered test inventory', () async {
    await Link(
      '${fixture.directory.path}/test/link_test.dart',
    ).create('../lib/first.dart');
    expect(() => discoverTests(fixture.directory.path), throwsFormatException);
  });

  test('rejects symbolic links in a Dart test dependency graph', () async {
    await fixture.write({
      'test/first_test.dart':
          "import 'package:test/test.dart'; import '../lib/first.dart';",
    });
    await fixture.remove('lib/first.dart');
    await Link(
      '${fixture.directory.path}/lib/first.dart',
    ).create('second.dart');
    await expectLater(
      TestRuntimes.classify(fixture.directory.path, ['test/first_test.dart']),
      throwsFormatException,
    );
  });

  test('rejects parent traversal in an own-package dependency URI', () async {
    await fixture.write({
      'test/first_test.dart':
          "import 'package:test/test.dart'; import 'package:transcriber/../../escape.dart';",
    });
    await expectLater(
      TestRuntimes.classify(fixture.directory.path, ['test/first_test.dart']),
      throwsFormatException,
    );
  });

  test('rejects a dependency escaping through a symbolic link parent', () async {
    await fixture.write({
      'test/first_test.dart':
          "import 'package:test/test.dart'; import '../lib/linked/escape.dart';",
    });
    final outside = await Directory.systemTemp.createTemp(
      'outside-test-runtime-',
    );
    addTearDown(() => outside.delete(recursive: true));
    await File(
      '${outside.path}/escape.dart',
    ).writeAsString('const secret = 1;');
    await Link('${fixture.directory.path}/lib/linked').create(outside.path);
    await expectLater(
      TestRuntimes.classify(fixture.directory.path, ['test/first_test.dart']),
      throwsFormatException,
    );
  });
}
