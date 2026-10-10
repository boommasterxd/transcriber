import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// One option in an [AnimatedSegmentedControl].
class SegmentOption {
  const SegmentOption(this.label, {this.icon});
  final String label;
  final IconData? icon;
}

/// A full-width segmented control whose white selection "thumb" slides
/// horizontally between options (no ink ripple). Used for theme, language and
/// provider and language selectors.
class AnimatedSegmentedControl extends StatelessWidget {
  const AnimatedSegmentedControl({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    this.height = 44,
  });

  final List<SegmentOption> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final n = options.length;
    final alignX = n <= 1 ? 0.0 : -1 + 2 * (selectedIndex / (n - 1));

    return Container(
      constraints: BoxConstraints(minHeight: height),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.chip,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Stack(
        children: [
          // Sliding thumb.
          Positioned.fill(
            child: AnimatedAlign(
              alignment: Alignment(alignX, 0),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(9999),
                    boxShadow: [
                      BoxShadow(
                        color: palette.shadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: _Segment(
                      option: options[i],
                      selected: i == selectedIndex,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.option, required this.selected});

  final SegmentOption option;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = selected ? palette.accent : palette.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (option.icon != null) ...[
            Icon(option.icon, size: 15, color: color),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              child: Text(option.label, textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }
}
