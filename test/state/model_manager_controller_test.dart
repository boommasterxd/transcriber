import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/data/catalog/gemma_catalog.dart';
import 'package:transcriber/data/catalog/whisper_catalog.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/models/local_model_runtime.dart';
import 'package:transcriber/state/model_manager_controller.dart';
import 'package:transcriber/state/providers.dart';
import 'package:transcriber/state/settings_controller.dart';

enum _Stage { whisper, gemma }

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _registerCoreTests();
  for (final stage in _Stage.values) {
    _registerDownloadTests(stage);
    _registerLifecycleTests(stage);
    _registerSelectionTests(stage);
  }
}

void _registerCoreTests() {
  test('status and initial state cover every catalog model', () async {
    final container = await _container(_FakeRuntime());
    final state = container.read(modelManagerControllerProvider);
    const loading = ModelStatus(
      status: DownloadStatus.downloading,
      progress: 0.4,
    );
    expect(state.whisper.keys, WhisperCatalog.models.map((model) => model.id));
    expect(state.gemma.keys, GemmaCatalog.models.map((model) => model.id));
    expect(state.whisperStatus('unknown').isDownloaded, isFalse);
    expect(loading.copyWith(progress: 0.8).progress, 0.8);
    expect(loading.copyWith(progress: 0.8).isDownloading, isTrue);
  });
  test('refresh reconciles both model catalogs through the runtime', () async {
    final runtime = _FakeRuntime()
      ..installed[_Stage.whisper]!.add('tiny')
      ..installed[_Stage.gemma]!.add(GemmaCatalog.defaultId);
    final container = await _container(runtime);
    final controller = container.manager;
    await controller.refresh();
    final state = container.read(modelManagerControllerProvider);
    expect(state.whisperStatus('tiny').isDownloaded, isTrue);
    expect(state.whisperStatus('base').isDownloaded, isFalse);
    expect(state.gemmaStatus(GemmaCatalog.defaultId).isDownloaded, isTrue);
  });
}

void _registerDownloadTests(_Stage stage) {
  test('${stage.name} download reports progress and succeeds', () async {
    final runtime = _FakeRuntime()..progress[stage] = [0.2, 0.75];
    final settings = _settings(stage, _ids(stage)[2], token: 'test-token');
    final container = await _container(runtime, settings: settings);
    final controller = container.manager;
    final id = _ids(stage).first;
    final observed = <double>[];
    final subscription = container.listen(modelManagerControllerProvider, (
      _,
      next,
    ) {
      observed.add(_status(next, stage, id).progress);
    });
    await _download(controller, stage, id);
    subscription.close();
    expect(observed, containsAllInOrder([0.2, 0.75, 1]));
    expect(container.status(stage, id).isDownloaded, isTrue);
    expect(runtime.downloads[stage], [id]);
    if (stage == _Stage.gemma) expect(runtime.gemmaTokens, ['test-token']);
  });
  test('${stage.name} download rolls state back after an error', () async {
    final runtime = _FakeRuntime()
      ..progress[stage] = [0.3]
      ..failures[stage] = StateError('download failed');
    final container = await _container(runtime);
    final controller = container.manager;
    final id = _ids(stage).first;
    await expectLater(
      _download(controller, stage, id),
      throwsA(isA<StateError>()),
    );
    final status = container.status(stage, id);
    expect((status.status, status.progress), (DownloadStatus.notDownloaded, 0));
  });
}

void _registerLifecycleTests(_Stage stage) {
  test('${stage.name} duplicate download is ignored', () async {
    final blocker = Completer<void>();
    final runtime = _FakeRuntime()..blockers[stage] = blocker;
    final container = await _container(runtime);
    final controller = container.manager;
    final id = _ids(stage).first;
    final first = _download(controller, stage, id);
    await _download(controller, stage, id);
    expect(runtime.downloads[stage], [id]);
    expect(container.status(stage, id).isDownloading, isTrue);
    blocker.complete();
    await first;
    expect(runtime.downloads[stage], [id]);
  });
  test('${stage.name} delete delegates and resets status', () async {
    final id = _ids(stage).first;
    final runtime = _FakeRuntime()..installed[stage]!.add(id);
    final container = await _container(runtime);
    final controller = container.manager;
    await controller.refresh();
    await _delete(controller, stage, id);
    expect(runtime.deletions[stage], [id]);
    expect(container.status(stage, id).status, DownloadStatus.notDownloaded);
  });
}

void _registerSelectionTests(_Stage stage) {
  test('${stage.name} first download becomes the selected model', () async {
    final id = _ids(stage).first;
    final container = await _container(
      _FakeRuntime(),
      settings: _settings(stage, _ids(stage)[1]),
    );
    await _download(container.manager, stage, id);
    expect(_selected(container, stage), id);
  });

  test('${stage.name} download replaces an invalid selection', () async {
    final ids = _ids(stage);
    final container = await _downloadWithExisting(stage, ids, ids[2]);
    expect(_selected(container, stage), ids[0]);
  });

  test('${stage.name} download keeps a valid selection', () async {
    final ids = _ids(stage);
    final container = await _downloadWithExisting(stage, ids, ids[1]);
    expect(_selected(container, stage), ids[1]);
  });
}

