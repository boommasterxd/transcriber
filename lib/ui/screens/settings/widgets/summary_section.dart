import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../data/catalog/gemma_catalog.dart';
import '../../../../data/models/processing_mode.dart';
import '../../../../data/models/remote_provider.dart';
import '../../../../state/model_manager_controller.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/surfaces.dart';
import 'downloadable_model_tile.dart';
import 'provider_connect_card.dart';
import 'provider_picker.dart';
import 'remote_model_list.dart';
import 'stage_explainer.dart';
import 'stage_mode_toggle.dart';

/// Summary stage: on-device Gemma, or any cloud provider + a live model list.
class SummarySection extends ConsumerWidget {
  const SummarySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final settings = ref.watch(settingsControllerProvider);
    final manager = ref.watch(modelManagerControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);
    final managerCtrl = ref.read(modelManagerControllerProvider.notifier);
    final isLocal = settings.summaryMode.isLocal;
    final provider = settings.summaryProvider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StageExplainer(text: t.summaryExplain),
        const SizedBox(height: 12),
        StageModeToggle(
          isLocal: isLocal,
          onChanged: (local) =>
              ctrl.setSummaryMode(local ? ProcessingMode.onDevice : ProcessingMode.cloud),
          localLabel: t.modeLocalT,
          cloudLabel: t.modeRemoteT,
        ),
        const SizedBox(height: 12),
        if (isLocal) ...[
          SurfaceCard(
            clip: true,
            child: Column(
              children: [
                for (final (i, m) in GemmaCatalog.models.indexed)
                  DownloadableModelTile(
                    icon: Icons.auto_awesome_outlined,
                    title: m.displayName,
                    subtitle:
                        '${formatBytes(m.sizeBytes, german: t.language == AppLanguage.de)} · ${m.badge.label(t.language)}',
                    downloadLabel: t.dl,
                    status: manager.gemmaStatus(m.id),
                    selected: settings.gemmaModelId == m.id,
                    recommended: m.recommended,
                    isLast: i == GemmaCatalog.models.length - 1,
                    onSelect: () => ctrl.setGemmaModel(m.id),
                    onDownload: () => managerCtrl.downloadGemma(m.id),
                    onDelete: () => managerCtrl.deleteGemma(m.id),
                  ),
              ],
            ),
          ),
        ] else ...[
          ProviderPicker(
            allowed: RemoteProviderId.values,
            selected: provider,
            onSelect: ctrl.setSummaryProvider,
          ),
          const SizedBox(height: 12),
          ProviderConnectCard(provider: provider),
          const SizedBox(height: 12),
          SectionLabel(t.remoteModel, padding: const EdgeInsets.fromLTRB(6, 4, 6, 9)),
          RemoteModelList(
            provider: provider,
            forTranscription: false,
            selectedId: settings.summaryModelId(provider),
            onSelect: (id) => ctrl.setSummaryModel(provider, id),
          ),
        ],
      ],
    );
  }
}
