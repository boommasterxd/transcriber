import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';

/// A selectable row inside a [SurfaceCard]-style list (models, providers).
class ModelTile extends StatelessWidget {
  const ModelTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
    this.leading,
    this.leadingColor,
    this.isLast = false,
    this.badge,
  });

  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;
  final Widget? leading;
  final Color? leadingColor;
  final bool isLast;

  /// Optional small badge shown next to the title (e.g. "Empfohlen").
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: palette.line)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            if (leading != null) ...[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: leadingColor ?? palette.accentSoft2,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(child: leading),
              ),
              const SizedBox(width: 13),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: palette.ink,
                          ),
                        ),
                      ),
                      if (badge != null) ...[const SizedBox(width: 8), badge!],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12.5, color: palette.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// Radio/checkmark selection indicator.
class SelectionIndicator extends StatelessWidget {
  const SelectionIndicator({super.key, required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (!selected) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: palette.line2, width: 2),
        ),
      );
    }
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(color: palette.accent, shape: BoxShape.circle),
      child: const Icon(Icons.check, color: Colors.white, size: 14),
    );
  }
}

/// "Laden / Get" download chip.
class DownloadChip extends StatelessWidget {
  const DownloadChip({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: palette.accentSoft,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_rounded, size: 14, color: palette.accentDeep),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: palette.accentDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular download progress shown while a model downloads.
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              value: progress <= 0 ? null : progress,
              strokeWidth: 3,
              backgroundColor: palette.accentSoft,
              valueColor: AlwaysStoppedAnimation(palette.accent),
            ),
          ),
          Text(
            '${(progress * 100).round()}',
            style: AppTheme.mono(
              color: palette.accent,
              size: 8,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
