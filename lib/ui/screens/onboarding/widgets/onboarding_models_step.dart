import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/remote_provider.dart';
import '../../../../state/connections_controller.dart';
import '../../settings/widgets/summary_section.dart';
import '../../settings/widgets/transcription_section.dart';

/// Chooses models for the providers connected in the preceding step.
class OnboardingModelsStep extends ConsumerWidget {
  const OnboardingModelsStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connections = ref.watch(connectionsControllerProvider);
    final connected = RemoteProviderId.values
        .where((provider) => connections[provider] ?? false)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TranscriptionSection(allowedProviders: connected),
        const SizedBox(height: 16),
        SummarySection(allowedProviders: connected),
      ],
    );
  }
}
