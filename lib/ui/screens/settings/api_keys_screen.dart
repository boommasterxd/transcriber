import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/remote_provider.dart';
import '../../../state/settings_controller.dart';
import 'widgets/provider_connect_card.dart';
import 'widgets/settings_page.dart';

/// One credential editor per provider, shared by both processing stages.
class ApiKeysScreen extends ConsumerWidget {
  const ApiKeysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SettingsPage(
    title: ref.watch(stringsProvider).providerConnectionsTitle,
    children: [
      for (final provider in RemoteProviderId.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ProviderConnectCard(provider: provider),
        ),
    ],
  );
}
