import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../data/catalog/remote_catalog.dart';
import '../../../../data/catalog/whisper_catalog.dart';
import '../../../../data/models/processing_mode.dart';
import '../../../../state/model_manager_controller.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/surfaces.dart';
import 'downloadable_model_tile.dart';
import 'provider_connect_card.dart';
import 'provider_picker.dart';

/// Transcription stage: on-device Whisper, or a cloud ASR provider (OpenAI/Google).
class TranscriptionSection extends ConsumerWidget {
  const TranscriptionSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final settings = ref.watch(settingsControllerProvider);
    final manager = ref.watch(modelManagerControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);
    final managerCtrl = ref.read(modelManagerControllerProvider.notifier);
    final isLocal = settings.asrMode.isLocal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: PillSegment(
            items: [SegmentItem(label: t.modeLocalT), SegmentItem(label: t.modeRemoteT)],
            selectedIndex: isLocal ? 0 : 1,
            onSelected: (i) =>
                ctrl.setAsrMode(i == 0 ? ProcessingMode.onDevice : ProcessingMode.cloud),
          ),
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
                  ),
              ],
            ),
          )
        else ...[
          ProviderPicker(
            allowed: RemoteCatalog.asrProviders,
            selected: settings.asrProvider,
            onSelect: ctrl.setAsrProvider,
          ),
          const SizedBox(height: 12),
          ProviderConnectCard(provider: settings.asrProvider),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.graphic_eq_rounded, size: 14, color: palette.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${t.shStep1}: ${RemoteCatalog.asrModelLabel(settings.asrProvider)}',
                  style: TextStyle(fontSize: 12.5, color: palette.muted),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
