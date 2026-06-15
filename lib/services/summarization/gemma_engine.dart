import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path/path.dart' as p;

import '../../data/catalog/gemma_catalog.dart';
import '../../data/models/gemma_model_spec.dart';
import '../storage/storage_paths.dart';
import 'summarization_service.dart';
import 'summary_prompt.dart';
import 'summary_result.dart';

/// The single integration point for the `flutter_gemma` package (v0.16.x).
///
/// Downloads use the plugin's Hugging Face-aware installer
/// (`FlutterGemma.installModel().fromNetwork(url, token:).withProgress().install()`),
/// which handles gated repos, redirects, retries and the Android foreground
/// service for large files. We additionally drop a small marker file per model
/// so the UI can show per-model "downloaded" state.
class GemmaEngine {
  GemmaEngine._();
  static final GemmaEngine instance = GemmaEngine._();

  String? _loadedModelId;
  InferenceModel? _model;

  ModelType _modelType(String id) {
    switch (id) {
      case 'gemma4':
        return ModelType.gemma4;
      case 'qwen':
        return ModelType.qwen;
      case 'qwen3':
        return ModelType.qwen3;
      case 'deepSeek':
        return ModelType.deepSeek;
      case 'phi':
        return ModelType.phi;
      case 'functionGemma':
        return ModelType.functionGemma;
      case 'general':
        return ModelType.general;
      case 'gemmaIt':
      default:
        return ModelType.gemmaIt;
    }
  }

  Future<File> _marker(GemmaModelSpec spec) async {
    final dir = await (await StoragePaths.instance()).gemmaDir();
    return File(p.join(dir.path, '${spec.id}.installed'));
  }

  /// True if this model has been installed by us before.
  Future<bool> isDownloaded(GemmaModelSpec spec) async => (await _marker(spec)).exists();

  /// Downloads + installs the model via the plugin, reporting progress (0..1).
  Future<void> download(
    GemmaModelSpec spec, {
    String? hfToken,
    void Function(double progress)? onProgress,
  }) async {
    await _install(spec, hfToken, onProgress);
    await (await _marker(spec)).create(recursive: true);
  }

  Future<void> deleteDownload(GemmaModelSpec spec) async {
    final marker = await _marker(spec);
    if (await marker.exists()) await marker.delete();
    if (_loadedModelId == spec.id) {
      _loadedModelId = null;
      _model = null;
    }
  }

  Future<void> _install(
    GemmaModelSpec spec,
    String? hfToken,
    void Function(double progress)? onProgress,
  ) async {
    final token = (spec.needsHfToken && hfToken != null && hfToken.isNotEmpty) ? hfToken : null;
    var builder = FlutterGemma.installModel(modelType: _modelType(spec.modelTypeId))
        .fromNetwork(spec.downloadUrl, token: token);
    if (onProgress != null) {
      builder = builder.withProgress((progress) => onProgress(progress / 100));
    }
    await builder.install();
  }

  /// Ensures [spec] is the active, loaded model (installing from cache if needed).
  Future<void> _ensureActive(GemmaModelSpec spec, String? hfToken) async {
    if (_loadedModelId == spec.id && _model != null) return;
    // Re-running install for an already-downloaded model just activates it.
    await _install(spec, hfToken, null);
    _model = await FlutterGemma.getActiveModel(
      maxTokens: spec.maxTokens,
      preferredBackend: PreferredBackend.gpu,
      supportAudio: spec.supportsAudio,
    );
    _loadedModelId = spec.id;
  }

  String _responseText(ModelResponse response) =>
      response is TextResponse ? response.token : '';

  /// Summarizes a transcript into structured output.
  Future<SummaryResult> summarize(
    GemmaModelSpec spec,
    String transcript, {
    required bool german,
    required String fallbackTitle,
    String? hfToken,
  }) async {
    await _ensureActive(spec, hfToken);
    final chat = await FlutterGemmaPlugin.instance.createChat(modelType: _modelType(spec.modelTypeId));
    await chat.addQueryChunk(
      Message.text(
        text: '${SummaryPrompt.system(german)}\n\n${SummaryPrompt.user(transcript, german: german)}',
        isUser: true,
      ),
    );

    final buffer = StringBuffer();
    await for (final response in chat.generateChatResponseAsync()) {
      buffer.write(_responseText(response));
    }
    return SummaryPrompt.parse(buffer.toString(), fallbackTitle: fallbackTitle);
  }
}

/// [SummarizationService] backed by an on-device Gemma model.
class GemmaSummarizationService implements SummarizationService {
  GemmaSummarizationService(this.modelId, {required this.fallbackTitle, this.hfToken});

  final String modelId;
  final String fallbackTitle;
  final String? hfToken;

  @override
  Future<SummaryResult> summarize(String transcript, {required bool german}) =>
      GemmaEngine.instance.summarize(
        GemmaCatalog.byId(modelId),
        transcript,
        german: german,
        fallbackTitle: fallbackTitle,
        hfToken: hfToken,
      );
}
