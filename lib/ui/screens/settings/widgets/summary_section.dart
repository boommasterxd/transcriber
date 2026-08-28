import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../data/models/remote_provider.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/surfaces.dart';
import 'remote_stage_settings.dart';
import 'settings_switch_row.dart';

/// Optional cloud summary stage with independent provider and model selection.
class SummarySection extends ConsumerWidget {
  const SummarySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final provider = settings.summaryProvider;
    return Column(
      children: [
        _SummaryAvailabilityCard(
          enabled: settings.summarizeEnabled,
          onChanged: controller.setSummarizeEnabled,
        ),
        if (settings.summarizeEnabled) ...[
          const SizedBox(height: 12),
          RemoteStageSettings(
            selection: RemoteStageSelection(
              stage: RemoteStage.summary,
              allowedProviders: RemoteProviderId.values,
              provider: provider,
              modelId: settings.summaryModelId(provider),
            ),
            actions: RemoteStageActions(
              selectProvider: controller.setSummaryProvider,
              selectModel: (modelId) =>
                  controller.setSummaryModel(provider, modelId),
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryAvailabilityCard extends ConsumerWidget {
  const _SummaryAvailabilityCard({
    required this.enabled,
    required this.onChanged,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final strings = ref.watch(stringsProvider);
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: SettingsSwitchRow(
        icon: (
          data: Icons.auto_awesome_outlined,
          foreground: palette.accent,
          background: palette.accentSoft,
        ),
        content: (
          title: strings.summarizeTitle,
          subtitle: strings.summarizeSub,
          subtitleHeight: 1.35,
        ),
        value: enabled,
        onChanged: onChanged,
      ),
    );
  }
}
