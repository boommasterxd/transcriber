import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
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
          _HfTokenField(initial: settings.hfToken, german: t.isDe, onChanged: ctrl.setHfToken),
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

class _HfTokenField extends StatefulWidget {
  const _HfTokenField({required this.initial, required this.german, required this.onChanged});
  final String initial;
  final bool german;
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

  Future<void> _openTokens() async {
    try {
      await launchUrl(
        Uri.parse('https://huggingface.co/settings/tokens'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final german = widget.german;
    final steps = german
        ? [
            '1. Kostenlos auf huggingface.co anmelden',
            '2. Settings → Access Tokens → New token (Typ: Read)',
            '3. Token (hf_…) kopieren und hier einfügen',
            '4. Bei Gemma: auf der Modellseite die Lizenz akzeptieren',
          ]
        : [
            '1. Sign up for free at huggingface.co',
            '2. Settings → Access Tokens → New token (type: Read)',
            '3. Copy the token (hf_…) and paste it here',
            '4. For Gemma: accept the license on the model page',
          ];

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
            german
                ? 'Nötig, um die Modelle herunterzuladen (z. B. Gemma). So bekommst du einen:'
                : 'Needed to download the models (e.g. Gemma). How to get one:',
            style: TextStyle(fontSize: 12.5, height: 1.4, color: palette.muted),
          ),
          const SizedBox(height: 8),
          for (final s in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(s, style: TextStyle(fontSize: 12.5, height: 1.35, color: palette.body)),
            ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _openTokens,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  german ? 'Token erstellen' : 'Create token',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: palette.accent),
                ),
                const SizedBox(width: 4),
                Icon(Icons.open_in_new_rounded, size: 14, color: palette.accent),
              ],
            ),
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
