import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/catalog/remote_catalog.dart';
import '../../../../state/connections_controller.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/model_tile.dart';
import '../../../widgets/surfaces.dart';

/// Cloud provider selection, API-key connection, and remote model picker.
class CloudSection extends ConsumerStatefulWidget {
  const CloudSection({super.key});

  @override
  ConsumerState<CloudSection> createState() => _CloudSectionState();
}

class _CloudSectionState extends ConsumerState<CloudSection> {
  final TextEditingController _keyController = TextEditingController();

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final provider = ref.read(settingsControllerProvider).provider;
    await ref.read(connectionsControllerProvider.notifier).connect(provider, _keyController.text);
    _keyController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final settings = ref.watch(settingsControllerProvider);
    final connections = ref.watch(connectionsControllerProvider);
    final settingsCtrl = ref.read(settingsControllerProvider.notifier);
    final provider = settings.provider;
    final connected = connections[provider] ?? false;
    final providerMeta = RemoteCatalog.provider(provider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(t.provider),
        SurfaceCard(
          clip: true,
          child: Column(
            children: [
              for (final (i, p) in RemoteCatalog.providers.indexed)
                ModelTile(
                  leading: Text(
                    p.glyph,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  leadingColor: p.color,
                  title: p.name,
                  subtitle: settings.language.code == 'de' ? p.subDe : p.subEn,
                  isLast: i == RemoteCatalog.providers.length - 1,
                  trailing: SelectionIndicator(selected: provider == p.id),
                  onTap: () => settingsCtrl.setProvider(p.id),
                ),
            ],
          ),
        ),
        SectionLabel(t.apiKey),
        SurfaceCard(
          padding: const EdgeInsets.all(16),
          child: connected
              ? _ConnectedRow(
                  providerName: providerMeta.name,
                  connectedLabel: t.connected,
                  disconnectLabel: t.disconnect,
                  onDisconnect: () =>
                      ref.read(connectionsControllerProvider.notifier).disconnect(provider),
                )
              : _KeyInput(
                  controller: _keyController,
                  hint: t.keyPlaceholder,
                  connectLabel: t.connect,
                  hintLabel: t.keyHint,
                  onConnect: _connect,
                ),
        ),
        SectionLabel(t.remoteModel),
        if (connected)
          SurfaceCard(
            clip: true,
            child: Column(
              children: [
                for (final (i, m) in RemoteCatalog.modelsFor(provider).indexed)
                  ModelTile(
                    leading: Icon(Icons.auto_awesome_outlined, size: 18, color: palette.accent),
                    title: m.displayName,
                    subtitle: m.badge.label(settings.language),
                    isLast: i == RemoteCatalog.modelsFor(provider).length - 1,
                    trailing: SelectionIndicator(selected: settings.remoteModelId(provider) == m.id),
                    onTap: () => settingsCtrl.setRemoteModel(provider, m.id),
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
    );
  }
}

class _ConnectedRow extends StatelessWidget {
  const _ConnectedRow({
    required this.providerName,
    required this.connectedLabel,
    required this.disconnectLabel,
    required this.onDisconnect,
  });

  final String providerName;
  final String connectedLabel;
  final String disconnectLabel;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: palette.mintSoft, borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.check_rounded, size: 17, color: palette.mint),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$connectedLabel · $providerName',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: palette.ink),
              ),
              Text('•••• •••• •••• ••••', style: AppTheme.mono(color: palette.muted, size: 12.5)),
            ],
          ),
        ),
        GestureDetector(
          onTap: onDisconnect,
          child: Text(
            disconnectLabel,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: palette.coralInk),
          ),
        ),
      ],
    );
  }
}

class _KeyInput extends StatelessWidget {
  const _KeyInput({
    required this.controller,
    required this.hint,
    required this.connectLabel,
    required this.hintLabel,
    required this.onConnect,
  });

  final TextEditingController controller;
  final String hint;
  final String connectLabel;
  final String hintLabel;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: palette.chip, borderRadius: BorderRadius.circular(13)),
                child: Row(
                  children: [
                    Icon(Icons.key_rounded, size: 16, color: palette.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        obscureText: true,
                        onSubmitted: (_) => onConnect(),
                        style: AppTheme.mono(color: palette.ink, size: 14),
                        cursorColor: palette.accent,
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: hint,
                          hintStyle: TextStyle(fontSize: 14, color: palette.faint),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onConnect,
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: palette.accent, borderRadius: BorderRadius.circular(13)),
                child: Text(
                  connectLabel,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: palette.onAccent),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(hintLabel, style: TextStyle(fontSize: 12, color: palette.faint)),
      ],
    );
  }
}
