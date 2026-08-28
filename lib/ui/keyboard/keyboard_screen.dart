import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../data/catalog/remote_catalog.dart';
import '../../state/dictation_controller.dart';
import '../../state/dictation_state.dart';

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
    required this.cancel,
    required this.switchBack,
    required this.openAppSettings,
  });
  final VoidCallback start;
  final VoidCallback stop;
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
    required this.cancel,
    required this.switchBack,
    required this.openAppSettings,
  });

  final DictationState state;
  final AppStrings strings;
  final VoidCallback start;
  final VoidCallback stop;
  final VoidCallback cancel;
  final VoidCallback switchBack;
  final VoidCallback openAppSettings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final actions = _KeyboardActions(
      start: start,
      stop: stop,
      cancel: cancel,
      switchBack: switchBack,
      openAppSettings: openAppSettings,
    );
    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            children: [
              _TopBar(
                state: state,
                strings: strings,
                onBack: actions.switchBack,
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _StatusPanel(state: state, strings: strings),
              ),
              const SizedBox(height: 10),
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
    return Semantics(
      liveRegion: true,
      label: status,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isError ? context.palette.coral : context.palette.line2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              status,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isError ? context.palette.coralInk : context.palette.ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (state.isActive) ...[
              const SizedBox(height: 10),
              _LiveWave(levels: state.levels),
            ],
            if (state.preview.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                state.preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.palette.body, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
