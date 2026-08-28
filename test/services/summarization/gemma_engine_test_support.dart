import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:transcriber/data/models/gemma_model_spec.dart';
import 'package:transcriber/data/models/model_badge.dart';
import 'package:transcriber/services/summarization/gemma_engine.dart';

GemmaModelSpec testSpec({
  required String id,
  String modelTypeId = 'gemmaIt',
  String extension = 'task',
  int maxTokens = 2048,
  bool supportsAudio = false,
  bool needsHfToken = false,
}) => GemmaModelSpec(
  id: id,
  displayName: id,
  sizeBytes: 1,
  badge: ModelBadge.fast,
  modelTypeId: modelTypeId,
  downloadUrl: 'https://example.test/$id.$extension',
  maxTokens: maxTokens,
  supportsAudio: supportsAudio,
  needsHfToken: needsHfToken,
);

final class MemoryGemmaMarkerStore implements GemmaMarkerStore {
  MemoryGemmaMarkerStore(this.events);

  final List<String> events;
  final Set<String> installedIds = {};
  Object? deleteError;

  @override
  Future<bool> exists(GemmaModelSpec spec) async =>
      installedIds.contains(spec.id);

  @override
  Future<void> create(GemmaModelSpec spec) async {
    events.add('marker.create:${spec.id}');
    installedIds.add(spec.id);
  }

  @override
  Future<void> delete(GemmaModelSpec spec) async {
    events.add('marker.delete:${spec.id}');
    if (deleteError != null) throw deleteError!;
    installedIds.remove(spec.id);
  }
}

final class FakeGemmaRuntime implements GemmaRuntime {
  FakeGemmaRuntime(this.events) : model = FakeInferenceModel(events);

  final List<String> events;
  final FakeInferenceModel model;
  final installCalls = <InstallCall>[];
  final activationCalls = <ActivationCall>[];
  Object? installError;
  Object? clearIdentityError;
  Object? uninstallError;
  String? activeModelFileName;

  @override
  Future<void> install({
    required ModelType modelType,
    required ModelFileType fileType,
    required String url,
    String? token,
    void Function(int progress)? onProgress,
  }) async {
    events.add('runtime.install:$url');
    installCalls.add((
      modelType: modelType,
      fileType: fileType,
      url: url,
      token: token,
    ));
    if (installError != null) throw installError!;
    activeModelFileName = Uri.parse(url).pathSegments.last;
    for (final progress in [0, 25, 100]) {
      onProgress?.call(progress);
    }
  }

  @override
  Future<GemmaModel> getActiveModel({
    required int maxTokens,
    PreferredBackend? preferredBackend,
    required bool supportAudio,
  }) async {
    events.add('runtime.activate');
    activationCalls.add((
      maxTokens: maxTokens,
      backend: preferredBackend,
      supportAudio: supportAudio,
    ));
    model
      ..maxTokensValue = maxTokens
      ..closed = false;
    return model;
  }

  @override
  Future<void> clearActiveInferenceIdentity() async {
    events.add('runtime.clearIdentity');
    if (clearIdentityError != null) throw clearIdentityError!;
    activeModelFileName = null;
  }

  @override
  Future<void> uninstallModel(String fileName) async {
    events.add('runtime.uninstall:$fileName');
    if (uninstallError != null) throw uninstallError!;
  }

  @override
  bool isActiveModel(String fileName) => activeModelFileName == fileName;
}

typedef InstallCall = ({
  ModelType modelType,
  ModelFileType fileType,
  String url,
  String? token,
});

typedef ActivationCall = ({
  int maxTokens,
  PreferredBackend? backend,
  bool supportAudio,
});

final class FakeInferenceModel implements GemmaModel {
  FakeInferenceModel(this.events);

  final List<String> events;
  final queuedSessions = <FakeSession>[];
  int maxTokensValue = 1024;
  String? lastSystemInstruction;
  Object? closeError;
  bool closed = false;

  FakeSession enqueue(List<String> tokens, {Object? error}) {
    final session = FakeSession(tokens, error);
    queuedSessions.add(session);
    return session;
  }

  @override
  Future<InferenceChat> createSummaryChat({
    required ModelType modelType,
    required String systemInstruction,
  }) async {
    lastSystemInstruction = systemInstruction;
    final session = queuedSessions.removeAt(0);
    final chat = InferenceChat(
      sessionCreator: () async => session,
      maxTokens: maxTokensValue,
      modelType: modelType,
      fileType: ModelFileType.task,
      systemInstruction: systemInstruction,
    );
    await chat.initSession();
    return chat;
  }

  @override
  Future<void> close() async {
    events.add('model.close');
    closed = true;
    if (closeError != null) throw closeError!;
  }
}

final class FakeSession implements InferenceModelSession {
  FakeSession(this.tokens, this.error);

  final List<String> tokens;
  final Object? error;
  final queries = <Message>[];
  bool closed = false;

  @override
  Future<void> addQueryChunk(Message message) async => queries.add(message);

  @override
  Stream<String> getResponseAsync() async* {
    yield* Stream.fromIterable(tokens);
    if (error != null) throw error!;
  }

  @override
  Future<int> sizeInTokens(String text) async => text.length;

  @override
  Future<void> close() async => closed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
