import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_palette.dart';
import '../../../data/catalog/remote_catalog.dart';
import '../../../services/dictation/dictation_platform.dart';
import '../../../services/dictation/live_transcription.dart';
import '../../../state/settings_controller.dart';
import '../../keyboard/keyboard_status_loader.dart';
import '../../widgets/surfaces.dart';

/// Optional guided setup for enabling and selecting the Android input method.
class KeyboardOnboardingScreen extends ConsumerWidget {
  const KeyboardOnboardingScreen({
    super.key,
    this.platform = const KeyboardSettingsPlatform(),
  });

  final KeyboardSettingsPlatform platform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final settings = ref.watch(settingsControllerProvider);
    final provider = RemoteCatalog.provider(settings.asrProvider).name;
    final model = LiveDictationModelCatalog.modelFor(settings.asrProvider);
    return Scaffold(
      backgroundColor: context.palette.bg,
      appBar: AppBar(
        backgroundColor: context.palette.bg,
        foregroundColor: context.palette.ink,
        title: Text(strings.keyboardSetupTitle),
      ),
      body: KeyboardStatusLoader(
        platform: platform,
        builder: (context, status, actions) => _SetupContent(
          status:
              status ?? const KeyboardStatus(enabled: false, selected: false),
          strings: strings,
          provider: provider,
          model: model,
          actions: actions,
        ),
      ),
    );
  }
}

class _SetupContent extends StatelessWidget {
  const _SetupContent({
    required this.status,
    required this.strings,
    required this.provider,
    required this.model,
    required this.actions,
  });

  final KeyboardStatus status;
  final AppStrings strings;
  final String provider;
  final String model;
  final KeyboardStatusActions actions;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        _SetupHero(strings: strings),
        const SizedBox(height: 18),
        _SetupStep(
          number: 1,
          complete: true,
          title: strings.keyboardSetupProviderTitle,
          body: strings.keyboardSetupProviderBody,
          detail: '$provider · $model',
        ),
        const SizedBox(height: 12),
        _SetupStep(
          number: 2,
          complete: status.enabled,
          title: strings.keyboardSetupEnableTitle,
          body: strings.keyboardSetupEnableBody,
          actionLabel: status.enabled
              ? strings.keyboardEnabled
              : strings.keyboardOpenSettings,
          action: status.enabled ? null : actions.enable,
        ),
        const SizedBox(height: 12),
        _SetupStep(
          number: 3,
          complete: status.selected,
          title: strings.keyboardSetupChooseTitle,
          body: strings.keyboardSetupChooseBody,
          actionLabel: status.selected
              ? strings.keyboardSelected
              : strings.keyboardChoose,
          action: status.enabled && !status.selected ? actions.choose : null,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                strings.keyboardPrivacy,
                style: TextStyle(color: context.palette.muted, fontSize: 12),
              ),
            ),
            IconButton(
              onPressed: actions.refresh,
              tooltip: strings.retry,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: status.selected ? () => Navigator.of(context).pop() : null,
          icon: const Icon(Icons.check_rounded),
          label: Text(strings.keyboardSetupDone),
        ),
      ],
    ),
  );
}

class _SetupHero extends StatelessWidget {
  const _SetupHero({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: context.palette.accent.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.keyboard_voice_rounded,
          size: 34,
          color: context.palette.accent,
        ),
      ),
      const SizedBox(height: 14),
      Text(
        strings.keyboardTitle,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: context.palette.ink,
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 7),
      Text(
        strings.keyboardSetupSubtitle,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.palette.body, height: 1.4),
      ),
    ],
  );
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.number,
    required this.complete,
    required this.title,
    required this.body,
    this.detail,
    this.actionLabel,
    this.action,
  });

  final int number;
  final bool complete;
  final String title;
  final String body;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepBadge(number: number, complete: complete),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.palette.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(body, style: TextStyle(color: context.palette.body)),
                if (detail case final value?) ...[
                  const SizedBox(height: 9),
                  Text(
                    value,
                    style: TextStyle(
                      color: context.palette.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (actionLabel case final label?) ...[
                  const SizedBox(height: 10),
                  FilledButton.tonal(onPressed: action, child: Text(label)),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.number, required this.complete});

  final int number;
  final bool complete;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 16,
    backgroundColor: complete ? context.palette.mint : context.palette.chip,
    foregroundColor: complete ? Colors.white : context.palette.ink,
    child: complete
        ? const Icon(Icons.check_rounded, size: 18)
        : Text('$number', style: const TextStyle(fontWeight: FontWeight.w800)),
  );
}
