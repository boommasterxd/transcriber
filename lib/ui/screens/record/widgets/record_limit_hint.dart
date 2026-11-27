import 'package:material_ui/material_ui.dart';
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
    const warningSeconds = 60;
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
    final phase = boundary.failed
        ? _LimitPhase.failed
        : boundary.reached
        ? _LimitPhase.reached
        : remaining <= warningSeconds
        ? _LimitPhase.warning
        : _LimitPhase.normal;
    final text = switch (phase) {
      _LimitPhase.failed => strings.recFailure,
      _LimitPhase.reached => strings.recLimitReached,
      _LimitPhase.warning => strings.recLimitWarning(formatDuration(remaining)),
      _LimitPhase.normal => strings.recLimit(
        formatDuration(boundary.maxDurationSec),
      ),
    };
    return _LimitStatus(phase: phase, text: text);
  }
}

enum _LimitPhase { normal, warning, reached, failed }

class _LimitStatus extends StatefulWidget {
  const _LimitStatus({required this.phase, required this.text});

  final _LimitPhase phase;
  final String text;

  @override
  State<_LimitStatus> createState() => _LimitStatusState();
}

class _LimitStatusState extends State<_LimitStatus> {
  late bool _announce = widget.phase != _LimitPhase.normal;

  @override
  void didUpdateWidget(_LimitStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The countdown stays readable without interrupting TalkBack every second.
    _announce =
        widget.phase != _LimitPhase.normal && widget.phase != oldWidget.phase;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      container: true,
      liveRegion: _announce,
      child: Text(
        widget.text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          color: widget.phase == _LimitPhase.normal
              ? palette.muted
              : palette.coralInk,
        ),
      ),
    );
  }
}
