import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/catalog/remote_catalog.dart';
import '../../../../data/models/remote_provider.dart';
import '../../../../state/connections_controller.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/surfaces.dart';

/// API-key connect / connected card for a single provider. The key is stored in
/// secure storage via [ConnectionsController].
class ProviderConnectCard extends ConsumerStatefulWidget {
  const ProviderConnectCard({super.key, required this.provider});

  final RemoteProviderId provider;

  @override
  ConsumerState<ProviderConnectCard> createState() => _ProviderConnectCardState();
}

class _ProviderConnectCardState extends ConsumerState<ProviderConnectCard> {
  final TextEditingController _keyController = TextEditingController();

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    await ref
        .read(connectionsControllerProvider.notifier)
        .connect(widget.provider, _keyController.text);
    _keyController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final connected = ref.watch(connectionsControllerProvider)[widget.provider] ?? false;
    final providerName = RemoteCatalog.provider(widget.provider).name;

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: connected
          ? Row(
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
                        '${t.connected} · $providerName',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: palette.ink),
                      ),
                      Text('•••• •••• •••• ••••', style: AppTheme.mono(color: palette.muted, size: 12.5)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      ref.read(connectionsControllerProvider.notifier).disconnect(widget.provider),
                  child: Text(
                    t.disconnect,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: palette.coralInk),
                  ),
                ),
              ],
            )
          : Column(
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
                                controller: _keyController,
                                obscureText: true,
                                onSubmitted: (_) => _connect(),
                                style: AppTheme.mono(color: palette.ink, size: 14),
                                cursorColor: palette.accent,
                                decoration: InputDecoration(
                                  isCollapsed: true,
                                  border: InputBorder.none,
                                  hintText: t.keyPlaceholder,
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
                      onTap: _connect,
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: palette.accent, borderRadius: BorderRadius.circular(13)),
                        child: Text(
                          t.connect,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: palette.onAccent),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(t.keyHint, style: TextStyle(fontSize: 12, color: palette.faint)),
              ],
            ),
    );
  }
}
