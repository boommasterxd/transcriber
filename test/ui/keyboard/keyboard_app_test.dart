import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/repositories/settings_repository.dart';
import 'package:transcriber/ui/keyboard/keyboard_app.dart';
import 'package:transcriber/ui/keyboard/keyboard_screen.dart';

import '../../state/dictation_test_support.dart';

void main() {
  testWidgets('keeps the keyboard surface mounted when settings reload fails', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    final repository = SettingsRepository(database);
    final platform = FakeDictationPlatform();
    addTearDown(platform.close);
    await database.close();

    await tester.pumpWidget(
      KeyboardApp(
        database: database,
        settingsRepository: repository,
        initialSettings: AppSettings.initial(),
        platform: platform,
      ),
    );
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byType(KeyboardScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
