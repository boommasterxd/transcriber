import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:transcriber/state/app_version_provider.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/ui/screens/settings/widgets/settings_version_footer.dart';

import '../../../support/app_test_fakes.dart';
import 'settings_test_app.dart';

void main() {
  testWidgets('displays installed package version and caches the read', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'Transcriber',
      packageName: 'test.transcriber',
      version: '2.4.1',
      buildNumber: '17',
      buildSignature: '',
    );
    await tester.pumpWidget(_footerApp());
    await tester.pumpAndSettle();
    expect(find.text('Transcriber · Version 2.4.1+17'), findsOneWidget);
    final element = tester.element(find.byType(SettingsVersionFooter));
    final container = ProviderScope.containerOf(element);
    expect(await container.read(appVersionProvider.future), '2.4.1+17');
  });

  testWidgets('keeps a loading footer and handles unavailable metadata', (
    tester,
  ) async {
    final version = Completer<String>();
    await tester.pumpWidget(_footerApp(version: version.future));
    expect(find.text('Transcriber'), findsOneWidget);
    version.completeError(StateError('Metadata unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Transcriber · Version nicht verfügbar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _footerApp({Future<String>? version}) => ProviderScope(
  overrides: [
    settingsControllerProvider.overrideWith(TestSettingsController.new),
    if (version != null) appVersionProvider.overrideWith((ref) => version),
  ],
  child: settingsTestApp(home: const Scaffold(body: SettingsVersionFooter())),
);
