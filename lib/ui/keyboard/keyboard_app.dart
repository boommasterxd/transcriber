import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/models/app_settings.dart';
import '../../data/repositories/settings_repository.dart';
import '../../services/dictation/dictation_platform.dart';
import '../../state/dictation_controller.dart';
import 'keyboard_screen.dart';

class KeyboardApp extends StatefulWidget {
  const KeyboardApp({
    super.key,
    required this.database,
    required this.settingsRepository,
    required this.initialSettings,
    this.platform,
  });

  final AppDatabase database;
  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;
  final DictationPlatform? platform;

  @override
  State<KeyboardApp> createState() => _KeyboardAppState();
}

class _KeyboardAppState extends State<KeyboardApp> with WidgetsBindingObserver {
  late AppSettings _settings = widget.initialSettings;
  late final DictationController _controller = DictationController(
    settingsRepository: widget.settingsRepository,
    platform: widget.platform ?? MethodChannelDictationPlatform(),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reloadSettings();
  }

  Future<void> _reloadSettings() async {
    final settings = await widget.settingsRepository.load();
    if (mounted) setState(() => _settings = settings);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    widget.database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.build(Brightness.light, _settings.accent),
    darkTheme: AppTheme.build(Brightness.dark, _settings.accent),
    themeMode: _settings.themeMode,
    home: KeyboardScreen(
      controller: _controller,
      strings: AppStrings.of(_settings.language),
      openAppSettings: const KeyboardSettingsPlatform().openAppSettings,
    ),
  );
}
