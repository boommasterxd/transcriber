import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../data/catalog/remote_catalog.dart';
import '../../../../data/models/remote_provider.dart';
import '../../../../state/settings_controller.dart';

class ProviderKeyHelpDialog extends ConsumerWidget {
  const ProviderKeyHelpDialog({
    super.key,
    required this.provider,
    required this.onOpenPage,
  });

  final RemoteProviderId provider;
  final VoidCallback onOpenPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final providerName = RemoteCatalog.provider(provider).name;
    return AlertDialog(
      backgroundColor: palette.surface,
      title: Text(
        t.keyHelpTitle(providerName),
        style: TextStyle(
          color: palette.ink,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: _ProviderKeyHelpContent(providerName: providerName),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            t.cancel,
            style: TextStyle(color: palette.muted, fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onOpenPage();
          },
          child: Text(
            t.openPage,
            style: TextStyle(
              color: palette.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProviderKeyHelpContent extends ConsumerWidget {
  const _ProviderKeyHelpContent({required this.providerName});

  final String providerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final steps = [
      t.keyHelpStep1(providerName),
      t.keyHelpStep2,
      t.keyHelpStep3,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final step in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              step,
              style: TextStyle(fontSize: 14, height: 1.4, color: palette.body),
            ),
          ),
        const SizedBox(height: 6),
        Text(
          t.keyHelpNote,
          style: TextStyle(fontSize: 12.5, color: palette.muted),
        ),
      ],
    );
  }
}
