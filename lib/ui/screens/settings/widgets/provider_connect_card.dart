import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../data/catalog/remote_catalog.dart';
import '../../../../data/models/remote_provider.dart';
import '../../../../state/connections_controller.dart';
import '../../../widgets/surfaces.dart';
import 'provider_connection_views.dart';
import 'provider_key_help_dialog.dart';

/// API-key connection controls for a single cloud provider.
class ProviderConnectCard extends ConsumerStatefulWidget {
  const ProviderConnectCard({super.key, required this.provider});

  final RemoteProviderId provider;

  @override
  ConsumerState<ProviderConnectCard> createState() =>
      _ProviderConnectCardState();
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

  Future<void> _openKeyPage() async {
    try {
      await launchUrl(
        Uri.parse(RemoteCatalog.keyUrlFor(widget.provider)),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  void _showKeyHelp() {
    showDialog<void>(
      context: context,
      builder: (_) => ProviderKeyHelpDialog(
        provider: widget.provider,
        onOpenPage: _openKeyPage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected =
        ref.watch(connectionsControllerProvider)[widget.provider] ?? false;
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: connected
          ? ProviderConnectedStatus(
              provider: widget.provider,
              onDisconnect: () => ref
                  .read(connectionsControllerProvider.notifier)
                  .disconnect(widget.provider),
            )
          : ProviderCredentialForm(
              controller: _keyController,
              onConnect: _connect,
              onShowHelp: _showKeyHelp,
            ),
    );
  }
}
