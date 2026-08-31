import 'dart:async';

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
    this.settingsPlatform = const KeyboardSettingsPlatform(),
  });

  final AppDatabase database;
  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;
  final DictationPlatform? platform;
  final KeyboardSettingsPlatform settingsPlatform;

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
    unawaited(_initializeController());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reloadSettings();
  }

  Future<void> _reloadSettings() async {
    try {
      final settings = await widget.settingsRepository.load();
      if (mounted) setState(() => _settings = settings);
    } catch (_) {
      // Preserve the last usable keyboard theme and language on storage errors.
    }
  }

  Future<void> _initializeController() async {
    try {
      await _controller.initialize();
    } catch (_) {
      // The Flutter surface must remain mounted while Android restores the IME.
    }
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
    builder: (context, child) => _KeyboardAppearance(
      platform: widget.settingsPlatform,
      child: child ?? const SizedBox.shrink(),
    ),
    home: KeyboardScreen(
      controller: _controller,
      strings: AppStrings.of(_settings.language),
      openAppSettings: widget.settingsPlatform.openAppSettings,
    ),
  );
}

class _KeyboardAppearance extends StatefulWidget {
  const _KeyboardAppearance({required this.platform, required this.child});

  final KeyboardSettingsPlatform platform;
  final Widget child;

  @override
  State<_KeyboardAppearance> createState() => _KeyboardAppearanceState();
}

class _KeyboardAppearanceState extends State<_KeyboardAppearance> {
  Brightness? _lastBrightness;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _synchronize(Theme.of(context).brightness);
  }

  @override
  void didUpdateWidget(covariant _KeyboardAppearance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.platform == widget.platform) return;
    _lastBrightness = null;
    _synchronize(Theme.of(context).brightness);
  }

  void _synchronize(Brightness brightness) {
    if (_lastBrightness == brightness) return;
    _lastBrightness = brightness;
    unawaited(_setLightNavigationBar(brightness == Brightness.light));
  }

  Future<void> _setLightNavigationBar(bool lightBackground) async {
    try {
      await widget.platform.setLightNavigationBar(lightBackground);
    } on Exception {
      // Keep the keyboard available if an older native host lacks this method.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
