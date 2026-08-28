import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/surfaces.dart';
import 'settings_switch_row.dart';

/// Privacy preferences: auto-delete the source audio after processing.
class PrivacySection extends ConsumerWidget {
  const PrivacySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final autoDelete = ref.watch(
      settingsControllerProvider.select((s) => s.autoDeleteAudio),
    );
    final ctrl = ref.read(settingsControllerProvider.notifier);

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSwitchRow(
            icon: (
              data: Icons.delete_outline_rounded,
              foreground: palette.coral,
              background: palette.coralSoft,
            ),
            content: (
              title: t.autoDel,
              subtitle: t.autoDelSub,
              subtitleHeight: null,
            ),
            value: autoDelete,
            onChanged: ctrl.setAutoDelete,
          ),
          if (autoDelete) _AutoDeleteWarning(text: t.autoDelNote),
          Divider(height: 26, color: palette.line),
          _LocalProcessingStatement(text: t.privacyStatement),
        ],
      ),
    );
  }
}

class _AutoDeleteWarning extends StatelessWidget {
  const _AutoDeleteWarning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 15, color: palette.coralInk),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: palette.coralInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalProcessingStatement extends StatelessWidget {
  const _LocalProcessingStatement({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: palette.mintSoft,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(Icons.shield_outlined, size: 18, color: palette.mint),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12.5, height: 1.45, color: palette.body),
          ),
        ),
      ],
    );
  }
}
