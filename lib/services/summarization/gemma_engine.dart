import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart';

import '../../data/catalog/gemma_catalog.dart';
import '../../data/models/gemma_model_spec.dart';
import '../download/file_downloader.dart';
import '../storage/storage_paths.dart';
import 'summarization_service.dart';
import 'summary_prompt.dart';
import 'summary_result.dart';

/// The single integration point for the `flutter_gemma` package. Confines all
/// package types here so version differences are contained to one file.
///
/// Models are downloaded by [FileDownloader] (so gated Hugging Face artifacts
/// work with a token), then handed to flutter_gemma via `setModelPath`, which is
/// a long-stable part of its API.
class GemmaEngine {
  GemmaEngine._();
  static final GemmaEngine instance = GemmaEngine._();

  final FileDownloader _downloader = const FileDownloader();

  String? _loadedModelId;
  dynamic _inferenceModel; // InferenceModel
  dynamic _chat;

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
      case 'gemmaIt':
      default:
        return ModelType.gemmaIt;
    }
  }

  Future<String> _modelFilePath(GemmaModelSpec spec) async =>
      (await StoragePaths.instance()).gemmaModelFile(spec.fileName);

  /// True if the model artifact is present on disk.
  Future<bool> isDownloaded(GemmaModelSpec spec) async =>
      File(await _modelFilePath(spec)).exists();

  /// Downloads the model artifact with progress (0..1).
  Future<void> download(
    GemmaModelSpec spec, {
    String? hfToken,
    void Function(double progress)? onProgress,
  }) async {
    final path = await _modelFilePath(spec);
    await _downloader.download(
      spec.downloadUrl,
      path,
      bearerToken: spec.needsHfToken ? hfToken : null,
      onProgress: onProgress,
    );
  }

  Future<void> deleteDownload(GemmaModelSpec spec) async {
    final file = File(await _modelFilePath(spec));
    if (await file.exists()) await file.delete();
    if (_loadedModelId == spec.id) await _unload();
  }

  Future<void> _unload() async {
    try {
      await _chat?.close?.call();
    } catch (_) {}
    try {
      await _inferenceModel?.close?.call();
    } catch (_) {}
    _chat = null;
    _inferenceModel = null;
    _loadedModelId = null;
  }

  /// Ensures the given model is downloaded and loaded into flutter_gemma.
  Future<void> _ensureLoaded(GemmaModelSpec spec) async {
    if (_loadedModelId == spec.id && _inferenceModel != null) return;
    await _unload();

    final path = await _modelFilePath(spec);
    if (!await File(path).exists()) {
      throw StateError('Gemma model not downloaded: ${spec.id}');
    }

    final gemma = FlutterGemmaPlugin.instance;
    await gemma.modelManager.setModelPath(path);
    _inferenceModel = await gemma.createModel(
      modelType: _modelType(spec.modelTypeId),
      maxTokens: spec.maxTokens,
      preferredBackend: PreferredBackend.gpu,
    );
    _loadedModelId = spec.id;
  }

  /// Generates a chat completion for [prompt] using the loaded model.
  Future<String> _generate(GemmaModelSpec spec, String systemPrompt, String prompt) async {
    await _ensureLoaded(spec);
    final chat = await _inferenceModel.createChat();
    await chat.addQueryChunk(Message.text(text: '$systemPrompt\n\n$prompt', isUser: true));
    final dynamic response = await chat.generateChatResponse();
    return _asText(response);
  }

  String _asText(dynamic response) {
    if (response is String) return response;
    try {
      final dynamic token = response.token;
      if (token is String) return token;
    } catch (_) {}
    try {
      final dynamic text = response.text;
      if (text is String) return text;
    } catch (_) {}
    return response?.toString() ?? '';
  }

  /// Summarizes a transcript into structured output.
  Future<SummaryResult> summarize(
    GemmaModelSpec spec,
    String transcript, {
    required bool german,
    required String fallbackTitle,
  }) async {
    final raw = await _generate(
      spec,
      SummaryPrompt.system(german),
      SummaryPrompt.user(transcript, german: german),
    );
    return SummaryPrompt.parse(raw, fallbackTitle: fallbackTitle);
  }
}

/// [SummarizationService] backed by an on-device Gemma model.
class GemmaSummarizationService implements SummarizationService {
  GemmaSummarizationService(this.modelId, {required this.fallbackTitle});

  final String modelId;
  final String fallbackTitle;

  @override
  Future<SummaryResult> summarize(String transcript, {required bool german}) =>
      GemmaEngine.instance.summarize(
        GemmaCatalog.byId(modelId),
        transcript,
        german: german,
        fallbackTitle: fallbackTitle,
      );
}
