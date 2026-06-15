import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/segmented_control.dart';
import '../../../widgets/surfaces.dart';

/// App language toggle (full-width, no side label) + transcription language.
class LanguageSection extends ConsumerWidget {
  const LanguageSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final settings = ref.watch(settingsControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          AnimatedSegmentedControl(
            options: const [SegmentOption('Deutsch'), SegmentOption('English')],
            selectedIndex: settings.language == AppLanguage.de ? 0 : 1,
            onChanged: (i) => ctrl.setLanguage(i == 0 ? AppLanguage.de : AppLanguage.en),
          ),
          Divider(height: 28, color: palette.line),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  t.transLang,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: palette.ink),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        t.autoLang,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: palette.muted),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, size: 18, color: palette.faint),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
