import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/catalog/remote_catalog.dart';
import '../../../../data/models/remote_provider.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/provider_logo.dart';

class ProviderCredentialForm extends ConsumerWidget {
  const ProviderCredentialForm({
    super.key,
    required this.provider,
    required this.controller,
    required this.busy,
    required this.connected,
    required this.verified,
    required this.failed,
    required this.onConnect,
    required this.onShowHelp,
    this.onTest,
    this.onDisconnect,
  });

  final RemoteProviderId provider;
  final TextEditingController controller;
  final bool busy;
  final bool connected;
  final bool verified;
  final bool failed;
  final VoidCallback onConnect;
  final VoidCallback onShowHelp;
  final VoidCallback? onTest;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final strings = ref.watch(stringsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProviderCredentialHeader(provider: provider, connected: connected),
        const SizedBox(height: 13),
        _ProviderApiKeyInput(
          provider: provider,
          controller: controller,
          onConnect: onConnect,
          busy: busy,
          connected: connected,
        ),
        if (verified || failed) ...[
          const SizedBox(height: 8),
          Text(
            verified ? strings.keyVerified : strings.keyCheckFailed,
            style: TextStyle(
              fontSize: 12,
              color: verified ? palette.mint : palette.coralInk,
            ),
          ),
        ],
        const SizedBox(height: 9),
        Text(
          strings.keyHint,
          style: TextStyle(fontSize: 12, color: palette.faint),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: busy ? null : onShowHelp,
            icon: const Icon(Icons.help_outline_rounded, size: 16),
            label: Text(strings.keyHelp),
          ),
        ),
        if (onTest != null || onDisconnect != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              if (onTest != null)
                Expanded(
                  child: TextButton(
                    onPressed: busy ? null : onTest,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(
                      strings.testKey,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              if (onTest != null && onDisconnect != null)
                const SizedBox(width: 8),
              if (onDisconnect != null)
                Expanded(
                  child: TextButton(
                    onPressed: busy ? null : onDisconnect,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(
                      strings.disconnect,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.coralInk),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ProviderCredentialHeader extends ConsumerWidget {
  const _ProviderCredentialHeader({
    required this.provider,
    required this.connected,
  });

  final RemoteProviderId provider;
  final bool connected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final strings = ref.watch(stringsProvider);
    final providerName = RemoteCatalog.provider(provider).name;
    return Row(
      children: [
        ProviderLogo(provider: provider, size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$providerName ${strings.apiKey}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
          ),
        ),
        if (connected)
          Icon(Icons.check_circle_rounded, size: 18, color: palette.mint),
      ],
    );
  }
}

class _ProviderApiKeyInput extends ConsumerWidget {
  const _ProviderApiKeyInput({
    required this.provider,
    required this.controller,
    required this.onConnect,
    required this.busy,
    required this.connected,
  });

  final RemoteProviderId provider;
  final TextEditingController controller;
  final VoidCallback onConnect;
  final bool busy;
  final bool connected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final button = _ProviderConnectButton(
      label: connected ? strings.replaceKey : strings.connect,
      busy: busy,
      onPressed: busy ? null : onConnect,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final field = _ProviderApiKeyField(
          provider: provider,
          controller: controller,
          onSubmitted: onConnect,
          enabled: !busy,
        );
        if (constraints.maxWidth < 390) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [field, const SizedBox(height: 8), button],
          );
        }
        return Row(
          children: [
            Expanded(child: field),
            const SizedBox(width: 8),
            button,
          ],
        );
      },
    );
  }
}

class _ProviderApiKeyField extends ConsumerWidget {
  const _ProviderApiKeyField({
    required this.provider,
    required this.controller,
    required this.onSubmitted,
    required this.enabled,
  });

  final RemoteProviderId provider;
  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final strings = ref.watch(stringsProvider);
    final placeholder = provider == RemoteProviderId.openai
        ? strings.openAiKeyPlaceholder
        : strings.googleKeyPlaceholder;
    return SizedBox(
      height: 46,
      child: TextField(
        controller: controller,
        enabled: enabled,
        obscureText: true,
        enableSuggestions: false,
        autocorrect: false,
        keyboardType: TextInputType.visiblePassword,
        onSubmitted: (_) => onSubmitted(),
        style: AppTheme.mono(color: palette.ink, size: 14),
        cursorColor: palette.accent,
        decoration: InputDecoration(
          filled: true,
          fillColor: palette.chip,
          prefixIcon: Icon(Icons.key_rounded, size: 17, color: palette.muted),
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(13),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          hintText: placeholder,
          hintStyle: TextStyle(fontSize: 14, color: palette.faint),
        ),
      ),
    );
  }
}

class _ProviderConnectButton extends StatelessWidget {
  const _ProviderConnectButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: 46,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.onAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        child: busy
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: palette.onAccent,
                ),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
