import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'data/repositories/settings_repository.dart';
import 'state/providers.dart';
import 'state/settings_controller.dart';
import 'ui/screens/share/share_overlay_sheet.dart';

/// Channel shared with the native [ShareActivity] (translucent). It hands over
/// the cached path of the shared audio and lets us finish the activity (which
/// returns the user to the app they shared from).
const _channel = MethodChannel('app/share');

/// Second Flutter entry point, run by the translucent `ShareActivity`. It renders
/// only the share overlay over a transparent window, so the app the user shared
/// from stays visible behind a dimmed scrim — the "see-through" share flow.
@pragma('vm:entry-point')
Future<void> shareMain() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Receives the processing result from the foreground-service isolate.
  FlutterForegroundTask.initCommunicationPort();

  final prefs = await SharedPreferences.getInstance();
  final settingsRepo = SettingsRepository(prefs);
  final settings = await settingsRepo.load();
  final connections = await settingsRepo.connectedProviders();

  try {
    await FlutterGemma.initialize(
      huggingFaceToken: settings.hfToken.isEmpty ? null : settings.hfToken,
    );
  } catch (_) {
    // Best-effort, mirrors main().
  }

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
      // Transparent so the source app shows through behind the dimmed scrim.
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
  String? _path;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _loadPath();
  }

  Future<void> _loadPath() async {
    String? path;
    try {
      path = await _channel.invokeMethod<String>('getInitialSharedPath');
    } catch (_) {
      path = null;
    }
    if (!mounted) return;
    setState(() {
      _path = path;
      _resolved = true;
    });
    // Nothing usable was shared — close immediately rather than show an empty
    // sheet over the other app.
    if (path == null) _finish();
  }

  void _finish() {
    _channel.invokeMethod('finish');
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;
    final isTablet = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Dimmed scrim; tapping it (outside the sheet) dismisses the overlay.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _finish,
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
          ),
          if (_resolved && path != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isTablet ? 600 : double.infinity),
                child: ShareSheetContent(
                  audioPath: path,
                  fileName: path.split('/').last,
                  onFinished: _finish,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
