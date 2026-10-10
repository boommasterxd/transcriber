import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';

/// Explains a partial processing result and exposes its persisted diagnostic.
class SummaryFailureNotice extends StatelessWidget {
  const SummaryFailureNotice({
    super.key,
    required this.error,
    required this.strings,
  });

  final String error;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.coralSoft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.summaryFailedTitle,
              style: TextStyle(fontWeight: FontWeight.w700, color: palette.ink),
            ),
            const SizedBox(height: 8),
            Text(
              strings.summaryFailedBody,
              style: TextStyle(color: palette.ink),
            ),
            const SizedBox(height: 12),
            SelectableText(error, style: TextStyle(color: palette.ink)),
          ],
        ),
      ),
    );
  }
}
