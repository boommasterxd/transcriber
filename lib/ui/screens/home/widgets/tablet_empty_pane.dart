import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../state/settings_controller.dart';

class TabletEmptyPane extends ConsumerWidget {
  const TabletEmptyPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final strings = ref.watch(stringsProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: palette.accentSoft,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(
                Icons.graphic_eq_rounded,
                size: 42,
                color: palette.accent,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              strings.tabEmptyTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              strings.tabEmptySub,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.5,
                color: palette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
