import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../data/models/remote_provider.dart';
import '../../../../state/settings_controller.dart';
import '../../settings/widgets/provider_connect_card.dart';

/// Connects at least one cloud provider before choosing models.
class OnboardingCloudStep extends ConsumerStatefulWidget {
  const OnboardingCloudStep({super.key});

  @override
  ConsumerState<OnboardingCloudStep> createState() =>
      _OnboardingCloudStepState();
}

class _OnboardingCloudStepState extends ConsumerState<OnboardingCloudStep> {
  RemoteProviderId? _expandedProvider;

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final provider in RemoteProviderId.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ProviderConnectCard(
              provider: provider,
              expanded: _expandedProvider == provider,
              onExpansionChanged: (expanded) => setState(
                () => _expandedProvider = expanded ? provider : null,
              ),
            ),
          ),
        const SizedBox(height: 8),
        _CloudPrivacyNotice(text: strings.privacyStatement),
      ],
    );
  }
}

class _CloudPrivacyNotice extends StatelessWidget {
  const _CloudPrivacyNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Text(
      text,
      style: TextStyle(fontSize: 12.5, height: 1.45, color: palette.muted),
    );
  }
}
