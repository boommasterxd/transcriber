import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../state/recording_controller.dart';

/// Shows the model-specific cap and keeps completed audio under user control.
class RecordLimitHint extends ConsumerWidget {
  const RecordLimitHint({super.key, required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boundary = ref.watch(
      recordingControllerProvider.select((state) => state.boundary),
    );
    final elapsed = ref.watch(
      recordingControllerProvider.select((state) => state.elapsedSec),
    );
    if (boundary.maxDurationSec == 0) return const SizedBox.shrink();
    final remaining = (boundary.maxDurationSec - elapsed).clamp(
      0,
      boundary.maxDurationSec,
    );
    final warning = remaining <= 60;
    final text = boundary.failed
        ? strings.recFailure
        : boundary.reached
        ? strings.recLimitReached
        : warning
        ? strings.recLimitWarning(formatDuration(remaining))
        : strings.recLimit(formatDuration(boundary.maxDurationSec));
    return Semantics(
      liveRegion: boundary.reached || boundary.failed,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          color: warning || boundary.failed
              ? context.palette.coralInk
              : context.palette.muted,
        ),
      ),
    );
  }
}
