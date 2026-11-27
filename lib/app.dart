import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/toast.dart';
import 'state/notes_controller.dart';
import 'state/settings_controller.dart';
import 'ui/navigation.dart';
import 'ui/screens/home/audio_import_recovery_gate.dart';
import 'ui/screens/home/home_screen.dart';
import 'ui/screens/onboarding/onboarding_screen.dart';
import 'ui/screens/share/widgets/transcriber_app_shell.dart';
import 'ui/screens/tablet/tablet_home_screen.dart';

class TranscriberApp extends ConsumerWidget {
  const TranscriberApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(settingsWriteErrorProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          showAppToast(ref.read(stringsProvider).errorTitle, isError: true);
        }
      });
    });
    return TranscriberAppShell(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: const _RootGate(),
    );
  }
}

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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_refreshOnResume());
  }

  Future<void> _refreshOnResume() async {
    try {
      await Future.wait<void>([
        ref.read(settingsControllerProvider.notifier).refresh(),
        ref.read(notesControllerProvider.notifier).refresh(),
      ]);
    } on Object {
      if (mounted) {
        showAppToast(ref.read(stringsProvider).errorTitle, isError: true);
      }
    }
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
          final isTablet = constraints.maxWidth >= AppTheme.tabletMinWidth;
          return isTablet ? const TabletHomeScreen() : const HomeScreen();
        },
      ),
    );
  }
}
