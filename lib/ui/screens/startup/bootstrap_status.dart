import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/app_accent.dart';

/// Displays startup progress or recovery before persisted settings are available.
class BootstrapStatus extends StatelessWidget {
  const BootstrapStatus({
    super.key,
    required this.failed,
    required this.retry,
    this.close,
  });

  final bool failed;
  final VoidCallback retry;
  final Future<void> Function()? close;

  @override
  Widget build(BuildContext context) {
    final language = AppLanguage.fromCode(
      WidgetsBinding.instance.platformDispatcher.locale.languageCode,
    );
    final strings = AppStrings.of(language);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light, AppAccent.blue),
      darkTheme: AppTheme.build(Brightness.dark, AppAccent.blue),
      locale: Locale(language.code),
      supportedLocales: const [Locale('de'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: PopScope<void>(
        canPop: close == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(close?.call());
        },
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _actions(strings),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actions(AppStrings strings) {
    final dismiss = close;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (failed) ...[
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(strings.errorTitle),
          ),
          TextButton(onPressed: retry, child: Text(strings.retry)),
        ] else
          const CircularProgressIndicator(),
        if (dismiss != null)
          TextButton(onPressed: dismiss, child: Text(strings.actionClose)),
      ],
    );
  }
}
