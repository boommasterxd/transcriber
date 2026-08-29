part of 'keyboard_screen.dart';

final _keyboardIdleLevels = List<double>.filled(
  DictationController.maximumLevels,
  DictationController.initialWaveformLevel,
  growable: false,
);

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.state,
    required this.strings,
    required this.onBack,
    required this.onDelete,
  });

  final DictationState state;
  final AppStrings strings;
  final VoidCallback onBack;
  final VoidCallback onDelete;

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
            tooltip: strings.keyboardSwitchBack,
            onPressed: onBack,
            icon: provider == null
                ? const Icon(Icons.graphic_eq_rounded)
                : ProviderLogo(provider: provider, size: 34),
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
        if (state.isActive) ...[
          const SizedBox(width: 6),
          _Timer(elapsed: state.elapsed),
          const SizedBox(width: 2),
        ],
        Semantics(
          button: true,
          label: strings.keyboardDeleteCharacter,
          child: IconButton(
            tooltip: strings.keyboardDeleteCharacter,
            onPressed: onDelete,
            icon: const Icon(Icons.backspace_outlined),
          ),
        ),
      ],
    );
  }
}

class _KeyboardActiveStatus extends StatelessWidget {
  const _KeyboardActiveStatus({required this.status, required this.paused});

  final String status;
  final bool paused;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: paused ? context.palette.faint : context.palette.mint,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          status,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.palette.muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
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
    if (state.phase == DictationPhase.connecting) {
      return _ConnectionCancelControl(
        label: strings.keyboardCancel,
        onCancel: actions.cancel,
      );
    }
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

class _ConnectionCancelControl extends StatelessWidget {
  const _ConnectionCancelControl({required this.label, required this.onCancel});

  final String label;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Center(
    child: OutlinedButton.icon(
      onPressed: onCancel,
      icon: const Icon(Icons.close_rounded, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: context.palette.body,
        minimumSize: const Size(152, 48),
        side: BorderSide(color: context.palette.line2),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class _ConnectingStatus extends StatelessWidget {
  const _ConnectingStatus({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox.square(
          dimension: 30,
          child: CircularProgressIndicator(
            value: animationsDisabled ? 0.7 : null,
            strokeWidth: 3,
            color: context.palette.accent,
            backgroundColor: context.palette.accentSoft,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          status,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.palette.ink,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: context.palette.chip,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$minutes:$seconds',
        style: AppTheme.mono(
          color: context.palette.muted,
        ).copyWith(fontSize: 11),
      ),
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
