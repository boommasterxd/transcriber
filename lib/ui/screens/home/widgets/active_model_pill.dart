import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

/// Small pill showing the active processing model; taps through to settings.
/// Turns into a coral warning state when a cloud stage isn't connected.
class ActiveModelPill extends StatelessWidget {
  const ActiveModelPill({
    super.key,
    required this.label,
    required this.onTap,
    this.activeText,
    this.warning = false,
  });

  final String label;
  final String? activeText;
  final VoidCallback onTap;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Flexible(
            child: _ModelStatusBadge(label: label, warning: warning),
          ),
          if (activeText != null) ...[
            const SizedBox(width: 10),
            Text(
              activeText!,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: context.palette.faint,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModelStatusBadge extends StatelessWidget {
  const _ModelStatusBadge({required this.label, required this.warning});

  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final indicatorColor = warning ? palette.coral : palette.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: warning ? palette.coralSoft : palette.accentSoft,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          warning
              ? Icon(
                  Icons.warning_amber_rounded,
                  size: 13,
                  color: indicatorColor,
                )
              : _StatusDot(color: indicatorColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: warning ? palette.coralInk : palette.accentDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
