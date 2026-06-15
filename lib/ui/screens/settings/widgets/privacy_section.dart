import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/surfaces.dart';

/// Privacy preferences: auto-delete the source audio after processing.
class PrivacySection extends ConsumerWidget {
  const PrivacySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final autoDelete = ref.watch(settingsControllerProvider.select((s) => s.autoDeleteAudio));
    final ctrl = ref.read(settingsControllerProvider.notifier);

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: palette.coralSoft, borderRadius: BorderRadius.circular(11)),
            child: Icon(Icons.delete_outline_rounded, size: 18, color: palette.coral),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.autoDel, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: palette.ink)),
                Text(t.autoDelSub, style: TextStyle(fontSize: 12.5, color: palette.muted)),
              ],
            ),
          ),
          Switch(
            value: autoDelete,
            onChanged: ctrl.setAutoDelete,
            activeTrackColor: palette.accent,
            inactiveTrackColor: palette.line2,
          ),
        ],
      ),
    );
  }
}
