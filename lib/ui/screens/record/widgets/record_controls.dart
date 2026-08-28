import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';

/// Bottom actions for discarding, stopping and pausing a recording.
class RecordControls extends StatelessWidget {
  const RecordControls({
    super.key,
    required this.paused,
    required this.strings,
    required this.onCancel,
    required this.onStop,
    required this.onTogglePause,
  });

  final bool paused;
  final AppStrings strings;
  final VoidCallback onCancel;
  final VoidCallback onStop;
  final VoidCallback onTogglePause;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 16, 36, 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _RecordAction(
            icon: Icons.delete_outline_rounded,
            label: strings.recCancel,
            color: context.palette.coralInk,
            onTap: onCancel,
          ),
          _RecordStopAction(label: strings.recStopShort, onTap: onStop),
          _RecordAction(
            icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            label: paused ? strings.recResume : strings.recPause,
            color: context.palette.body,
            onTap: onTogglePause,
          ),
        ],
      ),
    );
  }
}

class _RecordStopAction extends StatelessWidget {
  const _RecordStopAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: palette.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: palette.accent.withValues(alpha: 0.45),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: palette.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordAction extends StatelessWidget {
  const _RecordAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: palette.chip,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.muted,
            ),
          ),
        ],
      ),
    );
  }
}
