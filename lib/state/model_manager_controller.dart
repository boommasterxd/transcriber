import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/toast.dart';
import '../data/catalog/gemma_catalog.dart';
import '../data/catalog/whisper_catalog.dart';
import '../services/models/local_model_runtime.dart';
import 'providers.dart';
import 'settings_controller.dart';

enum DownloadStatus { notDownloaded, downloading, downloaded }

class ModelStatus {
  const ModelStatus({
    this.status = DownloadStatus.notDownloaded,
    this.progress = 0,
  });
  final DownloadStatus status;
  final double progress;

  bool get isDownloaded => status == DownloadStatus.downloaded;
  bool get isDownloading => status == DownloadStatus.downloading;

  ModelStatus copyWith({DownloadStatus? status, double? progress}) =>
      ModelStatus(
        status: status ?? this.status,
        progress: progress ?? this.progress,
      );
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
  }) => ModelManagerState(
    whisper: whisper ?? this.whisper,
    gemma: gemma ?? this.gemma,
  );
}

/// Manages downloading / removing on-device models and exposes their status.
class ModelManagerController extends Notifier<ModelManagerState> {
  LocalModelRuntime get _runtime => ref.read(localModelRuntimeProvider);

  @override
  ModelManagerState build() {
    final whisper = {
      for (final m in WhisperCatalog.models) m.id: const ModelStatus(),
    };
    final gemma = {
      for (final m in GemmaCatalog.models) m.id: const ModelStatus(),
    };
    // Reconcile against the filesystem asynchronously.
    Future.microtask(refresh);
    return ModelManagerState(whisper: whisper, gemma: gemma);
  }

  Future<void> refresh() async {
    final whisper = <String, ModelStatus>{};
    for (final spec in WhisperCatalog.models) {
      final current = state.whisperStatus(spec.id);
      if (current.isDownloading) {
        whisper[spec.id] = current;
        continue;
      }
      final exists = await _runtime.isWhisperDownloaded(spec.id);
      if (!ref.mounted) return;
      final latest = state.whisperStatus(spec.id);
      if (latest.isDownloading) {
        whisper[spec.id] = latest;
        continue;
      }
      whisper[spec.id] = ModelStatus(
        status: exists
            ? DownloadStatus.downloaded
            : DownloadStatus.notDownloaded,
      );
    }

    final gemma = <String, ModelStatus>{};
    for (final spec in GemmaCatalog.models) {
      final current = state.gemmaStatus(spec.id);
      if (current.isDownloading) {
        gemma[spec.id] = current;
        continue;
      }
      final exists = await _runtime.isGemmaDownloaded(spec.id);
      if (!ref.mounted) return;
      final latest = state.gemmaStatus(spec.id);
      if (latest.isDownloading) {
        gemma[spec.id] = latest;
        continue;
      }
      gemma[spec.id] = ModelStatus(
        status: exists
            ? DownloadStatus.downloaded
            : DownloadStatus.notDownloaded,
      );
    }

    state = state.copyWith(whisper: whisper, gemma: gemma);
  }

  void _setWhisper(String id, ModelStatus status) =>
      state = state.copyWith(whisper: {...state.whisper, id: status});

  void _setGemma(String id, ModelStatus status) =>
      state = state.copyWith(gemma: {...state.gemma, id: status});

  Future<void> downloadWhisper(String id) async {
    if (state.whisperStatus(id).isDownloading) return;
    _setWhisper(id, const ModelStatus(status: DownloadStatus.downloading));
    try {
      await _runtime.downloadWhisper(
        id,
        onProgress: (p) => _setWhisper(
          id,
          ModelStatus(status: DownloadStatus.downloading, progress: p),
        ),
      );
      _setWhisper(
        id,
        const ModelStatus(status: DownloadStatus.downloaded, progress: 1),
      );
      _autoSelectWhisper(id);
      _toast(WhisperCatalog.byId(id).displayName, downloaded: true);
    } catch (_) {
      _setWhisper(id, const ModelStatus(status: DownloadStatus.notDownloaded));
      rethrow;
    }
  }

  /// Selects [id] when it's the only downloaded ASR model, or when the current
  /// selection isn't downloaded — so a freshly downloaded model is used.
  void _autoSelectWhisper(String id) {
    final downloaded = WhisperCatalog.models.where(
      (m) => state.whisperStatus(m.id).isDownloaded,
    );
    final current = ref.read(settingsControllerProvider).whisperModelId;
    if (downloaded.length == 1 || !downloaded.any((m) => m.id == current)) {
      ref.read(settingsControllerProvider.notifier).setWhisperModel(id);
    }
  }

  Future<void> deleteWhisper(String id) async {
    await _runtime.deleteWhisper(id);
    _setWhisper(id, const ModelStatus(status: DownloadStatus.notDownloaded));
    _toast(WhisperCatalog.byId(id).displayName, downloaded: false);
  }

  void _toast(String name, {required bool downloaded}) {
    final t = ref.read(stringsProvider);
    showAppToast('$name ${downloaded ? t.toastDownloaded : t.toastRemoved}');
  }

  Future<void> downloadGemma(String id) async {
    if (state.gemmaStatus(id).isDownloading) return;
    final hfToken = ref.read(settingsControllerProvider).hfToken;
    _setGemma(id, const ModelStatus(status: DownloadStatus.downloading));
    try {
      await _runtime.downloadGemma(
        id,
        hfToken: hfToken,
        onProgress: (p) => _setGemma(
          id,
          ModelStatus(status: DownloadStatus.downloading, progress: p),
        ),
      );
      _setGemma(
        id,
        const ModelStatus(status: DownloadStatus.downloaded, progress: 1),
      );
      _autoSelectGemma(id);
      _toast(GemmaCatalog.byId(id).displayName, downloaded: true);
    } catch (_) {
      _setGemma(id, const ModelStatus(status: DownloadStatus.notDownloaded));
      rethrow;
    }
  }

  void _autoSelectGemma(String id) {
    final downloaded = GemmaCatalog.models.where(
      (m) => state.gemmaStatus(m.id).isDownloaded,
    );
    final current = ref.read(settingsControllerProvider).gemmaModelId;
    if (downloaded.length == 1 || !downloaded.any((m) => m.id == current)) {
      ref.read(settingsControllerProvider.notifier).setGemmaModel(id);
    }
  }

  Future<void> deleteGemma(String id) async {
    await _runtime.deleteGemma(id);
    _setGemma(id, const ModelStatus(status: DownloadStatus.notDownloaded));
    _toast(GemmaCatalog.byId(id).displayName, downloaded: false);
  }
}

final modelManagerControllerProvider =
    NotifierProvider<ModelManagerController, ModelManagerState>(
      ModelManagerController.new,
    );
