import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/catalog/remote_catalog.dart';
import '../../../../data/models/remote_provider.dart';
import '../../../../state/settings_controller.dart';

class ProviderConnectedStatus extends ConsumerWidget {
  const ProviderConnectedStatus({
    super.key,
    required this.provider,
    required this.busy,
    required this.verified,
    required this.failed,
    required this.onTest,
    required this.onReplace,
    required this.onDisconnect,
  });

  final RemoteProviderId provider;
  final bool busy;
  final bool verified;
  final bool failed;
  final VoidCallback onTest;
  final VoidCallback onReplace;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final providerName = RemoteCatalog.provider(provider).name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: palette.mintSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.check_rounded, size: 17, color: palette.mint),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${t.connected} · $providerName',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                    ),
                  ),
                  Text(
                    '•••• •••• •••• ••••',
                    style: AppTheme.mono(color: palette.muted, size: 12.5),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            TextButton(onPressed: busy ? null : onTest, child: Text(t.testKey)),
            TextButton(
              onPressed: busy ? null : onReplace,
              child: Text(t.replaceKey),
            ),
            TextButton(
              onPressed: busy ? null : onDisconnect,
              child: Text(
                t.disconnect,
                style: TextStyle(color: palette.coralInk),
              ),
            ),
          ],
        ),
        if (verified || failed)
          Text(
            verified ? t.keyVerified : t.keyCheckFailed,
            style: TextStyle(
              fontSize: 12,
              color: verified ? palette.mint : palette.coralInk,
            ),
          ),
      ],
    );
  }
}

class ProviderCredentialForm extends ConsumerWidget {
  const ProviderCredentialForm({
    super.key,
    required this.controller,
    required this.busy,
    required this.failed,
    required this.onConnect,
    required this.onShowHelp,
    this.onCancel,
  });

  final TextEditingController controller;
  final bool busy;
  final bool failed;
  final VoidCallback onConnect;
  final VoidCallback onShowHelp;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProviderApiKeyInput(
          controller: controller,
          onConnect: onConnect,
          busy: busy,
        ),
        if (failed) ...[
          const SizedBox(height: 8),
          Text(
            t.keyCheckFailed,
            style: TextStyle(fontSize: 12, color: palette.coralInk),
          ),
        ],
        const SizedBox(height: 9),
        Text(t.keyHint, style: TextStyle(fontSize: 12, color: palette.faint)),
        const SizedBox(height: 8),
        _ProviderKeyHelpLink(onTap: onShowHelp),
        if (onCancel != null)
          TextButton(onPressed: busy ? null : onCancel, child: Text(t.cancel)),
      ],
    );
  }
}

class _ProviderApiKeyInput extends ConsumerWidget {
  const _ProviderApiKeyInput({
    required this.controller,
    required this.onConnect,
    required this.busy,
  });

  final TextEditingController controller;
  final VoidCallback onConnect;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return Row(
      children: [
        Expanded(
          child: _ProviderApiKeyField(
            controller: controller,
            onSubmitted: onConnect,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: busy ? null : onConnect,
          child: _ProviderConnectButton(label: t.connect, busy: busy),
        ),
      ],
    );
  }
}

class _ProviderApiKeyField extends ConsumerWidget {
  const _ProviderApiKeyField({
    required this.controller,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: palette.chip,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(Icons.key_rounded, size: 16, color: palette.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: true,
              onSubmitted: (_) => onSubmitted(),
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
    );
  }
}

class _ProviderConnectButton extends StatelessWidget {
  const _ProviderConnectButton({required this.label, required this.busy});

  final String label;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.accent,
        borderRadius: BorderRadius.circular(13),
      ),
      child: busy
          ? SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.onAccent,
              ),
            )
          : Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: palette.onAccent,
              ),
            ),
    );
  }
}

class _ProviderKeyHelpLink extends ConsumerWidget {
  const _ProviderKeyHelpLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.help_outline_rounded, size: 15, color: palette.accent),
          const SizedBox(width: 6),
          Text(
            t.keyHelp,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: palette.accent,
            ),
          ),
        ],
      ),
    );
  }
}
