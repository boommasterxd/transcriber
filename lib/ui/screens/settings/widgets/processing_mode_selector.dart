import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../data/models/processing_mode.dart';
import '../../../../state/settings_controller.dart';

/// The on-device ↔ cloud master switch plus its contextual privacy note.
class ProcessingModeSelector extends ConsumerWidget {
  const ProcessingModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final mode = ref.watch(settingsControllerProvider.select((s) => s.mode));
    final controller = ref.read(settingsControllerProvider.notifier);
    final isLocal = mode.isLocal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _ModeCard(
                selected: isLocal,
                icon: Icons.shield_outlined,
                iconBg: palette.mintSoft,
                iconColor: palette.mint,
                title: t.modeLocalT,
                subtitle: t.modeLocalS,
                onTap: () => controller.setMode(ProcessingMode.onDevice),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ModeCard(
                selected: !isLocal,
                icon: Icons.cloud_outlined,
                iconBg: palette.accentSoft,
                iconColor: palette.accent,
                title: t.modeRemoteT,
                subtitle: t.modeRemoteS,
                onTap: () => controller.setMode(ProcessingMode.cloud),
              ),
            ),
          ],
        ),
        if (isLocal)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 15, color: palette.mint),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.noteLocal,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: palette.mint),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(color: palette.coralSoft, borderRadius: BorderRadius.circular(13)),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: palette.coralInk),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.noteRemote,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: palette.coralInk),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.selected,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? palette.accent : Colors.transparent, width: 2),
          boxShadow: [BoxShadow(color: palette.shadow, blurRadius: 12, offset: const Offset(0, 2))],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                const SizedBox(height: 11),
                Text(title, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: palette.ink)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: palette.muted)),
              ],
            ),
            if (selected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(color: palette.accent, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
