import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'data/repositories/settings_repository.dart';
import 'state/providers.dart';
import 'state/settings_controller.dart';
import 'ui/screens/share/share_overlay_sheet.dart';

/// Channel shared with the native [ShareActivity] (translucent): hands over the
/// cached path of the shared audio and lets us finish the activity (returning
/// the user to the app they shared from).
const _channel = MethodChannel('app/share');

/// Bootstraps and renders the share overlay over a transparent window. Called
/// from `shareMain` in main.dart (which is the actual Dart entrypoint).
Future<void> runShareEntrypoint() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Receives the processing result from the foreground-service isolate.
  FlutterForegroundTask.initCommunicationPort();

  final prefs = await SharedPreferences.getInstance();
  final settingsRepo = SettingsRepository(prefs);
  final settings = await settingsRepo.load();
  final connections = await settingsRepo.connectedProviders();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        initialSettingsProvider.overrideWithValue(settings),
        initialConnectionsProvider.overrideWithValue(connections),
      ],
      child: const _ShareApp(),
    ),
  );
}

class _ShareApp extends ConsumerWidget {
  const _ShareApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsControllerProvider.select((s) => s.themeMode));
    final accent = ref.watch(settingsControllerProvider.select((s) => s.accent));
    final language = ref.watch(settingsControllerProvider.select((s) => s.language));

    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
      color: const Color(0x00000000),
      home: const _ShareHost(),
    );
  }
}

class _ShareHost extends ConsumerStatefulWidget {
  const _ShareHost();

  @override
  ConsumerState<_ShareHost> createState() => _ShareHostState();
}

class _ShareHostState extends ConsumerState<_ShareHost> {
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  /// Loads the shared path, then presents the overlay as a real modal bottom
  /// sheet — so it slides up from the bottom and supports drag-to-dismiss, just
  /// like the in-app overlay. Finishing the activity returns to the source app.
  Future<void> _open() async {
    if (_opened) return;
    _opened = true;
    String? path;
    try {
      path = await _channel.invokeMethod<String>('getInitialSharedPath');
    } catch (_) {
      path = null;
    }
    if (!mounted) return;
    if (path == null) {
      _finish();
      return;
    }
    final isTablet = MediaQuery.of(context).size.width >= 720;
    final sharedPath = path;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      constraints: isTablet ? const BoxConstraints(maxWidth: 600) : null,
      builder: (sheetCtx) => ShareSheetContent(
        audioPath: sharedPath,
        fileName: sharedPath.split('/').last,
        onFinished: () => Navigator.of(sheetCtx).pop(),
      ),
    );
    // Sheet dismissed (saved, closed, dragged or scrim-tapped) → close the
    // translucent activity and return to the app the audio was shared from.
    _finish();
  }

  void _finish() => _channel.invokeMethod('finish');

  @override
  Widget build(BuildContext context) {
    // The sheet itself is presented as a modal route above; the page is just a
    // transparent surface so the source app shows through behind the scrim.
    return const Scaffold(backgroundColor: Colors.transparent);
  }
}
