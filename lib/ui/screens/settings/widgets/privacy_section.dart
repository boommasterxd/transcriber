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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          if (autoDelete)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 15, color: palette.coralInk),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.isDe
                          ? 'Hinweis: Gelöschte Audios können danach nicht mehr in der App abgespielt werden.'
                          : 'Note: deleted audio can no longer be played back in the app afterwards.',
                      style: TextStyle(fontSize: 12.5, height: 1.4, color: palette.coralInk),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
