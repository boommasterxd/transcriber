import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../data/catalog/gemma_catalog.dart';
import '../../../../data/catalog/whisper_catalog.dart';
import '../../../../state/model_manager_controller.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/model_tile.dart';
import '../../../widgets/surfaces.dart';

/// On-device transcription + summary model lists, with download management and
/// an optional Hugging Face token field for gated models.
class LocalModelsSection extends ConsumerWidget {
  const LocalModelsSection({super.key});

  Future<void> _guardedDownload(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final settings = ref.watch(settingsControllerProvider);
    final manager = ref.watch(modelManagerControllerProvider);
    final managerCtrl = ref.read(modelManagerControllerProvider.notifier);
    final settingsCtrl = ref.read(settingsControllerProvider.notifier);
    final lang = settings.language;

    Widget tile({
      required IconData icon,
      required String title,
      required String subtitle,
      required ModelStatus status,
      required bool selected,
      required bool isLast,
      required VoidCallback onSelect,
      required Future<void> Function() onDownload,
    }) {
      final download = () => _guardedDownload(context, onDownload);
      return ModelTile(
        leading: Icon(icon, size: 18, color: context.palette.accent),
        title: title,
        subtitle: subtitle,
        isLast: isLast,
        trailing: switch (status.status) {
          DownloadStatus.downloading => ProgressRing(progress: status.progress),
          DownloadStatus.downloaded => SelectionIndicator(selected: selected),
          DownloadStatus.notDownloaded => DownloadChip(label: t.dl, onTap: download),
        },
        onTap: () {
          if (status.isDownloaded) {
            onSelect();
          } else if (!status.isDownloading) {
            download();
          }
        },
      );
    }

    String sub(int bytes, String badge) =>
        '${formatBytes(bytes, german: lang == AppLanguage.de)} · $badge';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(t.setAsr),
        SurfaceCard(
          clip: true,
          child: Column(
            children: [
              for (final (i, m) in WhisperCatalog.models.indexed)
                tile(
                  icon: Icons.graphic_eq_rounded,
                  title: m.displayName,
                  subtitle: sub(m.sizeBytes, m.badge.label(lang)),
                  status: manager.whisperStatus(m.id),
                  selected: settings.whisperModelId == m.id,
                  isLast: i == WhisperCatalog.models.length - 1,
                  onSelect: () => settingsCtrl.setWhisperModel(m.id),
                  onDownload: () => managerCtrl.downloadWhisper(m.id),
                ),
            ],
          ),
        ),
        SectionLabel(t.setLlm),
        SurfaceCard(
          clip: true,
          child: Column(
            children: [
              for (final (i, m) in GemmaCatalog.models.indexed)
                tile(
                  icon: Icons.auto_awesome_outlined,
                  title: m.displayName,
                  subtitle: sub(m.sizeBytes, m.badge.label(lang)),
                  status: manager.gemmaStatus(m.id),
                  selected: settings.gemmaModelId == m.id,
                  isLast: i == GemmaCatalog.models.length - 1,
                  onSelect: () => settingsCtrl.setGemmaModel(m.id),
                  onDownload: () => managerCtrl.downloadGemma(m.id),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _HfTokenField(initial: settings.hfToken, onChanged: settingsCtrl.setHfToken),
      ],
    );
  }
}

class _HfTokenField extends StatefulWidget {
  const _HfTokenField({required this.initial, required this.onChanged});
  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<_HfTokenField> createState() => _HfTokenFieldState();
}

class _HfTokenFieldState extends State<_HfTokenField> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hugging Face Token',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: palette.ink),
          ),
          const SizedBox(height: 4),
          Text(
            'Für den Download gated Modelle (Gemma 3n).',
            style: TextStyle(fontSize: 12.5, color: palette.muted),
          ),
          const SizedBox(height: 12),
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: palette.chip, borderRadius: BorderRadius.circular(13)),
            child: Row(
              children: [
                Icon(Icons.key_rounded, size: 16, color: palette.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    obscureText: true,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onChanged,
                    style: TextStyle(fontSize: 14, color: palette.ink),
                    cursorColor: palette.accent,
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'hf_…',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
