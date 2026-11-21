import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/toast.dart';
import 'state/notes_controller.dart';
import 'state/providers.dart';
import 'state/settings_controller.dart';
import 'ui/navigation.dart';
import 'ui/screens/home/audio_import_recovery_gate.dart';
import 'ui/screens/home/home_screen.dart';
import 'ui/screens/onboarding/onboarding_screen.dart';
import 'ui/screens/share/share_overlay_sheet.dart';
import 'ui/screens/share/widgets/transcriber_app_shell.dart';
import 'ui/screens/tablet/tablet_home_screen.dart';

/// Root widget: wires theme, localization and the share-intent listener.
class TranscriberApp extends ConsumerWidget {
  const TranscriberApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TranscriberAppShell(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: const _RootGate(),
    );
  }
}

/// Decides between onboarding and home, and bridges incoming share intents into
/// the processing flow.
class _RootGate extends ConsumerStatefulWidget {
  const _RootGate();

  @override
  ConsumerState<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends ConsumerState<_RootGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupShareIntents();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // The share entry point can persist a note through a separate Flutter
    // engine while this UI is paused.
    unawaited(_refreshNotes());
  }

  Future<void> _refreshNotes() async {
    try {
      await ref.read(notesControllerProvider.notifier).refresh();
    } on Object {
      if (mounted) {
        showAppToast(ref.read(stringsProvider).errorTitle, isError: true);
      }
    }
  }

  Future<void> _setupShareIntents() async {
    final service = ref.read(shareIntentServiceProvider);
    final initial = await service.initialSharedAudio();
    if (initial != null) await _handleShared(initial);
    service.listen(_handleShared);
  }

  Future<void> _handleShared(String path) async {
    // Shared/opened audio is processed in a modal overlay sheet so the result
    // can be previewed and explicitly saved.
    final imported = await ref
        .read(audioCacheManagerProvider)
        .importExternal(path);
    await ShareOverlay.show(
      audioPath: imported.path,
      fileName: path.split('/').last,
    );
  }

  @override
  Widget build(BuildContext context) {
    final onboarded = ref.watch(
      settingsControllerProvider.select((s) => s.onboarded),
    );
    return AudioImportRecoveryGate(
      ready: onboarded,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The setup wizard runs first on any device; afterwards wide screens use
          // the split-view, narrow ones the phone home.
          if (!onboarded) return const OnboardingScreen();
          final isTablet = constraints.maxWidth >= 720;
          return isTablet ? const TabletHomeScreen() : const HomeScreen();
        },
      ),
    );
  }
}
