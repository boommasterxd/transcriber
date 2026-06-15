import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/formatting.dart';
import '../../../data/catalog/gemma_catalog.dart';
import '../../../data/catalog/whisper_catalog.dart';
import '../../../state/model_manager_controller.dart';
import '../../../state/settings_controller.dart';
import '../../widgets/buttons.dart';
import '../../widgets/surfaces.dart';
import 'widgets/appearance_section.dart';
import 'widgets/language_section.dart';
import 'widgets/privacy_section.dart';
import 'widgets/summary_section.dart';
import 'widgets/transcription_section.dart';

/// Settings: processing mode (master switch) → models (local/cloud) → language
/// → appearance → privacy.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final manager = ref.watch(modelManagerControllerProvider);

    final storage = _storageSummary(manager, t);

    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: Row(
                children: [
                  IconCircleButton(icon: Icons.arrow_back_ios_new_rounded, onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 12),
                  Text(
                    t.setTitle,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: palette.ink),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FadeEdges(
                builder: (context, controller) => ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 36),
                  children: [
                    SectionLabel(t.setAsr, padding: const EdgeInsets.fromLTRB(6, 12, 6, 9)),
                    const TranscriptionSection(),
                    SectionLabel(t.setLlm),
                    const SummarySection(),
                    SectionLabel(t.setLang),
                    const LanguageSection(),
                    SectionLabel(t.setAppear),
                    const AppearanceSection(),
                    SectionLabel(t.setPriv),
                    const PrivacySection(),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        storage,
                        style: TextStyle(fontSize: 12.5, color: palette.faint),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _storageSummary(ModelManagerState manager, AppStrings t) {
    var count = 0;
    var bytes = 0;
    for (final m in WhisperCatalog.models) {
      if (manager.whisperStatus(m.id).isDownloaded) {
        count++;
        bytes += m.sizeBytes;
      }
    }
    for (final m in GemmaCatalog.models) {
      if (manager.gemmaStatus(m.id).isDownloaded) {
        count++;
        bytes += m.sizeBytes;
      }
    }
    return t.storage(count, formatBytes(bytes, german: t.isDe));
  }
}
