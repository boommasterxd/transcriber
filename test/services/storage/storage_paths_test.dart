import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:transcriber/services/storage/storage_paths.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late String applicationSupportPath;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('transcriber-storage-test-');
    applicationSupportPath = root.path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (call) async {
          if (call.method == 'getApplicationSupportDirectory') {
            return applicationSupportPath;
          }
          throw MissingPluginException('Unexpected method: ${call.method}');
        });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
    await root.delete(recursive: true);
  });

  group('StoragePaths', () {
    test(
      'creates each model and audio directory below application support',
      () async {
        final paths = await StoragePaths.instance();

        final whisper = await paths.whisperDir();
        final gemma = await paths.gemmaDir();
        final audio = await paths.audioDir();

        expect(whisper.path, p.join(root.path, 'models', 'whisper'));
        expect(gemma.path, p.join(root.path, 'models', 'gemma'));
        expect(audio.path, p.join(root.path, 'audio'));
        expect(await whisper.exists(), isTrue);
        expect(await gemma.exists(), isTrue);
        expect(await audio.exists(), isTrue);
      },
    );

    test(
      'reuses existing directories without changing their locations',
      () async {
        final paths = await StoragePaths.instance();

        final first = await paths.audioDir();
        final second = await paths.audioDir();

        expect(first.path, second.path);
        expect(await second.exists(), isTrue);
      },
    );

    test('resolves a model file within the Gemma model directory', () async {
      final paths = await StoragePaths.instance();

      final modelFile = await paths.gemmaModelFile('gemma.task');

      expect(modelFile, p.join(root.path, 'models', 'gemma', 'gemma.task'));
    });

    test('rejects model names that could escape the Gemma directory', () async {
      final paths = await StoragePaths.instance();

      for (final name in <String>[
        '../outside.task',
        r'..\outside.task',
        '/tmp/outside.task',
        '',
        '.',
        '..',
      ]) {
        expect(
          paths.gemmaModelFile(name),
          throwsA(isA<ArgumentError>()),
          reason: name,
        );
      }
    });

    test(
      'reports a filesystem conflict instead of treating a file as a dir',
      () async {
        final paths = await StoragePaths.instance();
        final audioPath = p.join(root.path, 'audio');
        final existingDirectory = Directory(audioPath);
        if (await existingDirectory.exists()) {
          await existingDirectory.delete(recursive: true);
        }
        await File(audioPath).writeAsString('not a directory');

        expect(paths.audioDir(), throwsA(isA<FileSystemException>()));
        await File(audioPath).delete();
      },
    );
  });
}
