import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_mode.dart';
import '../../../../state/settings_controller.dart';

/// Shared theme and localization shell for the main and translucent apps.
class TranscriberAppShell extends ConsumerWidget {
  const TranscriberAppShell({
    super.key,
    required this.home,
    this.navigatorKey,
    this.scaffoldMessengerKey,
    this.transparent = false,
  });

  final Widget home;
  final GlobalKey<NavigatorState>? navigatorKey;
  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;
  final bool transparent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(
      settingsControllerProvider.select((settings) => settings.themeMode),
    );
    final accent = ref.watch(
      settingsControllerProvider.select((settings) => settings.accent),
    );
    final language = ref.watch(
      settingsControllerProvider.select((settings) => settings.language),
    );

    return MaterialApp(
      title: transparent ? '' : 'Transcriber',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.build(Brightness.light, accent),
      darkTheme: AppTheme.build(Brightness.dark, accent),
      themeMode: themeMode.flutterThemeMode,
      locale: Locale(language.code),
      supportedLocales: const [Locale('de'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      color: transparent ? Colors.transparent : null,
      home: home,
    );
  }
}
