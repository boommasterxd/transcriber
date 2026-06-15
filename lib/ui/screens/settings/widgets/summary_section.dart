import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../data/catalog/gemma_catalog.dart';
import '../../../../data/models/inference_backend.dart';
import '../../../../data/models/processing_mode.dart';
import '../../../../data/models/remote_provider.dart';
import '../../../../state/model_manager_controller.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/segmented_control.dart';
import '../../../widgets/surfaces.dart';
import 'downloadable_model_tile.dart';
import 'provider_connect_card.dart';
import 'provider_picker.dart';
import 'remote_model_list.dart';
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
                    isLast: i == GemmaCatalog.models.length - 1,
                    onSelect: () => ctrl.setGemmaModel(m.id),
                    onDownload: () => managerCtrl.downloadGemma(m.id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _HfTokenField(initial: settings.hfToken, onChanged: ctrl.setHfToken),
          const SizedBox(height: 12),
          _BackendField(
            selected: settings.gemmaBackend,
            german: t.isDe,
            onChanged: ctrl.setGemmaBackend,
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

/// Compute-backend selector (Auto/GPU/CPU/NPU) for the on-device summary model.
class _BackendField extends StatelessWidget {
  const _BackendField({required this.selected, required this.german, required this.onChanged});

  final InferenceBackend selected;
  final bool german;
  final ValueChanged<InferenceBackend> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Backend', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: palette.ink)),
          const SizedBox(height: 4),
          Text(
            german ? 'GPU am schnellsten · NPU ist geräteabhängig' : 'GPU is fastest · NPU is device-dependent',
            style: TextStyle(fontSize: 12.5, color: palette.muted),
          ),
          const SizedBox(height: 12),
          AnimatedSegmentedControl(
            options: [for (final b in InferenceBackend.values) SegmentOption(b.label)],
            selectedIndex: InferenceBackend.values.indexOf(selected),
            onChanged: (i) => onChanged(InferenceBackend.values[i]),
          ),
        ],
      ),
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
            'Für den Download gated Modelle (Gemma, Gemma 3n).',
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
