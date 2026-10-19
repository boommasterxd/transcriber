import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// A selectable row inside a [SurfaceCard]-style list (models, providers).
class ModelTile extends StatelessWidget {
  const ModelTile({
    super.key,
    required this.content,
    required this.trailing,
    this.onTap,
    this.leading,
    this.isLast = false,
  });

  final ModelTileContent content;
  final Widget trailing;
  final VoidCallback? onTap;
  final Widget? leading;
  final bool isLast;

  /// Optional small badge shown next to the title (e.g. "Empfohlen").
  String get title => content.title;
  String get subtitle => content.subtitle;
  Widget? get badge => content.badge;

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
            if (leading != null) ...[leading!, const SizedBox(width: 13)],
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

class ModelTileContent {
  const ModelTileContent({
    required this.title,
    required this.subtitle,
    this.badge,
  });

  final String title;
  final String subtitle;
  final Widget? badge;
}

class ModelTileLeading extends StatelessWidget {
  const ModelTileLeading({super.key, required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: color ?? context.palette.accentSoft2,
      borderRadius: BorderRadius.circular(11),
    ),
    child: Center(child: child),
  );
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
