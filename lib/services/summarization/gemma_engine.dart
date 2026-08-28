import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import '../../data/catalog/gemma_catalog.dart';
import '../../data/models/gemma_model_spec.dart';
import 'gemma_runtime.dart';
import 'summarization_service.dart';
import 'summary_prompt.dart';
import 'summary_result.dart';

export 'gemma_runtime.dart';

/// The single integration point for the `flutter_gemma` package (v1.x).
///
/// Downloads use the plugin's Hugging Face-aware installer
/// (`FlutterGemma.installModel().fromNetwork(url, token:).withProgress().install()`),
/// which handles gated repos, redirects, retries and the Android foreground
/// service for large files. We additionally drop a small marker file per model
/// so the UI can show per-model "downloaded" state.
class GemmaEngine {
  GemmaEngine._({GemmaRuntime? runtime, GemmaMarkerStore? markerStore})
    : _runtime = runtime ?? const FlutterGemmaRuntime(),
      _markerStore = markerStore ?? const FileGemmaMarkerStore();

  static final GemmaEngine instance = GemmaEngine._();

  @visibleForTesting
  GemmaEngine.test({
    required GemmaRuntime runtime,
    required GemmaMarkerStore markerStore,
  }) : this._(runtime: runtime, markerStore: markerStore);

  final GemmaRuntime _runtime;
  final GemmaMarkerStore _markerStore;

  String? _loadedModelId;
  String? _loadedBackendId;
  GemmaModel? _model;

  PreferredBackend? _backend(String backendId) => switch (backendId) {
    'gpu' => PreferredBackend.gpu,
    'cpu' => PreferredBackend.cpu,
    'npu' => PreferredBackend.npu,
    _ => null,
  };

  ModelType _modelType(String id) => switch (id) {
    'gemma4' => ModelType.gemma4,
    'qwen' => ModelType.qwen,
    'qwen3' => ModelType.qwen3,
    'deepSeek' => ModelType.deepSeek,
    'phi' => ModelType.phi,
    'functionGemma' => ModelType.functionGemma,
    'general' => ModelType.general,
    _ => ModelType.gemmaIt,
  };

  /// flutter_gemma routes `.litertlm` models through the Dart-FFI LiteRT-LM
  /// client and `.task`/`.bin` models through native MediaPipe. The choice is
  /// made *only* by the `fileType` passed at install time (the file extension is
  /// ignored), so we derive it from the download URL here.
  ModelFileType _fileType(GemmaModelSpec spec) =>
      spec.downloadUrl.toLowerCase().endsWith('.litertlm')
      ? ModelFileType.litertlm
      : ModelFileType.task;

  /// True if this model has been installed by us before.
  Future<bool> isDownloaded(GemmaModelSpec spec) async =>
      _markerStore.exists(spec);

  /// Downloads + installs the model via the plugin, reporting progress (0..1).
  Future<void> download(
    GemmaModelSpec spec, {
    String? hfToken,
    void Function(double progress)? onProgress,
  }) async {
    await _install(spec, hfToken, onProgress);
    await _markerStore.create(spec);
  }

  Future<void> deleteDownload(GemmaModelSpec spec) async {
    final isLoaded = _loadedModelId == spec.id;
    if (isLoaded) {
      try {
        await _model?.close();
      } finally {
        _clearLoadedModel();
      }
    }
    if (_runtime.isActiveModel(spec.fileName)) {
      await _runtime.clearActiveInferenceIdentity();
    }
    await _runtime.uninstallModel(spec.fileName);
    await _markerStore.delete(spec);
  }

  void _clearLoadedModel() {
    _loadedModelId = null;
    _loadedBackendId = null;
    _model = null;
  }

  Future<void> _install(
    GemmaModelSpec spec,
    String? hfToken,
    void Function(double progress)? onProgress,
  ) async {
    final token = (spec.needsHfToken && hfToken != null && hfToken.isNotEmpty)
        ? hfToken
        : null;
    await _runtime.install(
      modelType: _modelType(spec.modelTypeId),
      fileType: _fileType(spec),
      url: spec.downloadUrl,
      token: token,
      onProgress: onProgress == null
          ? null
          : (progress) => onProgress(progress / 100),
    );
  }

  /// Ensures [spec] is the active, loaded model on the chosen [backendId]
  /// (installing from cache if needed; reloading if model or backend changed).
  Future<void> _ensureActive(
    GemmaModelSpec spec,
    String? hfToken,
    String backendId,
  ) async {
    if (_loadedModelId == spec.id &&
        _loadedBackendId == backendId &&
        _model != null) {
      return;
    }
    // Re-running install for an already-downloaded model just activates it.
    await _install(spec, hfToken, null);
    _model = await _runtime.getActiveModel(
      maxTokens: spec.maxTokens,
      preferredBackend: _backend(backendId),
      supportAudio: spec.supportsAudio,
    );
    _loadedModelId = spec.id;
    _loadedBackendId = backendId;
  }

  /// Summarizes a transcript into structured output using a fresh chat.
  ///
  /// Uses the high-level chat API: the system prompt is passed natively via
  /// `systemInstruction` (NOT prepended to the user message — for `.litertlm`
  /// FFI models a hand-built prompt makes the model decode straight to
  /// `<end_of_turn>` and return nothing). The response is consumed as a token
  /// stream so the work yields to the event loop between tokens, keeping the UI
  /// responsive. `createChat`/`generateChatResponseAsync` are identical for
  /// `.task` (MediaPipe) and `.litertlm` (FFI) models.
  Future<SummaryResult> summarize(
    GemmaModelSpec spec,
    String transcript, {
    required bool german,
    required String fallbackTitle,
    String? hfToken,
    String backendId = 'auto',
  }) async {
    await _ensureActive(spec, hfToken, backendId);
    final chat = await _model!.createSummaryChat(
      modelType: _modelType(spec.modelTypeId),
      systemInstruction: SummaryPrompt.system(german),
    );
    try {
      await chat.addQuery(
        Message.text(
          text: SummaryPrompt.user(transcript, german: german),
          isUser: true,
        ),
      );
      final buffer = StringBuffer();
      await for (final response in chat.generateChatResponseAsync()) {
        if (response is TextResponse) buffer.write(response.token);
      }
      return SummaryPrompt.parse(
        buffer.toString(),
        fallbackTitle: fallbackTitle,
      );
    } finally {
      await chat.close();
    }
  }
}

/// [SummarizationService] backed by an on-device Gemma model.
class GemmaSummarizationService implements SummarizationService {
  GemmaSummarizationService(
    this.modelId, {
    required this.fallbackTitle,
    this.hfToken,
    this.backendId = 'auto',
    GemmaEngine? engine,
  }) : _engine = engine ?? GemmaEngine.instance;

  final String modelId;
  final String fallbackTitle;
  final String? hfToken;
  final String backendId;
  final GemmaEngine _engine;

  @override
  Future<SummaryResult> summarize(String transcript, {required bool german}) =>
      _engine.summarize(
        GemmaCatalog.byId(modelId),
        transcript,
        german: german,
        fallbackTitle: fallbackTitle,
        hfToken: hfToken,
        backendId: backendId,
      );
}
