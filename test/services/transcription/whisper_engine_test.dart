import 'dart:io';

import 'package:background_downloader/background_downloader.dart' as bd;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:transcriber/services/transcription/whisper_engine.dart';
import 'package:whisper_kit/whisper_kit.dart';

part 'whisper_engine_test_support.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
late Directory _root;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _configureStorageFixture();
  _registerModelStorageTests();
  _registerRequestTests();
  _registerSegmentTests();
  _registerFailureTests();
  _registerDownloadTests();
}

void _configureStorageFixture() {
  setUpAll(() async {
    _root = await Directory.systemTemp.createTemp('transcriber-whisper-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (call) async {
          if (call.method == 'getApplicationSupportDirectory') {
            return _root.path;
          }
          throw MissingPluginException('Unexpected method: ${call.method}');
        });
  });
  setUp(() async {
    final directory = _modelDirectory();
    if (await directory.exists()) await directory.delete(recursive: true);
    await directory.create(recursive: true);
  });
  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
    await _root.delete(recursive: true);
  });
}

void _registerModelStorageTests() {
  test('reports a missing model without network or device access', () async {
    expect(await WhisperEngine.instance.isDownloaded('tiny'), isFalse);
    expect(await _modelDirectory().exists(), isTrue);
  });

  test('uses the expected GGML path for every supported model id', () async {
    for (final modelId in ['tiny', 'base', 'small', 'medium']) {
      final file = _modelFile(modelId);
      await file.writeAsBytes([1, 2, 3]);

      expect(await WhisperEngine.instance.isDownloaded(modelId), isTrue);
      expect(file.path, endsWith('models/whisper/ggml-$modelId.bin'));
    }
  });

  test('uses the base specification for unknown model ids', () async {
    await _modelFile('base').writeAsBytes([1]);
    await _modelFile('custom').writeAsBytes([1]);

    expect(await WhisperEngine.instance.isDownloaded('custom'), isTrue);
    await WhisperEngine.instance.deleteDownload('custom');

    expect(await _modelFile('base').exists(), isFalse);
    expect(await _modelFile('custom').exists(), isTrue);
  });

  test('tolerates deleting a missing model', () async {
    await expectLater(WhisperEngine.instance.deleteDownload('base'), completes);
  });
}

void _registerRequestTests() {
  test(
    'uses auto language and default threads for null or empty input',
    () async {
      final harness = _TranscribeHarness(const _FakeResponse(' Text ', []));
      final engine = WhisperEngine(transcribeRunner: harness.call);

      await engine.transcribeWith('tiny', '/audio/one.wav');
      expect(harness.request?.language, 'auto');
      expect(harness.request?.threads, 4);

      await engine.transcribeWith('tiny', '/audio/two.wav', languageCode: '');
      expect(harness.request?.language, 'auto');
    },
  );

  test('forwards model, path, language, and thread count', () async {
    final harness = _TranscribeHarness(const _FakeResponse('Text', []));
    final engine = WhisperEngine(transcribeRunner: harness.call);

    await engine.transcribeWith(
      'small',
      '/audio/input.wav',
      languageCode: 'de',
      threads: 7,
    );

    expect(harness.model, WhisperModel.small);
    expect(harness.modelDir, _modelDirectory().path);
    expect(harness.request?.audio, '/audio/input.wav');
    expect(harness.request?.language, 'de');
    expect(harness.request?.threads, 7);
    expect(harness.request?.isTranslate, isFalse);
  });

  test('forwards the canonical base model for an unknown id', () async {
    final harness = _TranscribeHarness(const _FakeResponse('Text', []));
    final engine = WhisperEngine(transcribeRunner: harness.call);

    await engine.transcribeWith('custom', '/audio/input.wav');

    expect(harness.model, WhisperModel.base);
  });
}

void _registerSegmentTests() {
  test('normalizes supported native timestamp representations', () async {
    const response = _FakeResponse('Complete text', [
      _FakeSegment(' Duration ', Duration(seconds: 62)),
      _FakeSegment('Integer', 2500),
      _FakeSegment('Number', 3500.0),
      _FakeSegment('Unknown', 'invalid'),
      _FakeSegment('   ', 1000),
    ]);
    final engine = WhisperEngine(
      transcribeRunner: _TranscribeHarness(response).call,
    );

    final result = await engine.transcribeWith('base', '/audio/input.wav');

    expect(result.text, 'Complete text');
    expect(result.segments.map((line) => line.time), [
      '1:02',
      '0:02',
      '0:04',
      '0:00',
    ]);
    expect(result.segments.map((line) => line.text), [
      'Duration',
      'Integer',
      'Number',
      'Unknown',
    ]);
  });

  test('creates a zero-time fallback when native segments are empty', () async {
    final harness = _TranscribeHarness(
      const _FakeResponse('  Full text  ', null),
    );
    final engine = WhisperEngine(transcribeRunner: harness.call);

    final result = await engine.transcribeWith('base', '/audio/input.wav');

    expect(result.text, 'Full text');
    expect(result.segments.single.time, '0:00');
    expect(result.segments.single.text, 'Full text');
  });
}

void _registerFailureTests() {
  test(
    'reports canonical model and file sizes for empty native text',
    () async {
      final wav = File(p.join(_root.path, 'empty.wav'));
      await _writeSizedFile(wav, 2 * 1024);
      await _writeSizedFile(_modelFile('base'), 1024 * 1024);
      final harness = _TranscribeHarness(const _FakeResponse('   ', []));
      final engine = WhisperEngine(transcribeRunner: harness.call);

      expect(
        engine.transcribeWith(
          'custom',
          wav.path,
          languageCode: 'de',
          threads: 6,
        ),
        throwsA(
          predicate<Object>(
            (error) =>
                error.toString().contains('model "base" (1MB)') &&
                error.toString().contains('language "de"') &&
                error.toString().contains('WAV 2 KB, 6 threads'),
          ),
        ),
      );
    },
  );

  test('propagates native transcription failures unchanged', () async {
    final failure = StateError('native transcription failed');
    final harness = _TranscribeHarness(null, error: failure);
    final engine = WhisperEngine(transcribeRunner: harness.call);

    await expectLater(
      engine.transcribeWith('base', '/audio/input.wav'),
      throwsA(same(failure)),
    );
  });
}

void _registerDownloadTests() {
  test('downloads the canonical model and filters invalid progress', () async {
    final harness = _DownloadHarness(bd.TaskStatus.complete);
    final progress = <double>[];
    final engine = WhisperEngine(downloadRunner: harness.call);

    await engine.download('custom', onProgress: progress.add);

    expect(harness.task?.filename, 'ggml-base.bin');
    expect(harness.task?.url, endsWith('/ggml-base.bin'));
    expect(harness.task?.directory, 'models/whisper');
    expect(progress, [0.25, 1.0]);
  });

  test('reports a non-complete download status', () async {
    final harness = _DownloadHarness(bd.TaskStatus.failed);
    final engine = WhisperEngine(downloadRunner: harness.call);

    await expectLater(
      engine.download('tiny'),
      throwsA(
        predicate<Object>(
          (error) => error.toString().contains('Download failed (failed)'),
        ),
      ),
    );
  });
}

Directory _modelDirectory() =>
    Directory(p.join(_root.path, 'models', 'whisper'));

File _modelFile(String modelId) =>
    File(p.join(_modelDirectory().path, 'ggml-$modelId.bin'));
