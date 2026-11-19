import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../data/catalog/remote_catalog.dart';
import '../../../../data/models/remote_provider.dart';
import '../../../../state/connections_controller.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/provider_logo.dart';
import '../../../widgets/surfaces.dart';
import 'provider_credential_form.dart';
import 'provider_key_help_dialog.dart';

/// API-key connection controls for a single cloud provider.
class ProviderConnectCard extends ConsumerStatefulWidget {
  const ProviderConnectCard({
    super.key,
    required this.provider,
    this.expanded,
    this.onExpansionChanged,
  });

  final RemoteProviderId provider;
  final bool? expanded;
  final ValueChanged<bool>? onExpansionChanged;

  @override
  ConsumerState<ProviderConnectCard> createState() =>
      _ProviderConnectCardState();
}

class _ProviderConnectCardState extends ConsumerState<ProviderConnectCard> {
  TextEditingController? _keyController;
  String? _loadedKey;
  bool _busy = false;
  bool _verified = false;
  bool _failed = false;
  bool _expanded = false;
  int _keyLoadGeneration = 0;

  bool get _isExpanded => widget.expanded ?? _expanded;

  @override
  void initState() {
    super.initState();
    if (_isExpanded) _openEditor();
  }

  @override
  void didUpdateWidget(covariant ProviderConnectCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider) {
      _closeEditor(discardDraft: true);
      _busy = false;
      _verified = false;
      _failed = false;
      if (_isExpanded) _openEditor();
    } else if ((oldWidget.expanded ?? _expanded) != _isExpanded) {
      _syncEditor();
    }
  }

  @override
  void dispose() {
    _keyLoadGeneration++;
    _keyController?.dispose();
    super.dispose();
  }

  void _syncEditor() {
    if (_isExpanded) {
      _openEditor();
    } else {
      _closeEditor();
    }
  }

  void _openEditor() {
    final controller = _keyController ??= TextEditingController();
    if (controller.text.isEmpty &&
        ref.read(connectionsControllerProvider)[widget.provider] == true) {
      unawaited(_loadStoredKey(controller));
    }
  }

  void _closeEditor({bool discardDraft = false}) {
    _keyLoadGeneration++;
    final controller = _keyController;
    if (controller != null &&
        (discardDraft ||
            controller.text.isEmpty ||
            controller.text == _loadedKey)) {
      _keyController = null;
      // The collapsing field can still use its controller until it unmounts.
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    }
    _loadedKey = null;
  }

  Future<void> _loadStoredKey(TextEditingController controller) async {
    final provider = widget.provider;
    final generation = ++_keyLoadGeneration;
    try {
      final key = await ref
          .read(connectionsControllerProvider.notifier)
          .apiKey(provider);
      if (!mounted || generation != _keyLoadGeneration) return;
      if (controller.text.isNotEmpty) return;
      _loadedKey = key;
      controller.text = key;
    } catch (_) {
      if (!mounted || generation != _keyLoadGeneration) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _connect() async {
    final controller = _keyController;
    if (controller == null) return;
    final candidate = controller.text;
    await _run(() async {
      await ref
          .read(connectionsControllerProvider.notifier)
          .connect(widget.provider, candidate);
      if (!mounted || !identical(_keyController, controller)) return;
      if (controller.text != candidate) return;
      _loadedKey = candidate;
      if (!_isExpanded) _closeEditor();
    });
  }

  Future<void> _test() => _run(
    () =>
        ref.read(connectionsControllerProvider.notifier).test(widget.provider),
  );

  Future<void> _disconnect() => _run(() async {
    final provider = widget.provider;
    await ref.read(connectionsControllerProvider.notifier).disconnect(provider);
  });

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    final provider = widget.provider;
    setState(() {
      _busy = true;
      _verified = false;
      _failed = false;
    });
    try {
      await action();
      if (!mounted || provider != widget.provider) return;
      setState(() => _verified = true);
    } catch (_) {
      if (!mounted || provider != widget.provider) return;
      setState(() => _failed = true);
    } finally {
      if (mounted && provider == widget.provider) setState(() => _busy = false);
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

  void _toggleExpanded() {
    final expanded = !_isExpanded;
    if (widget.expanded == null) {
      setState(() {
        _expanded = expanded;
        _syncEditor();
      });
    }
    widget.onExpansionChanged?.call(expanded);
  }

  @override
  Widget build(BuildContext context) {
    final connected =
        ref.watch(connectionsControllerProvider)[widget.provider] ?? false;
    final strings = ref.watch(stringsProvider);
    final expanded = _isExpanded;
    ref.listen<bool>(
      connectionsControllerProvider.select(
        (connections) => connections[widget.provider] ?? false,
      ),
      (previous, next) {
        if (!next) {
          _keyLoadGeneration++;
          _loadedKey = null;
          _keyController?.clear();
        } else if (previous != next && _isExpanded) {
          _openEditor();
        }
      },
    );
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _connectionRow(connected, expanded, strings),
          // Keep a local scope when the editor disappears so an unrelated
          // previously focused input cannot reopen its keyboard.
          FocusScope(child: _credentialArea(connected, expanded)),
        ],
      ),
    );
  }

  Widget _credentialArea(bool connected, bool expanded) {
    final child = expanded
        ? Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ProviderCredentialForm(
              provider: widget.provider,
              controller: _keyController!,
              status: CredentialFormStatus(
                busy: _busy,
                connected: connected,
                verified: _verified,
                failed: _failed,
              ),
              actions: CredentialFormActions(
                connect: _connect,
                showHelp: _showKeyHelp,
                test: connected ? _test : null,
                disconnect: connected ? _disconnect : null,
              ),
            ),
          )
        : const SizedBox(width: double.infinity);
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: child,
    );
  }

  Widget _connectionRow(bool connected, bool expanded, AppStrings strings) {
    final palette = context.palette;
    final status = _busy
        ? strings.providerChecking
        : _failed
        ? strings.providerConnectionFailed
        : connected
        ? strings.connected
        : strings.keyMissing;
    return Semantics(
      expanded: expanded,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          contentPadding: const EdgeInsets.all(16),
          onTap: _toggleExpanded,
          leading: ProviderLogo(provider: widget.provider, size: 34),
          title: Text(
            RemoteCatalog.provider(widget.provider).name,
            style: TextStyle(fontWeight: FontWeight.w700, color: palette.ink),
          ),
          subtitle: Text(
            status,
            style: TextStyle(
              fontSize: 12,
              color: _failed ? palette.coralInk : palette.muted,
            ),
          ),
          trailing: Icon(
            expanded ? Icons.expand_less : Icons.expand_more,
            color: palette.muted,
          ),
        ),
      ),
    );
  }
}
