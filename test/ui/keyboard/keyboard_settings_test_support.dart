import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_theme.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';

import '../../support/app_test_fakes.dart';

Future<void> pumpKeyboardSettingsSurface(
  WidgetTester tester, {
  required Widget child,
}) async {
  final database = testDatabase();
  addTearDown(database.close);
  final settings = AppSettings.initial().copyWith(
    asrProvider: RemoteProviderId.google,
    onboarded: true,
  );
  await tester.pumpWidget(
    appScope(
      database: database,
      settings: settings,
      child: MaterialApp(
        theme: AppTheme.build(Brightness.light, AppAccent.blue),
        home: child,
      ),
    ),
  );
  await tester.pump();
}
