import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../data/catalog/remote_catalog.dart';
import '../../state/dictation_controller.dart';
import '../../state/dictation_state.dart';
import '../widgets/recording_controls.dart';
import '../widgets/provider_logo.dart';
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
      actions: KeyboardActions(
        start: controller.start,
        recording: RecordingActions(
          stop: controller.stop,
          togglePause: controller.togglePause,
          cancel: controller.cancel,
        ),
        deleteBackward: controller.deleteBackward,
        switchBack: controller.switchBack,
        openAppSettings: openAppSettings ?? controller.start,
      ),
    ),
  );
}

class KeyboardActions {
  const KeyboardActions({
    required this.start,
    required this.recording,
    required this.deleteBackward,
    required this.switchBack,
    required this.openAppSettings,
  });
  final VoidCallback start;
  final RecordingActions recording;
  VoidCallback get stop => recording.stop!;
  VoidCallback get togglePause => recording.togglePause!;
  VoidCallback get cancel => recording.cancel!;
  final VoidCallback deleteBackward;
  final VoidCallback switchBack;
  final VoidCallback openAppSettings;
}

class KeyboardView extends StatelessWidget {
  const KeyboardView({
    super.key,
    required this.state,
    required this.strings,
    required this.actions,
  });

  final DictationState state;
  final AppStrings strings;
  final KeyboardActions actions;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
          child: Column(
            children: [
              _TopBar(
                state: state,
                strings: strings,
                onBack: actions.switchBack,
                onDelete: actions.deleteBackward,
              ),
              const SizedBox(height: 4),
              Expanded(
                child: _StatusPanel(state: state, strings: strings),
              ),
              const SizedBox(height: 4),
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
      child: LayoutBuilder(
        builder: (context, constraints) => _StatusPanelContent(
          state: state,
          status: status,
          isError: isError,
          paused: paused,
          showWave: constraints.maxHeight >= 58,
        ),
      ),
    );
  }
}

class _StatusPanelContent extends StatelessWidget {
  const _StatusPanelContent({
    required this.state,
    required this.status,
    required this.isError,
    required this.paused,
    required this.showWave,
  });

  final DictationState state;
  final String status;
  final bool isError;
  final bool paused;
  final bool showWave;

  @override
  Widget build(BuildContext context) {
    if (state.phase == DictationPhase.connecting) {
      return _ConnectingStatus(status: status);
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _statusRow(),
        if (state.isActive && showWave) ...[
          const SizedBox(height: 4),
          Expanded(
            child: RecordWave(
              levels: state.levels.isEmpty ? _keyboardIdleLevels : state.levels,
              paused: paused,
              barWidth: 5,
            ),
          ),
        ],
      ],
    );
  }

  Widget _statusRow() => state.isActive
      ? _KeyboardActiveStatus(status: status, paused: paused)
      : _KeyboardStatusPill(status: status, isError: isError, paused: paused);
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
              maxLines: isError ? 3 : 1,
              overflow: isError ? null : TextOverflow.ellipsis,
              textAlign: TextAlign.center,
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
