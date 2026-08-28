import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatting.dart';
import '../../../../data/catalog/remote_catalog.dart';
import '../../../../data/catalog/whisper_catalog.dart';
import '../../../../data/models/processing_mode.dart';
import '../../../../state/model_manager_controller.dart';
import '../../../../state/settings_controller.dart';
import 'local_stage_model_list.dart';
import 'remote_stage_settings.dart';
import 'stage_mode_toggle.dart';

/// Transcription stage: on-device Whisper, or a cloud ASR provider (OpenAI /
/// Google) with a live transcription-model list.
class TranscriptionSection extends ConsumerWidget {
  const TranscriptionSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(modelManagerControllerProvider);
    final t = ref.watch(stringsProvider);
    final isLocal = ref.watch(
      settingsControllerProvider.select((settings) => settings.asrMode.isLocal),
    );
    final controller = ref.read(settingsControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StageModeToggle(
          isLocal: isLocal,
          onChanged: (local) => controller.setAsrMode(
            local ? ProcessingMode.onDevice : ProcessingMode.cloud,
          ),
          labels: (local: t.modeLocalT, cloud: t.modeRemoteT),
        ),
        const SizedBox(height: 12),
        if (isLocal)
          const _TranscriptionLocalModels()
        else
          const _TranscriptionCloudModels(),
      ],
    );
  }
}

class _TranscriptionLocalModels extends ConsumerWidget {
  const _TranscriptionLocalModels();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final selectedId = ref.watch(
      settingsControllerProvider.select((settings) => settings.whisperModelId),
    );
    final status = ref.watch(modelManagerControllerProvider);
    final settingsController = ref.read(settingsControllerProvider.notifier);
    final modelController = ref.read(modelManagerControllerProvider.notifier);
    return LocalStageModelList(
      icon: Icons.graphic_eq_rounded,
      downloadLabel: t.dl,
      options: [
        for (final model in WhisperCatalog.models)
          (
            id: model.id,
            title: model.displayName,
            subtitle:
                '${formatBytes(model.sizeBytes, german: t.isDe)} · ${model.badge.label(t)}',
            status: status.whisperStatus(model.id),
            selected: selectedId == model.id,
          ),
      ],
      actions: LocalStageModelActions(
        select: settingsController.setWhisperModel,
        download: modelController.downloadWhisper,
        delete: modelController.deleteWhisper,
      ),
    );
  }
}

class _TranscriptionCloudModels extends ConsumerWidget {
  const _TranscriptionCloudModels();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(
      settingsControllerProvider.select((settings) {
        final provider = settings.asrProvider;
        return (provider: provider, modelId: settings.asrModelId(provider));
      }),
    );
    final controller = ref.read(settingsControllerProvider.notifier);
    return RemoteStageSettings(
      selection: RemoteStageSelection(
        stage: RemoteStage.transcription,
        allowedProviders: RemoteCatalog.asrProviders,
        provider: selection.provider,
        modelId: selection.modelId,
      ),
      actions: RemoteStageActions(
        selectProvider: controller.setAsrProvider,
        selectModel: (id) => controller.setAsrModel(selection.provider, id),
      ),
    );
  }
}
