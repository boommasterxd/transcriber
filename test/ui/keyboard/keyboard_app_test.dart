import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/repositories/settings_repository.dart';
import 'package:transcriber/services/dictation/dictation_platform.dart';
import 'package:transcriber/ui/keyboard/keyboard_app.dart';
import 'package:transcriber/ui/keyboard/keyboard_screen.dart';

import '../../state/dictation_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('matches native navigation icons to the keyboard theme', (
    tester,
  ) async {
    final harness = await _pumpKeyboardApp(
      tester,
      AppSettings.initial().copyWith(themeMode: ThemeMode.light),
    );
    expect(harness.backgrounds, [true]);

    await harness.repository.save(
      AppSettings.initial().copyWith(themeMode: ThemeMode.dark),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(harness.backgrounds, [true, false]);
  });

  testWidgets('follows platform brightness in system theme mode', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final harness = await _pumpKeyboardApp(tester, AppSettings.initial());
    expect(harness.backgrounds, [true]);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();

    expect(harness.backgrounds, [true, false]);
  });

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

Future<({SettingsRepository repository, List<bool> backgrounds})>
_pumpKeyboardApp(WidgetTester tester, AppSettings settings) async {
  const channel = MethodChannel('test/keyboard/appearance');
  final backgrounds = <bool>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        backgrounds.add(call.arguments['lightBackground'] as bool);
        return true;
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  final database = AppDatabase(NativeDatabase.memory());
  final repository = SettingsRepository(database);
  final platform = FakeDictationPlatform();
  addTearDown(platform.close);
  await tester.pumpWidget(
    KeyboardApp(
      database: database,
      settingsRepository: repository,
      initialSettings: settings,
      platform: platform,
      settingsPlatform: const KeyboardSettingsPlatform(channel: channel),
    ),
  );
  await tester.pump();
  return (repository: repository, backgrounds: backgrounds);
}
