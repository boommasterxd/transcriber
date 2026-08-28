import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/gemma_model_spec.dart';
import 'package:transcriber/services/summarization/gemma_engine.dart';
import 'package:transcriber/services/summarization/summarization_service.dart';

import 'gemma_engine_test_support.dart';

void main() {
  late FakeGemmaRuntime runtime;
  late MemoryGemmaMarkerStore markers;
  late GemmaEngine engine;

  setUp(() {
    final events = <String>[];
    runtime = FakeGemmaRuntime(events);
    markers = MemoryGemmaMarkerStore(events);
    engine = GemmaEngine.test(runtime: runtime, markerStore: markers);
  });

  test(
    'passes runtime mapping and parses streamed structured output',
    () async {
      final spec = testSpec(
        id: 'structured',
        modelTypeId: 'general',
        supportsAudio: true,
        maxTokens: 3072,
      );
      final session = runtime.model.enqueue([
        '{"title":"Local",',
        '"gist":"Summary","points":["One"],"todos":["Do"]}',
      ]);

      final result = await engine.summarize(
        spec,
        'A German transcript',
        german: true,
        fallbackTitle: 'Fallback',
        backendId: 'npu',
      );

      expect(result.title, 'Local');
      expect(result.gist, 'Summary');
      expect(result.points, ['One']);
      expect(result.todos, ['Do']);
      expect(runtime.activationCalls.single.maxTokens, 3072);
      expect(runtime.activationCalls.single.backend, PreferredBackend.npu);
      expect(runtime.activationCalls.single.supportAudio, isTrue);
      expect(
        runtime.model.lastSystemInstruction,
        contains('präziser Assistent'),
      );
      expect(session.queries.single.text, contains('A German transcript'));
      expect(session.closed, isTrue);
    },
  );

  test('caches identical runtime and reloads after a backend change', () async {
    final spec = testSpec(id: 'cache', modelTypeId: 'general');
    await _summarize(engine, runtime, spec, 'cpu');
    await _summarize(engine, runtime, spec, 'cpu');
    expect(runtime.activationCalls, hasLength(1));

    await _summarize(engine, runtime, spec, 'gpu');
    expect(runtime.activationCalls, hasLength(2));
    expect(runtime.activationCalls.last.backend, PreferredBackend.gpu);
  });

  test('service resolves unknown ids and parses a plain response', () async {
    final session = runtime.model.enqueue(['  Plain local summary.  ']);
    final service = GemmaSummarizationService(
      'missing-model',
      fallbackTitle: 'Generated title',
      backendId: 'service-auto',
      engine: engine,
    );

    final result = await service.summarize('English input', german: false);

    expect(service, isA<SummarizationService>());
    expect(result.title, 'Generated title');
    expect(result.gist, 'Plain local summary.');
    expect(result.points, isEmpty);
    expect(result.todos, isEmpty);
    expect(runtime.installCalls.single.modelType, ModelType.qwen3);
    expect(runtime.activationCalls.single.backend, isNull);
    expect(session.queries.single.text, contains('Write in English'));
  });

  test('closes the chat when streaming fails', () async {
    final error = StateError('generation failed');
    final session = runtime.model.enqueue(['partial'], error: error);

    await expectLater(
      engine.summarize(
        testSpec(id: 'stream_error', modelTypeId: 'general'),
        'Transcript',
        german: false,
        fallbackTitle: 'Fallback',
        backendId: 'error-path',
      ),
      throwsA(same(error)),
    );
    expect(session.closed, isTrue);
  });
}

Future<void> _summarize(
  GemmaEngine engine,
  FakeGemmaRuntime runtime,
  GemmaModelSpec spec,
  String backendId,
) async {
  runtime.model.enqueue(['Summary']);
  await engine.summarize(
    spec,
    'Transcript',
    german: false,
    fallbackTitle: 'Fallback',
    backendId: backendId,
  );
}
