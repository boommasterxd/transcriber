import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path/path.dart' as p;

import '../../data/models/gemma_model_spec.dart';
import '../storage/storage_paths.dart';

/// Runtime boundary for Gemma model installation, activation, and removal.
abstract interface class GemmaRuntime {
  Future<void> install({
    required ModelType modelType,
    required ModelFileType fileType,
    required String url,
    String? token,
    void Function(int progress)? onProgress,
  });

  Future<GemmaModel> getActiveModel({
    required int maxTokens,
    PreferredBackend? preferredBackend,
    required bool supportAudio,
  });

  Future<void> clearActiveInferenceIdentity();

  Future<void> uninstallModel(String fileName);

  bool isActiveModel(String fileName);
}

/// Loaded model operations needed by the summarization engine.
abstract interface class GemmaModel {
  Future<InferenceChat> createSummaryChat({
    required ModelType modelType,
    required String systemInstruction,
  });

  Future<void> close();
}

/// Storage boundary for the per-model installation markers used by the UI.
abstract interface class GemmaMarkerStore {
  Future<bool> exists(GemmaModelSpec spec);

  Future<void> create(GemmaModelSpec spec);

  Future<void> delete(GemmaModelSpec spec);
}

/// Production adapter for the `flutter_gemma` plugin.
final class FlutterGemmaRuntime implements GemmaRuntime {
  const FlutterGemmaRuntime();

  @override
  Future<void> install({
    required ModelType modelType,
    required ModelFileType fileType,
    required String url,
    String? token,
    void Function(int progress)? onProgress,
  }) async {
    var builder = FlutterGemma.installModel(
      modelType: modelType,
      fileType: fileType,
    ).fromNetwork(url, token: token);
    if (onProgress != null) {
      builder = builder.withProgress(onProgress);
    }
    await builder.install();
  }

  @override
  Future<GemmaModel> getActiveModel({
    required int maxTokens,
    PreferredBackend? preferredBackend,
    required bool supportAudio,
  }) async => FlutterGemmaModel(
    await FlutterGemma.getActiveModel(
      maxTokens: maxTokens,
      preferredBackend: preferredBackend,
      supportAudio: supportAudio,
    ),
  );

  @override
  Future<void> clearActiveInferenceIdentity() =>
      FlutterGemma.clearActiveInferenceIdentity();

  @override
  Future<void> uninstallModel(String fileName) =>
      FlutterGemma.uninstallModel(fileName);

  @override
  bool isActiveModel(String fileName) =>
      FlutterGemma.activeModelSpec?.files.first.filename == fileName;
}

/// Production adapter for a loaded Gemma inference model.
final class FlutterGemmaModel implements GemmaModel {
  const FlutterGemmaModel(this._model);

  final InferenceModel _model;

  @override
  Future<InferenceChat> createSummaryChat({
    required ModelType modelType,
    required String systemInstruction,
  }) => _model.createChat(
    modelType: modelType,
    systemInstruction: systemInstruction,
    topK: 1,
  );

  @override
  Future<void> close() => _model.close();
}

/// Production marker storage below the app support directory.
final class FileGemmaMarkerStore implements GemmaMarkerStore {
  const FileGemmaMarkerStore();

  Future<File> _marker(GemmaModelSpec spec) async {
    final dir = await (await StoragePaths.instance()).gemmaDir();
    return File(p.join(dir.path, '${spec.id}.installed'));
  }

  @override
  Future<bool> exists(GemmaModelSpec spec) async =>
      (await _marker(spec)).exists();

  @override
  Future<void> create(GemmaModelSpec spec) async {
    await (await _marker(spec)).create(recursive: true);
  }

  @override
  Future<void> delete(GemmaModelSpec spec) async {
    final marker = await _marker(spec);
    if (await marker.exists()) {
      await marker.delete();
    }
  }
}
