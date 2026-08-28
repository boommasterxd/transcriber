import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

/// One-line plain-language explanation of a stage (e.g. "Transcription =
/// speech → text"), shown above the stage controls.
class StageExplainer extends StatelessWidget {
  const StageExplainer({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Icon(Icons.info_outline_rounded, size: 15, color: palette.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.muted,
            ),
          ),
        ),
      ],
    );
  }
}
