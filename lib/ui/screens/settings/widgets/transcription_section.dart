import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../data/catalog/remote_catalog.dart';
import '../../../../data/catalog/whisper_catalog.dart';
import '../../../../data/models/processing_mode.dart';
import '../../../../state/model_manager_controller.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/surfaces.dart';
import 'downloadable_model_tile.dart';
import 'provider_connect_card.dart';
import 'provider_picker.dart';
import 'remote_model_list.dart';
import 'stage_explainer.dart';
import 'stage_mode_toggle.dart';

/// Transcription stage: on-device Whisper, or a cloud ASR provider (OpenAI /
/// Google) with a live transcription-model list.
class TranscriptionSection extends ConsumerWidget {
  const TranscriptionSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final settings = ref.watch(settingsControllerProvider);
    final manager = ref.watch(modelManagerControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);
    final managerCtrl = ref.read(modelManagerControllerProvider.notifier);
    final isLocal = settings.asrMode.isLocal;
    final provider = settings.asrProvider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StageExplainer(text: t.asrExplain),
        const SizedBox(height: 12),
        StageModeToggle(
          isLocal: isLocal,
          onChanged: (local) =>
              ctrl.setAsrMode(local ? ProcessingMode.onDevice : ProcessingMode.cloud),
          localLabel: t.modeLocalT,
          cloudLabel: t.modeRemoteT,
        ),
        const SizedBox(height: 12),
        if (isLocal)
          SurfaceCard(
            clip: true,
            child: Column(
              children: [
                for (final (i, m) in WhisperCatalog.models.indexed)
                  DownloadableModelTile(
                    icon: Icons.graphic_eq_rounded,
                    title: m.displayName,
                    subtitle:
                        '${formatBytes(m.sizeBytes, german: t.language == AppLanguage.de)} · ${m.badge.label(t.language)}',
                    downloadLabel: t.dl,
                    status: manager.whisperStatus(m.id),
                    selected: settings.whisperModelId == m.id,
                    isLast: i == WhisperCatalog.models.length - 1,
                    onSelect: () => ctrl.setWhisperModel(m.id),
                    onDownload: () => managerCtrl.downloadWhisper(m.id),
                    onDelete: () => managerCtrl.deleteWhisper(m.id),
                  ),
              ],
            ),
          )
        else ...[
          ProviderPicker(
            allowed: RemoteCatalog.asrProviders,
            selected: provider,
            onSelect: ctrl.setAsrProvider,
          ),
          const SizedBox(height: 12),
          ProviderConnectCard(provider: provider),
          const SizedBox(height: 12),
          SectionLabel(t.remoteModel, padding: const EdgeInsets.fromLTRB(6, 4, 6, 9)),
          RemoteModelList(
            provider: provider,
            forTranscription: true,
            selectedId: settings.asrModelId(provider),
            onSelect: (id) => ctrl.setAsrModel(provider, id),
          ),
        ],
      ],
    );
  }
}
