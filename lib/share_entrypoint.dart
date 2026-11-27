import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_bootstrap.dart';
import 'core/toast.dart';
import 'services/storage/audio_cache_manager.dart';
import 'services/storage/managed_audio_file.dart';
import 'state/processing_controller.dart';
import 'state/providers.dart';
import 'state/settings_controller.dart';
import 'ui/screens/share/share_overlay_sheet.dart';
import 'ui/screens/share/widgets/transcriber_app_shell.dart';

/// Channel shared with the native [ShareActivity] (translucent): hands over the
/// cached path of the shared audio and lets us finish the activity (returning
/// the user to the app they shared from).
const _channel = MethodChannel('app/share');

/// Bootstraps and renders the share overlay over a transparent window. Called
/// from `shareMain` in main.dart (which is the actual Dart entrypoint).
Future<void> runShareEntrypoint({
  Future<AppBootstrapData> Function()? loadBootstrap,
}) {
  ManagedAudioFile? presentedAudio;
  return runBootstrappedApp(
    app: TranscriberAppShell(
      transparent: true,
      home: _ShareHost(onHandoff: (audio) => presentedAudio = audio),
    ),
    loadBootstrap: loadBootstrap,
    recoverPendingAudioDeletes: false,
    enforceAudioCacheQuota: false,
    shutdown: BootstrapShutdown(
      drain: (container) async {
        try {
          await _drainShareProcessing(container);
        } finally {
          if (presentedAudio case final audio?) {
            await _discardAudio(
              container.read(audioCacheManagerProvider),
              audio,
            );
          }
        }
      },
      finish: _finishActivity,
    ),
  );
}

Future<void> _drainShareProcessing(ProviderContainer container) async {
  try {
    if (container.read(processingControllerProvider.exists)) {
      await container.read(processingControllerProvider.notifier).close();
    }
  } finally {
    if (container.read(settingsControllerProvider.exists)) {
      await container.read(settingsControllerProvider.notifier).close();
    }
  }
}

Future<void> _finishActivity() async {
  try {
    await _channel.invokeMethod<bool>('finish');
  } on PlatformException {
    // The host may already have stopped handling the channel.
  } on MissingPluginException {
    // The host is already gone.
  }
}

Future<void> _discardAudio(
  AudioCacheManager cacheManager,
  ManagedAudioFile audio,
) async {
  try {
    await cacheManager.discard(audio);
  } catch (_) {
    // Native cache cleanup can retry after this engine closes.
  }
}

class _ShareHost extends ConsumerStatefulWidget {
  const _ShareHost({required this.onHandoff});

  final ValueChanged<ManagedAudioFile> onHandoff;

  @override
  ConsumerState<_ShareHost> createState() => _ShareHostState();
}

class _ShareHostState extends ConsumerState<_ShareHost> {
  late final Future<void> Function() _close;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _close = ref.read(closeBootstrappedAppProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_closing) unawaited(_open());
    });
  }

  /// Loads the shared path, then presents the overlay as a real modal bottom
  /// sheet, so it slides up from the bottom and supports drag-to-dismiss, just
  /// like the in-app overlay. Finishing the activity returns to the source app.
  Future<void> _open() async {
    final cacheManager = ref.read(audioCacheManagerProvider);
    String? path;
    var handedOff = false;
    try {
      path = await _channel.invokeMethod<String>('getInitialSharedPath');
      if (path == null || path.trim().isEmpty || !_canPresent) return;
      final audio = await cacheManager.registerShared(path);
      if (!mounted || _closing || _isDetached) return;
      widget.onHandoff(audio);
      handedOff = true;
      await presentShareSheet(
        context: context,
        audio: audio,
        fileName: path.split('/').last,
      );
    } catch (_) {
      // The source may disappear before the consent sheet is presented.
    } finally {
      if (!handedOff && path != null && path.trim().isNotEmpty) {
        await _discardAudio(
          cacheManager,
          ManagedAudioFile(path: path, ownership: AudioOwnership.temporary),
        );
      }
      if (mounted && !_isDetached) await _finish();
    }
  }

  bool get _canPresent => mounted && !_closing && !_isDetached;

  bool get _isDetached =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.detached;

  Future<void> _finish() async {
    if (_closing) return;
    _closing = true;
    await _close();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsWriteErrorProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _closing) return;
        showAppToast(
          ref.read(stringsProvider).errorTitle,
          isError: true,
          messenger: ScaffoldMessenger.of(context),
        );
      });
    });
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_finish());
      },
      child: const Scaffold(backgroundColor: Colors.transparent),
    );
  }
}
