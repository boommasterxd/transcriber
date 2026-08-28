import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../data/catalog/gemma_catalog.dart';
import '../../../../data/models/processing_mode.dart';
import '../../../../data/models/remote_provider.dart';
import '../../../../state/model_manager_controller.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/surfaces.dart';
import 'local_stage_model_list.dart';
import 'remote_stage_settings.dart';
import 'settings_switch_row.dart';
import 'stage_mode_toggle.dart';

/// Summary stage: on-device Gemma, or any cloud provider + a live model list.
class SummarySection extends ConsumerWidget {
  const SummarySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(modelManagerControllerProvider);
    final enabled = ref.watch(
      settingsControllerProvider.select(
        (settings) => settings.summarizeEnabled,
      ),
    );
    final settingsController = ref.read(settingsControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryAvailabilityCard(
          enabled: enabled,
          onChanged: settingsController.setSummarizeEnabled,
        ),
        if (enabled) ...[
          const SizedBox(height: 12),
          const _SummaryStageConfiguration(),
        ],
      ],
    );
  }
}

class _SummaryStageConfiguration extends ConsumerWidget {
  const _SummaryStageConfiguration();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final isLocal = ref.watch(
      settingsControllerProvider.select(
        (settings) => settings.summaryMode.isLocal,
      ),
    );
    final controller = ref.read(settingsControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StageModeToggle(
          isLocal: isLocal,
          onChanged: (local) => controller.setSummaryMode(
            local ? ProcessingMode.onDevice : ProcessingMode.cloud,
          ),
          labels: (local: t.modeLocalT, cloud: t.modeRemoteT),
        ),
        const SizedBox(height: 12),
        if (isLocal)
          const _SummaryLocalModels()
        else
          const _SummaryCloudModels(),
      ],
    );
  }
}

class _SummaryLocalModels extends ConsumerWidget {
  const _SummaryLocalModels();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final selectedId = ref.watch(
      settingsControllerProvider.select((settings) => settings.gemmaModelId),
    );
    final status = ref.watch(modelManagerControllerProvider);
    final settingsController = ref.read(settingsControllerProvider.notifier);
    final modelController = ref.read(modelManagerControllerProvider.notifier);
    return LocalStageModelList(
      icon: Icons.auto_awesome_outlined,
      downloadLabel: t.dl,
      options: [
        for (final model in GemmaCatalog.models)
          (
            id: model.id,
            title: model.displayName,
            subtitle:
                '${formatBytes(model.sizeBytes, german: t.isDe)} · ${model.badge.label(t)}',
            status: status.gemmaStatus(model.id),
            selected: selectedId == model.id,
          ),
      ],
      actions: LocalStageModelActions(
        select: settingsController.setGemmaModel,
        download: modelController.downloadGemma,
        delete: modelController.deleteGemma,
      ),
    );
  }
}

class _SummaryCloudModels extends ConsumerWidget {
  const _SummaryCloudModels();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(
      settingsControllerProvider.select((settings) {
        final provider = settings.summaryProvider;
        return (provider: provider, modelId: settings.summaryModelId(provider));
      }),
    );
    final controller = ref.read(settingsControllerProvider.notifier);
    return RemoteStageSettings(
      selection: RemoteStageSelection(
        stage: RemoteStage.summary,
        allowedProviders: RemoteProviderId.values,
        provider: selection.provider,
        modelId: selection.modelId,
      ),
      actions: RemoteStageActions(
        selectProvider: controller.setSummaryProvider,
        selectModel: (id) => controller.setSummaryModel(selection.provider, id),
      ),
    );
  }
}

class _SummaryAvailabilityCard extends ConsumerWidget {
  const _SummaryAvailabilityCard({
    required this.enabled,
    required this.onChanged,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: SettingsSwitchRow(
        icon: (
          data: Icons.auto_awesome_outlined,
          foreground: palette.accent,
          background: palette.accentSoft,
        ),
        content: (
          title: t.summarizeTitle,
          subtitle: t.summarizeSub,
          subtitleHeight: 1.35,
        ),
        value: enabled,
        onChanged: onChanged,
      ),
    );
  }
}
