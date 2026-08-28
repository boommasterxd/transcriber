import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// Checkable action-item tile (coral background, mint check when done).
class TodoTile extends StatelessWidget {
  const TodoTile({
    super.key,
    required this.text,
    required this.done,
    required this.onToggle,
  });

  final String text;
  final bool done;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: done ? palette.mintSoft : palette.coralSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: done
                  ? Container(
                      key: const ValueKey(true),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: palette.mint,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 13,
                      ),
                    )
                  : Container(
                      key: const ValueKey(false),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: palette.coral.withValues(alpha: 0.55),
                          width: 2,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: palette.body,
                  decoration: done ? TextDecoration.lineThrough : null,
                  decorationColor: palette.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
