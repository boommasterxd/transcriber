import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/gemma_model_spec.dart';
import 'package:transcriber/services/summarization/gemma_engine.dart';

import 'gemma_engine_test_support.dart';

late List<String> _events;
late FakeGemmaRuntime _runtime;
late MemoryGemmaMarkerStore _markers;
late GemmaEngine _engine;

void main() {
  setUp(() {
    _events = [];
    _runtime = FakeGemmaRuntime(_events);
    _markers = MemoryGemmaMarkerStore(_events);
    _engine = GemmaEngine.test(runtime: _runtime, markerStore: _markers);
  });
  _registerSuccessfulDeletionTests();
  _registerFailedDeletionTests();
}

void _registerSuccessfulDeletionTests() {
  test('closes and clears an active model before uninstalling it', () async {
    final spec = testSpec(id: 'active_model', modelTypeId: 'general');
    await _engine.download(spec);
    await _summarize(_engine, _runtime, spec);
    _events.clear();

    await _engine.deleteDownload(spec);

    expect(_events, [
      'model.close',
      'runtime.clearIdentity',
      'runtime.uninstall:active_model.task',
      'marker.delete:active_model',
    ]);
    expect(await _engine.isDownloaded(spec), isFalse);

    _runtime.model.enqueue(['Reloaded']);
    await _engine.summarize(
      spec,
      'Transcript',
      german: false,
      fallbackTitle: 'Fallback',
      backendId: 'cpu',
    );
    expect(_runtime.activationCalls, hasLength(2));
  });

  test(
    'uninstalls a non-active model without clearing the active one',
    () async {
      final active = testSpec(id: 'kept_active', modelTypeId: 'general');
      final removed = testSpec(id: 'removed_inactive');
      await _summarize(_engine, _runtime, active);
      await _engine.download(removed);
      _runtime.model.enqueue(['Reactivate retained model']);
      await _engine.summarize(
        active,
        'Transcript',
        german: false,
        fallbackTitle: 'Fallback',
        backendId: 'gpu',
      );
      _events.clear();

      await _engine.deleteDownload(removed);

      expect(_events, [
        'runtime.uninstall:removed_inactive.task',
        'marker.delete:removed_inactive',
      ]);
      _runtime.model.enqueue(['The active model remains cached']);
      await _engine.summarize(
        active,
        'Transcript',
        german: false,
        fallbackTitle: 'Fallback',
        backendId: 'gpu',
      );
      expect(_runtime.activationCalls, hasLength(2));
    },
  );

  test('clears an unloaded active identity before uninstalling it', () async {
    final spec = testSpec(id: 'identity_only');
    await _engine.download(spec);
    _events.clear();

    await _engine.deleteDownload(spec);

    expect(_events, [
      'runtime.clearIdentity',
      'runtime.uninstall:identity_only.task',
      'marker.delete:identity_only',
    ]);
  });
}

void _registerFailedDeletionTests() {
  test('preserves the marker and reloads after uninstall failure', () async {
    final spec = testSpec(id: 'failed_uninstall', modelTypeId: 'general');
    await _engine.download(spec);
    await _summarize(_engine, _runtime, spec);
    _events.clear();
    final error = StateError('uninstall failed');
    _runtime.uninstallError = error;

    await expectLater(_engine.deleteDownload(spec), throwsA(same(error)));

    expect(await _engine.isDownloaded(spec), isTrue);
    expect(_events, [
      'model.close',
      'runtime.clearIdentity',
      'runtime.uninstall:failed_uninstall.task',
    ]);
    expect(_events, isNot(contains('marker.delete:failed_uninstall')));

    _runtime.uninstallError = null;
    await _summarize(_engine, _runtime, spec);
    expect(_runtime.activationCalls, hasLength(2));
  });

  test(
    'preserves the marker and skips uninstall when identity clear fails',
    () async {
      final spec = testSpec(id: 'failed_clear', modelTypeId: 'general');
      await _engine.download(spec);
      await _summarize(_engine, _runtime, spec);
      _events.clear();
      final error = StateError('identity clear failed');
      _runtime.clearIdentityError = error;

      await expectLater(_engine.deleteDownload(spec), throwsA(same(error)));

      expect(await _engine.isDownloaded(spec), isTrue);
      expect(_events, ['model.close', 'runtime.clearIdentity']);
      expect(_events, isNot(contains('runtime.uninstall:failed_clear.task')));
      _runtime.clearIdentityError = null;
      await _summarize(_engine, _runtime, spec);
      expect(_runtime.activationCalls, hasLength(2));
    },
  );
}

Future<void> _summarize(
  GemmaEngine engine,
  FakeGemmaRuntime runtime,
  GemmaModelSpec spec,
) async {
  runtime.model.enqueue(['Summary']);
  await engine.summarize(
    spec,
    'Transcript',
    german: false,
    fallbackTitle: 'Fallback',
    backendId: 'cpu',
  );
}
