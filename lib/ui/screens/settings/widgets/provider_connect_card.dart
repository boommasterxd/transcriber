import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../data/catalog/remote_catalog.dart';
import '../../../../data/models/remote_provider.dart';
import '../../../../state/connections_controller.dart';
import '../../../widgets/surfaces.dart';
import 'provider_credential_form.dart';
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
  bool _verified = false;
  bool _failed = false;
  int _keyLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadStoredKey());
  }

  @override
  void didUpdateWidget(covariant ProviderConnectCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider == widget.provider) return;
    _keyLoadGeneration++;
    _keyController.clear();
    _verified = false;
    _failed = false;
    unawaited(_loadStoredKey());
  }

  @override
  void dispose() {
    _keyLoadGeneration++;
    _keyController.clear();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _loadStoredKey() async {
    final provider = widget.provider;
    final generation = ++_keyLoadGeneration;
    try {
      final key = await ref
          .read(connectionsControllerProvider.notifier)
          .apiKey(provider);
      if (!mounted ||
          generation != _keyLoadGeneration ||
          provider != widget.provider) {
        return;
      }
      _keyController.text = key;
    } catch (_) {
      if (!mounted || generation != _keyLoadGeneration) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _connect() async {
    await _run(() async {
      await ref
          .read(connectionsControllerProvider.notifier)
          .connect(widget.provider, _keyController.text);
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
    _keyLoadGeneration++;
    _keyController.clear();
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
    ref.listen<bool>(
      connectionsControllerProvider.select(
        (connections) => connections[widget.provider] ?? false,
      ),
      (previous, next) {
        if (!next) {
          _keyLoadGeneration++;
          _keyController.clear();
        } else if (previous != next) {
          unawaited(_loadStoredKey());
        }
      },
    );
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: ProviderCredentialForm(
        provider: widget.provider,
        controller: _keyController,
        busy: _busy,
        connected: connected,
        verified: _verified,
        failed: _failed,
        onConnect: _connect,
        onShowHelp: _showKeyHelp,
        onTest: connected ? _test : null,
        onDisconnect: connected ? _disconnect : null,
      ),
    );
  }
}
