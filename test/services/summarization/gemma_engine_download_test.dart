import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/summarization/gemma_engine.dart';

import 'gemma_engine_test_support.dart';

void main() {
  late List<String> events;
  late FakeGemmaRuntime runtime;
  late MemoryGemmaMarkerStore markers;
  late GemmaEngine engine;

  setUp(() {
    events = [];
    runtime = FakeGemmaRuntime(events);
    markers = MemoryGemmaMarkerStore(events);
    engine = GemmaEngine.test(runtime: runtime, markerStore: markers);
  });

  test(
    'maps model and file types and normalizes installation progress',
    () async {
      final cases = <(String, String, ModelType)>[
        ('gemma4', 'litertlm', ModelType.gemma4),
        ('qwen', 'task', ModelType.qwen),
        ('qwen3', 'task', ModelType.qwen3),
        ('deepSeek', 'task', ModelType.deepSeek),
        ('phi', 'task', ModelType.phi),
        ('functionGemma', 'task', ModelType.functionGemma),
        ('general', 'task', ModelType.general),
        ('unknown', 'task', ModelType.gemmaIt),
      ];

      for (final (typeId, extension, expectedType) in cases) {
        final spec = testSpec(
          id: 'download_$typeId',
          modelTypeId: typeId,
          extension: extension,
          needsHfToken: true,
        );
        final progress = <double>[];

        expect(await engine.isDownloaded(spec), isFalse);
        await engine.download(
          spec,
          hfToken: 'secret-token',
          onProgress: progress.add,
        );

        final call = runtime.installCalls.last;
        expect(progress, [0, 0.25, 1]);
        expect(await engine.isDownloaded(spec), isTrue);
        expect(call.modelType, expectedType);
        expect(
          call.fileType,
          extension == 'litertlm' ? ModelFileType.litertlm : ModelFileType.task,
        );
        expect(call.token, 'secret-token');
        expect(call.url, spec.downloadUrl);
      }
    },
  );

  test(
    'omits unusable tokens and creates markers only after installation',
    () async {
      final publicSpec = testSpec(id: 'public');
      await engine.download(publicSpec, hfToken: 'ignored');
      expect(runtime.installCalls.single.token, isNull);

      runtime.installCalls.clear();
      final gatedSpec = testSpec(id: 'empty_token', needsHfToken: true);
      await engine.download(gatedSpec, hfToken: '');
      expect(runtime.installCalls.single.token, isNull);

      final failedSpec = testSpec(id: 'failed_download');
      runtime.installError = StateError('download failed');
      await expectLater(
        engine.download(failedSpec),
        throwsA(isA<StateError>()),
      );
      expect(await engine.isDownloaded(failedSpec), isFalse);
      expect(events, isNot(contains('marker.create:failed_download')));
    },
  );
}
