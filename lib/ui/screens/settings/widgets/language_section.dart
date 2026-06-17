import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../data/models/transcription_language.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/segmented_control.dart';
import '../../../widgets/surfaces.dart';

/// App language and transcription language — each a label above a full-width
/// sliding segmented control.
class LanguageSection extends ConsumerWidget {
  const LanguageSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final settings = ref.watch(settingsControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: palette.ink)),
        );

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label(t.uiLang),
          AnimatedSegmentedControl(
            options: const [SegmentOption('Deutsch'), SegmentOption('English')],
            selectedIndex: settings.language == AppLanguage.de ? 0 : 1,
            onChanged: (i) => ctrl.setLanguage(i == 0 ? AppLanguage.de : AppLanguage.en),
          ),
          Divider(height: 28, color: palette.line),
          label(t.transLang),
          AnimatedSegmentedControl(
            options: const [SegmentOption('Auto'), SegmentOption('Deutsch'), SegmentOption('English')],
            selectedIndex: switch (settings.transcriptionLanguage) {
              TranscriptionLanguage.auto => 0,
              TranscriptionLanguage.de => 1,
              TranscriptionLanguage.en => 2,
            },
            onChanged: (i) => ctrl.setTranscriptionLanguage(
              switch (i) {
                1 => TranscriptionLanguage.de,
                2 => TranscriptionLanguage.en,
                _ => TranscriptionLanguage.auto,
              },
            ),
          ),
        ],
      ),
    );
  }
}
