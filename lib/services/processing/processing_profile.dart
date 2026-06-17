import '../../core/l10n/app_strings.dart';
import '../../core/utils/formatting.dart';
import '../../data/catalog/gemma_catalog.dart';
import '../../data/catalog/remote_catalog.dart';
import '../../data/catalog/whisper_catalog.dart';
import '../../data/models/app_settings.dart';

/// Resolved label/flags for a single processing stage (transcription or summary).
class StageInfo {
  const StageInfo({required this.name, required this.sub, required this.isLocal});

  final String name;
  final String sub;
  final bool isLocal;

  /// Compact "Name" used in the history list (drops size/provider).
  String get shortName => name;
}

/// Resolves the active transcription + summary stages from [AppSettings] into
/// display labels. Single source of truth shared by the pipeline (for note
/// metadata) and the UI (home pill, processing screen).
class ProcessingProfile {
  const ProcessingProfile({required this.asr, required this.summary});

  final StageInfo asr;
  final StageInfo summary;

  bool get isFullyLocal => asr.isLocal && summary.isLocal;

  /// "Whisper Base · Claude Sonnet 4.5" style summary for the home pill.
  String get combinedLabel => '${asr.name} · ${summary.shortName}';

  factory ProcessingProfile.resolve(AppSettings s) {
    final german = s.language == AppLanguage.de;

    final StageInfo asr;
    if (s.asrMode.isLocal) {
      final m = WhisperCatalog.byId(s.whisperModelId);
      asr = StageInfo(name: m.displayName, sub: formatBytes(m.sizeBytes, german: german), isLocal: true);
    } else {
      final provider = RemoteCatalog.provider(s.asrProvider);
      asr = StageInfo(name: s.asrModelId(s.asrProvider), sub: provider.name, isLocal: false);
    }

    final StageInfo summary;
    if (s.summaryMode.isLocal) {
      final m = GemmaCatalog.byId(s.gemmaModelId);
      summary = StageInfo(name: m.displayName, sub: formatBytes(m.sizeBytes, german: german), isLocal: true);
    } else {
      final provider = RemoteCatalog.provider(s.summaryProvider);
      summary = StageInfo(name: s.summaryModelId(s.summaryProvider), sub: provider.name, isLocal: false);
    }

    return ProcessingProfile(asr: asr, summary: summary);
  }
}
