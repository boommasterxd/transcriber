import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../data/catalog/gemma_catalog.dart';
import '../../../../data/catalog/remote_catalog.dart';
import '../../../../data/models/processing_mode.dart';
import '../../../../data/models/remote_provider.dart';
import '../../../../state/connections_controller.dart';
import '../../../../state/model_manager_controller.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/model_tile.dart';
import '../../../widgets/surfaces.dart';
import 'downloadable_model_tile.dart';
import 'provider_connect_card.dart';
import 'provider_picker.dart';

/// Summary stage: on-device Gemma, or any cloud provider + model.
class SummarySection extends ConsumerWidget {
  const SummarySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final settings = ref.watch(settingsControllerProvider);
    final manager = ref.watch(modelManagerControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);
    final managerCtrl = ref.read(modelManagerControllerProvider.notifier);
    final isLocal = settings.summaryMode.isLocal;
    final provider = settings.summaryProvider;
    final connected = ref.watch(connectionsControllerProvider)[provider] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: PillSegment(
            items: [SegmentItem(label: t.modeLocalT), SegmentItem(label: t.modeRemoteT)],
            selectedIndex: isLocal ? 0 : 1,
            onSelected: (i) =>
                ctrl.setSummaryMode(i == 0 ? ProcessingMode.onDevice : ProcessingMode.cloud),
          ),
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
          if (connected)
            SurfaceCard(
              clip: true,
              child: Column(
                children: [
                  for (final (i, m) in RemoteCatalog.modelsFor(provider).indexed)
                    ModelTile(
                      leading: Icon(Icons.auto_awesome_outlined, size: 18, color: palette.accent),
                      title: m.displayName,
                      subtitle: m.badge.label(t.language),
                      isLast: i == RemoteCatalog.modelsFor(provider).length - 1,
                      trailing: SelectionIndicator(selected: settings.remoteModelId(provider) == m.id),
                      onTap: () => ctrl.setRemoteModel(provider, m.id),
                    ),
                ],
              ),
            )
          else
            SurfaceCard(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  t.connectFirst,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: palette.muted),
                ),
              ),
            ),
        ],
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
