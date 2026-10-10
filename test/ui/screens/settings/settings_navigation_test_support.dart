import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/remote/remote_api_client.dart';
import 'package:transcriber/state/connections_controller.dart';
import 'package:transcriber/state/providers.dart';
import 'package:transcriber/state/remote_models_provider.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/ui/screens/settings/settings_screen.dart';

import '../../../support/app_test_fakes.dart';
import 'settings_test_app.dart';

Future<ProviderContainer> pumpSettingsNavigation(
  WidgetTester tester, {
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final database = testDatabase();
  addTearDown(database.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        settingsControllerProvider.overrideWith(TestSettingsController.new),
        connectionsControllerProvider.overrideWith(_NavigationConnections.new),
        remoteModelsProvider.overrideWith(
          (ref, query) async => [
            RemoteModelInfo(id: '${query.provider.name}-model'),
          ],
        ),
      ],
      child: settingsTestApp(
        textScaler: textScaler,
        home: const SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
}

Future<void> openSettingsDestination(WidgetTester tester, String title) async {
  final destination = find.text(title);
  await tester.ensureVisible(destination);
  await tester.pumpAndSettle();
  await tester.tap(destination);
  await tester.pumpAndSettle();
}

Future<void> goBackInSettings(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
}

class _NavigationConnections extends ConnectionsController {
  @override
  Map<RemoteProviderId, bool> build() => {
    for (final provider in RemoteProviderId.values) provider: true,
  };

  @override
  Future<String> apiKey(RemoteProviderId provider) async => '';
}
