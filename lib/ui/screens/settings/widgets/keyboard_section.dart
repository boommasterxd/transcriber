import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../data/catalog/remote_catalog.dart';
import '../../../../services/dictation/dictation_platform.dart';
import '../../../../services/dictation/live_transcription.dart';
import '../../../../state/settings_controller.dart';
import '../../../keyboard/keyboard_status_loader.dart';
import '../../onboarding/keyboard_onboarding_screen.dart';
import '../../../widgets/surfaces.dart';

class KeyboardSection extends ConsumerWidget {
  const KeyboardSection({
    super.key,
    this.platform = const KeyboardSettingsPlatform(),
  });

  final KeyboardSettingsPlatform platform;

  Future<void> _openSetup(BuildContext context) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => KeyboardOnboardingScreen(platform: platform),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final settings = ref.watch(settingsControllerProvider);
    final provider = settings.asrProvider;
    final model = LiveDictationModelCatalog.modelFor(provider);
    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.keyboardTitle,
            style: TextStyle(
              color: context.palette.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            strings.keyboardDescription,
            style: TextStyle(color: context.palette.body),
          ),
          const SizedBox(height: 12),
          _ModelLine(
            provider: RemoteCatalog.provider(provider).name,
            model: model,
          ),
          const SizedBox(height: 12),
          KeyboardStatusLoader(
            platform: platform,
            builder: (context, status, actions) => _StatusActions(
              status: status,
              strings: strings,
              onSetup: () async {
                await _openSetup(context);
                actions.refresh();
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            strings.keyboardPrivacy,
            style: TextStyle(color: context.palette.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ModelLine extends StatelessWidget {
  const _ModelLine({required this.provider, required this.model});
  final String provider;
  final String model;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: context.palette.chip,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(Icons.graphic_eq_rounded, size: 18, color: context.palette.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$provider\n$model',
            style: TextStyle(
              color: context.palette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _StatusActions extends StatelessWidget {
  const _StatusActions({
    required this.status,
    required this.strings,
    required this.onSetup,
  });
  final KeyboardStatus? status;
  final AppStrings strings;
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final enabled = status?.enabled == true;
    final selected = status?.selected == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              enabled ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              size: 18,
              color: enabled ? context.palette.mint : context.palette.coral,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                selected
                    ? strings.keyboardSelected
                    : enabled
                    ? strings.keyboardEnabled
                    : strings.keyboardDisabled,
                style: TextStyle(
                  color: context.palette.body,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onSetup,
            icon: Icon(
              selected ? Icons.check_rounded : Icons.arrow_forward_rounded,
            ),
            label: Text(
              selected
                  ? strings.keyboardManage
                  : enabled
                  ? strings.keyboardChoose
                  : strings.keyboardSetup,
            ),
          ),
        ),
      ],
    );
  }
}
