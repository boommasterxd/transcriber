import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'data/models/transcript_note.dart';
import 'state/settings_controller.dart';
import 'state/providers.dart';
import 'ui/navigation.dart';
import 'ui/screens/home/home_screen.dart';
import 'ui/screens/onboarding/onboarding_screen.dart';

/// Root widget: wires theme, localization and the share-intent listener.
class TranscriberApp extends ConsumerWidget {
  const TranscriberApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = ref.watch(settingsControllerProvider.select((s) => s.brightness));
    final accent = ref.watch(settingsControllerProvider.select((s) => s.accent));
    final language = ref.watch(settingsControllerProvider.select((s) => s.language));

    return MaterialApp(
      title: 'Transcriber',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.build(Brightness.light, accent),
      darkTheme: AppTheme.build(Brightness.dark, accent),
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
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

class _RootGateState extends ConsumerState<_RootGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupShareIntents());
  }

  Future<void> _setupShareIntents() async {
    final service = ref.read(shareIntentServiceProvider);
    final initial = await service.initialSharedAudio();
    if (initial != null) _handleShared(initial);
    service.listen(_handleShared);
  }

  void _handleShared(String path) {
    AppNavigator.startProcessingFromRoot(
      audioPath: path,
      source: NoteSource.shared,
      fileName: path.split('/').last,
    );
  }

  @override
  Widget build(BuildContext context) {
    final onboarded = ref.watch(settingsControllerProvider.select((s) => s.onboarded));
    // Touch strings so the widget rebuilds on language change.
    ref.watch(stringsProvider.select((AppStrings s) => s.language));
    return onboarded ? const HomeScreen() : const OnboardingScreen();
  }
}
