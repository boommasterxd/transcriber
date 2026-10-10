import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/settings_controller.dart';
import 'api_keys_screen.dart';
import 'widgets/settings_navigation_tile.dart';
import 'widgets/settings_page.dart';
import 'widgets/summary_section.dart';
import 'widgets/transcription_section.dart';

/// Independent cloud provider and model choices with shared key management.
class ModelSettingsScreen extends ConsumerWidget {
  const ModelSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return SettingsPage(
      title: strings.setModels,
      children: [
        const TranscriptionSection(),
        const SizedBox(height: 16),
        const SummarySection(),
        const SizedBox(height: 24),
        SettingsNavigationTile(
          title: strings.providerConnectionsTitle,
          subtitle: strings.apiKeysDescription,
          icon: Icons.key_rounded,
          page: const ApiKeysScreen(),
        ),
      ],
    );
  }
}
