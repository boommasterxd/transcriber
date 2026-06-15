import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

/// Small pill showing the active processing model; taps through to settings.
/// Turns into a coral warning state when a cloud stage isn't connected.
class ActiveModelPill extends StatelessWidget {
  const ActiveModelPill({
    super.key,
    required this.label,
    required this.activeText,
    required this.isLocal,
    required this.onTap,
    this.warning = false,
  });

  final String label;
  final String activeText;
  final bool isLocal;
  final VoidCallback onTap;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bg = warning ? palette.coralSoft : palette.accentSoft;
    final fg = warning ? palette.coralInk : palette.accentDeep;
    final dot = warning ? palette.coral : (isLocal ? palette.mint : palette.accent);

    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9999)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  warning
                      ? Icon(Icons.warning_amber_rounded, size: 13, color: dot)
                      : Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                        ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: fg),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            activeText,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: palette.faint),
          ),
        ],
      ),
    );
  }
}