Future<ProviderContainer> _downloadWithExisting(
  _Stage stage,
  List<String> ids,
  String selected,
) async {
  final runtime = _FakeRuntime()..installed[stage]!.add(ids[1]);
  final container = await _container(
    runtime,
    settings: _settings(stage, selected),
  );
  await container.manager.refresh();
  await _download(container.manager, stage, ids[0]);
  return container;
}

Future<ProviderContainer> _container(
  _FakeRuntime runtime, {
  AppSettings? settings,
}) async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      localModelRuntimeProvider.overrideWithValue(runtime),
      initialSettingsProvider.overrideWithValue(
        settings ?? AppSettings.initial(),
      ),
      initialConnectionsProvider.overrideWithValue(
        const <RemoteProviderId, bool>{},
      ),
      sharedPreferencesProvider.overrideWithValue(preferences),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

List<String> _ids(_Stage stage) => switch (stage) {
  _Stage.whisper => WhisperCatalog.models.map((model) => model.id).toList(),
  _Stage.gemma => GemmaCatalog.models.map((model) => model.id).toList(),
};

AppSettings _settings(_Stage stage, String id, {String token = ''}) =>
    switch (stage) {
      _Stage.whisper => AppSettings.initial().copyWith(
        whisperModelId: id,
        hfToken: token,
      ),
      _Stage.gemma => AppSettings.initial().copyWith(
        gemmaModelId: id,
        hfToken: token,
      ),
    };

ModelStatus _status(ModelManagerState state, _Stage stage, String id) =>
    switch (stage) {
      _Stage.whisper => state.whisperStatus(id),
      _Stage.gemma => state.gemmaStatus(id),
    };

extension on ProviderContainer {
  ModelManagerController get manager =>
      read(modelManagerControllerProvider.notifier);

  ModelStatus status(_Stage stage, String id) =>
      _status(read(modelManagerControllerProvider), stage, id);
}

String _selected(ProviderContainer container, _Stage stage) {
  final settings = container.read(settingsControllerProvider);
  return switch (stage) {
    _Stage.whisper => settings.whisperModelId,
    _Stage.gemma => settings.gemmaModelId,
  };
}

Future<void> _download(
  ModelManagerController controller,
  _Stage stage,
  String id,
) => switch (stage) {
  _Stage.whisper => controller.downloadWhisper(id),
  _Stage.gemma => controller.downloadGemma(id),
};

Future<void> _delete(
  ModelManagerController controller,
  _Stage stage,
  String id,
) => switch (stage) {
  _Stage.whisper => controller.deleteWhisper(id),
  _Stage.gemma => controller.deleteGemma(id),
};

class _FakeRuntime implements LocalModelRuntime {
  final installed = {for (final stage in _Stage.values) stage: <String>{}};
  final downloads = {for (final stage in _Stage.values) stage: <String>[]};
  final deletions = {for (final stage in _Stage.values) stage: <String>[]};
  final progress = <_Stage, List<double>>{};
  final failures = <_Stage, Object>{};
  final blockers = <_Stage, Completer<void>>{};
  final gemmaTokens = <String?>[];

  Future<void> _download(
    _Stage stage,
    String id,
    ModelDownloadProgress? onProgress,
  ) async {
    downloads[stage]!.add(id);
    for (final value in progress[stage] ?? const <double>[]) {
      onProgress?.call(value);
    }
    final blocker = blockers[stage];
    if (blocker != null) await blocker.future;
    final failure = failures[stage];
    if (failure != null) throw failure;
    installed[stage]!.add(id);
  }

  Future<void> _delete(_Stage stage, String id) async {
    deletions[stage]!.add(id);
    installed[stage]!.remove(id);
  }

  @override
  Future<bool> isWhisperDownloaded(String modelId) =>
      Future.value(installed[_Stage.whisper]!.contains(modelId));

  @override
  Future<void> downloadWhisper(
    String modelId, {
    ModelDownloadProgress? onProgress,
  }) => _download(_Stage.whisper, modelId, onProgress);

  @override
  Future<void> deleteWhisper(String modelId) =>
      _delete(_Stage.whisper, modelId);

  @override
  Future<bool> isGemmaDownloaded(String modelId) =>
      Future.value(installed[_Stage.gemma]!.contains(modelId));

  @override
  Future<void> downloadGemma(
    String modelId, {
    String? hfToken,
    ModelDownloadProgress? onProgress,
  }) {
    gemmaTokens.add(hfToken);
    return _download(_Stage.gemma, modelId, onProgress);
  }

  @override
  Future<void> deleteGemma(String modelId) => _delete(_Stage.gemma, modelId);
}
