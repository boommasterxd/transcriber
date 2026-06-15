import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

/// Small pill showing the active processing model; taps through to settings.
class ActiveModelPill extends StatelessWidget {
  const ActiveModelPill({
    super.key,
    required this.label,
    required this.activeText,
    required this.isLocal,
    required this.onTap,
  });

  final String label;
  final String activeText;
  final bool isLocal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                color: palette.accentSoft,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isLocal ? palette.mint : palette.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: palette.accentDeep,
                      ),
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
