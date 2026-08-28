import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../widgets/buttons.dart';

class AudioFileTile extends StatelessWidget {
  const AudioFileTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.line2, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: palette.shadow,
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const _AudioFileIcon(),
            const SizedBox(width: 14),
            Expanded(
              child: _AudioFileText(title: title, subtitle: subtitle),
            ),
            Icon(Icons.chevron_right_rounded, color: palette.faint),
          ],
        ),
      ),
    );
  }
}

class _AudioFileIcon extends StatelessWidget {
  const _AudioFileIcon();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.file_upload_outlined, color: palette.accent, size: 22),
    );
  }
}

class _AudioFileText extends StatelessWidget {
  const _AudioFileText({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            color: palette.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(fontSize: 12.5, color: palette.muted)),
      ],
    );
  }
}

class RecordFab extends StatelessWidget {
  const RecordFab({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.9,
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          color: palette.accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: palette.accent.withValues(alpha: 0.48),
              blurRadius: 32,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: const Icon(Icons.mic_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 64, 34, 0),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: palette.accentSoft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.graphic_eq_rounded,
              color: palette.accent,
              size: 32,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.5, color: palette.muted),
          ),
        ],
      ),
    );
  }
}
