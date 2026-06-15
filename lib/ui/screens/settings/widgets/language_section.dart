import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/surfaces.dart';

/// App language toggle (DE/EN) and transcription language (auto-detect).
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t.uiLang, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: palette.ink)),
              PillSegment(
                items: const [SegmentItem(label: 'Deutsch'), SegmentItem(label: 'English')],
                selectedIndex: settings.language == AppLanguage.de ? 0 : 1,
                onSelected: (i) => ctrl.setLanguage(i == 0 ? AppLanguage.de : AppLanguage.en),
              ),
            ],
          ),
          Divider(height: 28, color: palette.line),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t.transLang, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: palette.ink)),
              Row(
                children: [
                  Text(t.autoLang, style: TextStyle(fontSize: 14, color: palette.muted)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 18, color: palette.faint),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
