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
        _Timer(elapsed: state.elapsed),
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
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: canStart
            ? microphoneMissing
                  ? actions.openAppSettings
                  : actions.start
            : null,
        icon: const Icon(Icons.mic_rounded),
        label: Text(
          state.phase == DictationPhase.error
              ? strings.keyboardRetry
              : strings.keyboardReady,
        ),
      ),
    );
  }

  Widget _activeControls() => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: state.phase == DictationPhase.stopping
              ? null
              : actions.cancel,
          icon: const Icon(Icons.close_rounded),
          label: Text(strings.keyboardCancel),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: FilledButton.icon(
          onPressed: state.phase == DictationPhase.stopping
              ? null
              : actions.stop,
          icon: const Icon(Icons.stop_rounded),
          label: Text(strings.keyboardStop),
        ),
      ),
    ],
  );
}

class _LiveWave extends StatelessWidget {
  const _LiveWave({required this.levels});
  final List<double> levels;

  @override
  Widget build(BuildContext context) {
    final values = levels.isEmpty ? const [0.08] : levels;
    return SizedBox(
      height: 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final level in values)
            Container(
              width: 3,
              height: 5 + level.clamp(0, 1) * 23,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: context.palette.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
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
    DictationPhase.reconnecting => strings.keyboardReconnect,
    DictationPhase.stopping => strings.keyboardStopping,
    DictationPhase.unavailable => strings.keyboardSensitiveField,
    DictationPhase.error => strings.keyboardConnectionError,
  };
}
