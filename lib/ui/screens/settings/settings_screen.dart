import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../data/models/remote_provider.dart';
import '../../../state/settings_controller.dart';
import '../../widgets/buttons.dart';
import '../../widgets/surfaces.dart';
import 'widgets/appearance_section.dart';
import 'widgets/language_section.dart';
import 'widgets/privacy_section.dart';
import 'widgets/provider_connect_card.dart';
import 'widgets/summary_section.dart';
import 'widgets/transcription_section.dart';

/// Cloud provider, BYOK credential, language, appearance, and privacy settings.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final strings = ref.watch(stringsProvider);
    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _SettingsHeader(title: strings.setTitle),
            Expanded(
              child: FadeEdges(
                builder: (context, controller) => ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 36),
                  children: [
                    SectionLabel(strings.setAsr),
                    const TranscriptionSection(),
                    SectionLabel(strings.setLlm),
                    const SummarySection(),
                    SectionLabel(strings.apiKey),
                    const ProviderConnectionList(),
                    SectionLabel(strings.setLang),
                    const LanguageSection(),
                    SectionLabel(strings.setAppear),
                    const AppearanceSection(),
                    SectionLabel(strings.setPriv),
                    const PrivacySection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
    child: Row(
      children: [
        IconCircleButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: context.palette.ink,
          ),
        ),
      ],
    ),
  );
}

class ProviderConnectionList extends StatelessWidget {
  const ProviderConnectionList({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      ProviderConnectCard(provider: RemoteProviderId.openai),
      SizedBox(height: 12),
      ProviderConnectCard(provider: RemoteProviderId.google),
    ],
  );
}
