import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/surfaces.dart';
import '../../settings/widgets/summary_section.dart';
import '../../settings/widgets/transcription_section.dart';

/// Configures both independent cloud stages and their BYOK credentials.
class OnboardingCloudStep extends ConsumerWidget {
  const OnboardingCloudStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(strings.setAsr),
        const TranscriptionSection(showCredentials: true),
        SectionLabel(strings.setLlm),
        const SummarySection(showCredentials: true),
        const SizedBox(height: 12),
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
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_outlined, size: 20, color: palette.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: palette.body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
