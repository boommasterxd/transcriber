import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../data/catalog/remote_catalog.dart';
import '../../state/dictation_controller.dart';
import '../../state/dictation_state.dart';
import '../widgets/recording_controls.dart';
import '../widgets/waveforms.dart';

part 'keyboard_components.dart';

class KeyboardScreen extends StatelessWidget {
  const KeyboardScreen({
    super.key,
    required this.controller,
    required this.strings,
    this.openAppSettings,
  });

  final DictationController controller;
  final AppStrings strings;
  final VoidCallback? openAppSettings;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => KeyboardView(
      state: controller.state,
      strings: strings,
      start: controller.start,
      stop: controller.stop,
      togglePause: controller.togglePause,
      cancel: controller.cancel,
      switchBack: controller.switchBack,
      openAppSettings: openAppSettings ?? controller.start,
    ),
  );
}

class _KeyboardActions {
  const _KeyboardActions({
    required this.start,
    required this.stop,
    required this.togglePause,
    required this.cancel,
    required this.switchBack,
    required this.openAppSettings,
  });
  final VoidCallback start;
  final VoidCallback stop;
  final VoidCallback togglePause;
  final VoidCallback cancel;
  final VoidCallback switchBack;
  final VoidCallback openAppSettings;
}

class KeyboardView extends StatelessWidget {
  const KeyboardView({
    super.key,
    required this.state,
    required this.strings,
    required this.start,
    required this.stop,
    required this.togglePause,
    required this.cancel,
    required this.switchBack,
    required this.openAppSettings,
  });

  final DictationState state;
  final AppStrings strings;
  final VoidCallback start;
  final VoidCallback stop;
  final VoidCallback togglePause;
  final VoidCallback cancel;
  final VoidCallback switchBack;
  final VoidCallback openAppSettings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final actions = _KeyboardActions(
      start: start,
      stop: stop,
      togglePause: togglePause,
      cancel: cancel,
      switchBack: switchBack,
      openAppSettings: openAppSettings,
    );
    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
          child: Column(
            children: [
              _TopBar(
                state: state,
                strings: strings,
                onBack: actions.switchBack,
              ),
              const SizedBox(height: 6),
              Expanded(
                child: _StatusPanel(state: state, strings: strings),
              ),
              const SizedBox(height: 6),
              _Controls(state: state, strings: strings, actions: actions),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.state, required this.strings});
  final DictationState state;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final status = _statusText(state, strings);
    final isError =
        state.phase == DictationPhase.error ||
        state.phase == DictationPhase.unavailable;
    final paused = state.phase == DictationPhase.paused;
    return Semantics(
      liveRegion: true,
      label: status,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isError ? context.palette.coral : context.palette.line2,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => _StatusPanelContent(
            state: state,
            status: status,
            isError: isError,
            paused: paused,
            compact: constraints.maxHeight < 112,
            showWave: constraints.maxHeight >= 58,
          ),
        ),
      ),
    );
  }

  static const _idleLevels = <double>[0.08, 0.12, 0.08, 0.16, 0.1, 0.14, 0.08];
}

class _StatusPanelContent extends StatelessWidget {
  const _StatusPanelContent({
    required this.state,
    required this.status,
    required this.isError,
    required this.paused,
    required this.compact,
    required this.showWave,
  });

  final DictationState state;
  final String status;
  final bool isError;
  final bool paused;
  final bool compact;
  final bool showWave;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: _KeyboardStatusPill(
              status: status,
              isError: isError,
              paused: paused,
            ),
          ),
          if (state.isActive) ...[
            const SizedBox(width: 10),
            _Timer(elapsed: state.elapsed),
          ],
        ],
      ),
      if (state.isActive && showWave) ...[
        const SizedBox(height: 3),
        RecordWave(
          levels: state.levels.isEmpty
              ? _StatusPanel._idleLevels
              : state.levels,
          paused: paused,
          height: compact ? 22 : 28,
          barWidth: 3,
        ),
      ],
      if (!compact && state.preview.isNotEmpty) ...[
        const SizedBox(height: 2),
        Text(
          state.preview,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.palette.body, fontSize: 13),
        ),
      ],
    ],
  );
}

class _KeyboardStatusPill extends StatelessWidget {
  const _KeyboardStatusPill({
    required this.status,
    required this.isError,
    required this.paused,
  });

  final String status;
  final bool isError;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground = isError
        ? palette.coralInk
        : paused
        ? palette.muted
        : palette.ink;
    final dot = isError
        ? palette.coral
        : paused
        ? palette.faint
        : palette.mint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isError ? palette.coralSoft : palette.chip,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
