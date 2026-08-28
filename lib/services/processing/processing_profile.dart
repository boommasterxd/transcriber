import '../../data/catalog/remote_catalog.dart';
import '../../data/models/app_settings.dart';

/// Resolved display information for one cloud processing stage.
final class StageInfo {
  const StageInfo({required this.name, required this.providerName});

  final String name;
  final String providerName;

  String get sub => providerName;
}

/// Provider and model labels for the independently configured cloud stages.
final class ProcessingProfile {
  const ProcessingProfile({required this.asr, required this.summary});

  final StageInfo asr;
  final StageInfo summary;

  String get combinedLabel => '${asr.name} · ${summary.name}';

  factory ProcessingProfile.resolve(AppSettings settings) => ProcessingProfile(
    asr: StageInfo(
      name: settings.asrModelId(settings.asrProvider),
      providerName: RemoteCatalog.provider(settings.asrProvider).name,
    ),
    summary: StageInfo(
      name: settings.summaryModelId(settings.summaryProvider),
      providerName: RemoteCatalog.provider(settings.summaryProvider).name,
    ),
  );
}
