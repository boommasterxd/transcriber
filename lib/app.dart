import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/l10n/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'core/toast.dart';
import 'state/settings_controller.dart';
import 'state/providers.dart';
import 'ui/navigation.dart';
import 'ui/screens/home/home_screen.dart';
import 'ui/screens/onboarding/onboarding_screen.dart';
import 'ui/screens/onboarding/widgets/onboarding_permissions_step.dart';
import 'ui/screens/share/share_overlay_sheet.dart';
import 'ui/screens/tablet/tablet_home_screen.dart';

/// Root widget: wires theme, localization and the share-intent listener.
class TranscriberApp extends ConsumerWidget {
  const TranscriberApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsControllerProvider.select((s) => s.themeMode));
    final accent = ref.watch(settingsControllerProvider.select((s) => s.accent));
    final language = ref.watch(settingsControllerProvider.select((s) => s.language));

    return MaterialApp(
      title: 'Transcriber',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.build(Brightness.light, accent),
      darkTheme: AppTheme.build(Brightness.dark, accent),
      themeMode: themeMode,
      locale: Locale(language.code),
      supportedLocales: const [Locale('de'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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

class _RootGateState extends ConsumerState<_RootGate> with WidgetsBindingObserver {
  // null while the first permission check is in flight; afterwards true/false.
  bool? _permissionsGranted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupShareIntents();
    });
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check on resume so revoking access in system settings pushes the user
    // back into setup the next time they return to the app.
    if (state == AppLifecycleState.resumed) _checkPermissions();
  }

  /// Setup is only "done" when the wizard was finished AND the microphone and
  /// notification permissions are still granted; otherwise we force the wizard.
  Future<void> _checkPermissions() async {
    final mic = await Permission.microphone.isGranted;
    final notif = await Permission.notification.isGranted;
    if (!mounted) return;
    setState(() => _permissionsGranted = mic && notif);
  }

  Future<void> _setupShareIntents() async {
    final service = ref.read(shareIntentServiceProvider);
    final initial = await service.initialSharedAudio();
    if (initial != null) _handleShared(initial);
    service.listen(_handleShared);
  }

  void _handleShared(String path) {
    // Shared/opened audio is processed in a modal overlay sheet so the result
    // can be previewed and explicitly saved.
    ShareOverlay.show(audioPath: path, fileName: path.split('/').last);
  }

  @override
  Widget build(BuildContext context) {
    final onboarded = ref.watch(settingsControllerProvider.select((s) => s.onboarded));
    // Touch strings so the widget rebuilds on language change.
    ref.watch(stringsProvider.select((AppStrings s) => s.language));

    // When permissions are granted inside the wizard the app never backgrounds,
    // so re-read the OS status here too — otherwise a user forced back into
    // setup by a revoked permission could get stuck after re-granting it.
    ref.listen<bool>(onboardingPermissionsReadyProvider, (_, next) {
      if (next) _checkPermissions();
    });

    // Force the wizard if it was never finished, or if the required permissions
    // are no longer granted (revoked in system settings, etc.). While the first
    // check is pending we keep showing the wizard for a not-yet-onboarded user
    // and the home for an onboarded one — no flicker in the common case.
    final needsSetup = !onboarded || _permissionsGranted == false;

    return LayoutBuilder(
      builder: (context, constraints) {
        // The setup wizard runs first on any device; afterwards wide screens use
        // the split-view, narrow ones the phone home.
        if (needsSetup) return const OnboardingScreen();
        final isTablet = constraints.maxWidth >= 720;
        return isTablet ? const TabletHomeScreen() : const HomeScreen();
      },
    );
  }
}
