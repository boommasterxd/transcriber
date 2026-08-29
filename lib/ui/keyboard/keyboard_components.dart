part of 'keyboard_screen.dart';

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.state,
    required this.strings,
    required this.onBack,
  });

  final DictationState state;
  final AppStrings strings;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final provider = state.provider;
    final providerName = provider == null
        ? 'Transcriber'
        : RemoteCatalog.provider(provider).name;
    return Row(
      children: [
        Semantics(
          button: true,
          label: strings.keyboardSwitchBack,
          child: IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onBack,
            icon: const Icon(Icons.keyboard_alt_outlined),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                providerName,
                style: TextStyle(
                  color: context.palette.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              Text(
                state.modelId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.palette.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.state,
    required this.strings,
    required this.actions,
  });
  final DictationState state;
  final AppStrings strings;
  final _KeyboardActions actions;

  @override
  Widget build(BuildContext context) {
    if (state.isActive) return _activeControls();
    final canStart =
        state.phase == DictationPhase.ready ||
        state.phase == DictationPhase.error;
    final microphoneMissing =
        state.phase == DictationPhase.error &&
        state.errorCode == 'microphone_denied';
    return RecordStartControl(
      compact: true,
      onTap: canStart
          ? microphoneMissing
                ? actions.openAppSettings
                : actions.start
          : null,
      label: state.phase == DictationPhase.error
          ? strings.keyboardRetry
          : strings.keyboardReady,
    );
  }

  Widget _activeControls() => RecordControls(
    compact: true,
    paused: state.phase == DictationPhase.paused,
    strings: strings,
    onCancel: actions.cancel,
    onStop: actions.stop,
    onTogglePause: actions.togglePause,
    cancelEnabled: state.phase != DictationPhase.stopping,
    stopEnabled:
        state.phase != DictationPhase.connecting &&
        state.phase != DictationPhase.stopping,
    pauseEnabled:
        state.phase == DictationPhase.recording ||
        state.phase == DictationPhase.correcting ||
        state.phase == DictationPhase.paused,
  );
}

class _Timer extends StatelessWidget {
  const _Timer({required this.elapsed});
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Text(
      '$minutes:$seconds',
      style: AppTheme.mono(color: context.palette.muted),
    );
  }
}

String _statusText(DictationState state, AppStrings strings) {
  if (state.phase == DictationPhase.error) {
    return switch (state.errorCode) {
      'microphone_denied' => strings.keyboardMicMissing,
      'api_key_missing' => strings.keyboardKeyMissing,
      'authentication_failed' => strings.keyboardAuthenticationError,
      'quota_exceeded' => strings.keyboardQuotaError,
      'model_unavailable' ||
      'provider_access_denied' => strings.keyboardModelError,
      'configuration_rejected' => strings.keyboardConfigurationError,
      'connection_timeout' => strings.keyboardTimeoutError,
      _ => strings.keyboardConnectionError,
    };
  }
  return switch (state.phase) {
    DictationPhase.loading => strings.keyboardConnect,
    DictationPhase.ready => strings.keyboardReady,
    DictationPhase.connecting => strings.keyboardConnect,
    DictationPhase.recording => strings.keyboardRecording,
    DictationPhase.correcting => strings.keyboardCorrecting,
    DictationPhase.paused => strings.recPaused,
    DictationPhase.reconnecting => strings.keyboardReconnect,
    DictationPhase.stopping => strings.keyboardStopping,
    DictationPhase.unavailable => strings.keyboardSensitiveField,
    DictationPhase.error => strings.keyboardConnectionError,
  };
}
