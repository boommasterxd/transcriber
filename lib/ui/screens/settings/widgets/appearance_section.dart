import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/segmented_control.dart';
import '../../../widgets/surfaces.dart';

/// Theme (light/dark) and accent color selection. The theme toggle spans the
/// full width with a sliding thumb; no side label.
class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final settings = ref.watch(settingsControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSegmentedControl(
            options: [
              SegmentOption(t.system, icon: Icons.brightness_auto_outlined),
              SegmentOption(t.light, icon: Icons.light_mode_outlined),
              SegmentOption(t.dark, icon: Icons.dark_mode_outlined),
            ],
            selectedIndex: switch (settings.themeMode) {
              ThemeMode.system => 0,
              ThemeMode.light => 1,
              ThemeMode.dark => 2,
            },
            onChanged: (i) => ctrl.setThemeMode(
              switch (i) {
                1 => ThemeMode.light,
                2 => ThemeMode.dark,
                _ => ThemeMode.system,
              },
            ),
          ),
          Divider(height: 28, color: palette.line),
          Text(
            t.accentC,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: palette.ink),
          ),
          const SizedBox(height: 13),
          Center(child: AccentSwatches(selected: settings.accent, onSelected: ctrl.setAccent)),
        ],
      ),
    );
  }
}
