import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_theme.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';

import '../../support/app_test_fakes.dart';

final class FakeKeyboardSettingsChannel {
  FakeKeyboardSettingsChannel(
    this.channel, {
    this.enabled = false,
    this.selected = false,
  });

  final MethodChannel channel;
  final List<String> methods = [];
  bool enabled;
  bool selected;

  void install() => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .setMockMethodCallHandler(channel, _handle);

  void uninstall() => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);

  Future<Object?> _handle(MethodCall call) async {
    methods.add(call.method);
    switch (call.method) {
      case 'getStatus':
        return {'enabled': enabled, 'selected': selected};
      case 'openInputMethodSettings':
        enabled = true;
      case 'showInputMethodPicker':
        selected = true;
    }
    return true;
  }
}

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
