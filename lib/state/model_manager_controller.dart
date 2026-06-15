import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog/gemma_catalog.dart';
import '../data/catalog/whisper_catalog.dart';
import '../services/summarization/gemma_engine.dart';
import '../services/transcription/whisper_engine.dart';
import 'providers.dart';
import 'settings_controller.dart';

enum DownloadStatus { notDownloaded, downloading, downloaded }

class ModelStatus {
  const ModelStatus({this.status = DownloadStatus.notDownloaded, this.progress = 0});
  final DownloadStatus status;
  final double progress;

  bool get isDownloaded => status == DownloadStatus.downloaded;
  bool get isDownloading => status == DownloadStatus.downloading;

  ModelStatus copyWith({DownloadStatus? status, double? progress}) =>
      ModelStatus(status: status ?? this.status, progress: progress ?? this.progress);
}

class ModelManagerState {
  const ModelManagerState({this.whisper = const {}, this.gemma = const {}});
  final Map<String, ModelStatus> whisper;
  final Map<String, ModelStatus> gemma;

  ModelStatus whisperStatus(String id) => whisper[id] ?? const ModelStatus();
  ModelStatus gemmaStatus(String id) => gemma[id] ?? const ModelStatus();

  ModelManagerState copyWith({
    Map<String, ModelStatus>? whisper,
    Map<String, ModelStatus>? gemma,
  }) =>
      ModelManagerState(whisper: whisper ?? this.whisper, gemma: gemma ?? this.gemma);
}

/// Manages downloading / removing on-device models and exposes their status.
class ModelManagerController extends Notifier<ModelManagerState> {
  @override
  ModelManagerState build() {
    final installed = ref.read(modelInstallRepositoryProvider).downloadedWhisperIds();
    final whisper = {
      for (final m in WhisperCatalog.models)
        m.id: ModelStatus(
          status: installed.contains(m.id) ? DownloadStatus.downloaded : DownloadStatus.notDownloaded,
        ),
    };
    final gemma = {for (final m in GemmaCatalog.models) m.id: const ModelStatus()};
    // Kick off an async reconciliation against the filesystem.
    Future.microtask(refresh);
    return ModelManagerState(whisper: whisper, gemma: gemma);
  }

  Future<void> refresh() async {
    final gemma = <String, ModelStatus>{};
    for (final spec in GemmaCatalog.models) {
      final exists = await GemmaEngine.instance.isDownloaded(spec);
      final current = state.gemmaStatus(spec.id);
      gemma[spec.id] = current.isDownloading
          ? current
          : ModelStatus(
              status: exists ? DownloadStatus.downloaded : DownloadStatus.notDownloaded,
            );
    }
    state = state.copyWith(gemma: gemma);
  }

  void _setWhisper(String id, ModelStatus status) =>
      state = state.copyWith(whisper: {...state.whisper, id: status});

  void _setGemma(String id, ModelStatus status) =>
      state = state.copyWith(gemma: {...state.gemma, id: status});

  Future<void> downloadWhisper(String id) async {
    if (state.whisperStatus(id).isDownloading) return;
    _setWhisper(id, const ModelStatus(status: DownloadStatus.downloading));
    try {
      await WhisperEngine.instance.download(
        id,
        onProgress: (p) => _setWhisper(id, ModelStatus(status: DownloadStatus.downloading, progress: p)),
      );
      await ref.read(modelInstallRepositoryProvider).markWhisper(id);
      _setWhisper(id, const ModelStatus(status: DownloadStatus.downloaded, progress: 1));
    } catch (_) {
      _setWhisper(id, const ModelStatus(status: DownloadStatus.notDownloaded));
      rethrow;
    }
  }

  Future<void> deleteWhisper(String id) async {
    await ref.read(modelInstallRepositoryProvider).unmarkWhisper(id);
    _setWhisper(id, const ModelStatus(status: DownloadStatus.notDownloaded));
  }

  Future<void> downloadGemma(String id) async {
    if (state.gemmaStatus(id).isDownloading) return;
    final spec = GemmaCatalog.byId(id);
    final hfToken = ref.read(settingsControllerProvider).hfToken;
    _setGemma(id, const ModelStatus(status: DownloadStatus.downloading));
    try {
      await GemmaEngine.instance.download(
        spec,
        hfToken: hfToken,
        onProgress: (p) => _setGemma(id, ModelStatus(status: DownloadStatus.downloading, progress: p)),
      );
      _setGemma(id, const ModelStatus(status: DownloadStatus.downloaded, progress: 1));
    } catch (_) {
      _setGemma(id, const ModelStatus(status: DownloadStatus.notDownloaded));
      rethrow;
    }
  }

  Future<void> deleteGemma(String id) async {
    await GemmaEngine.instance.deleteDownload(GemmaCatalog.byId(id));
    _setGemma(id, const ModelStatus(status: DownloadStatus.notDownloaded));
  }
}

final modelManagerControllerProvider =
    NotifierProvider<ModelManagerController, ModelManagerState>(ModelManagerController.new);
