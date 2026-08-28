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
  bool _busy = false;
  bool _replacing = false;
  bool _verified = false;
  bool _failed = false;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    await _run(() async {
      await ref
          .read(connectionsControllerProvider.notifier)
          .connect(widget.provider, _keyController.text);
      _keyController.clear();
      _replacing = false;
    });
  }

  Future<void> _test() => _run(
    () =>
        ref.read(connectionsControllerProvider.notifier).test(widget.provider),
  );

  Future<void> _disconnect() => _run(() async {
    await ref
        .read(connectionsControllerProvider.notifier)
        .disconnect(widget.provider);
    _replacing = false;
  });

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _verified = false;
      _failed = false;
    });
    try {
      await action();
      if (!mounted) return;
      setState(() => _verified = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
      child: connected && !_replacing
          ? ProviderConnectedStatus(
              provider: widget.provider,
              busy: _busy,
              verified: _verified,
              failed: _failed,
              onTest: _test,
              onReplace: () => setState(() {
                _replacing = true;
                _verified = false;
                _failed = false;
              }),
              onDisconnect: _disconnect,
            )
          : ProviderCredentialForm(
              controller: _keyController,
              busy: _busy,
              failed: _failed,
              onConnect: _connect,
              onShowHelp: _showKeyHelp,
              onCancel: connected
                  ? () => setState(() {
                      _replacing = false;
                      _failed = false;
                      _keyController.clear();
                    })
                  : null,
            ),
    );
  }
}
