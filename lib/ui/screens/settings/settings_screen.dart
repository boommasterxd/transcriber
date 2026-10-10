import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/settings_controller.dart';
import 'model_settings_screen.dart';
import 'settings_section_screen.dart';
import 'widgets/settings_navigation_tile.dart';
import 'widgets/settings_page.dart';
import 'widgets/settings_version_footer.dart';

/// Settings overview with focused pages for each category.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final destinations = [
      (
        title: strings.keyboardSection,
        icon: Icons.keyboard_outlined,
        page: const SettingsSectionScreen(category: SettingsCategory.keyboard),
      ),
      (
        title: strings.setModels,
        icon: Icons.tune_rounded,
        page: const ModelSettingsScreen(),
      ),
      (
        title: strings.setGeneral,
        icon: Icons.settings_outlined,
        page: const SettingsSectionScreen(category: SettingsCategory.general),
      ),
    ];
    return SettingsPage(
      title: strings.setTitle,
      footer: const SettingsVersionFooter(),
      children: [
        for (final destination in destinations)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SettingsNavigationTile(
              title: destination.title,
              icon: destination.icon,
              page: destination.page,
            ),
          ),
      ],
    );
  }
}
