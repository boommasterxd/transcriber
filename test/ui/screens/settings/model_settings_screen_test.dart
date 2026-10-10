import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/ui/widgets/provider_logo.dart';

import 'settings_navigation_test_support.dart';

void main() {
  testWidgets('stage choices survive provider and page changes independently', (
    tester,
  ) async {
    final strings = AppStrings.of(AppLanguage.de);
    final container = await pumpSettingsNavigation(tester);
    await openSettingsDestination(tester, strings.setModels);
    await _select(tester, 'transcription', 'OpenAI', 'openai-model');
    var settings = container.read(settingsControllerProvider);
    expect(settings.asrProvider, RemoteProviderId.openai);
    expect(settings.summaryProvider, RemoteProviderId.google);
    expect(settings.asrModelId(RemoteProviderId.openai), 'openai-model');
    await _select(tester, 'summary', 'Google Gemini', 'google-model');
    await _select(tester, 'summary', 'OpenAI', 'openai-model');
    settings = container.read(settingsControllerProvider);
    expect(settings.summaryProvider, RemoteProviderId.openai);
    expect(settings.summaryModelId(RemoteProviderId.openai), 'openai-model');
    expect(settings.summaryModelId(RemoteProviderId.google), 'google-model');
    expect(settings.asrModelId(RemoteProviderId.openai), 'openai-model');
    await _select(tester, 'summary', 'Google Gemini', 'google-model');
    await openSettingsDestination(tester, strings.providerConnectionsTitle);
    await goBackInSettings(tester);
    await goBackInSettings(tester);
    await openSettingsDestination(tester, strings.setModels);
    expect(find.text('openai-model'), findsOneWidget);
    expect(find.text('google-model'), findsOneWidget);
    expect(_logo(tester, 'transcription').provider, RemoteProviderId.openai);
    expect(_logo(tester, 'summary').provider, RemoteProviderId.google);
  });
}

ProviderLogo _logo(WidgetTester tester, String stage) =>
    tester.widget<ProviderLogo>(
      find.descendant(
        of: find.byKey(Key('model-row-$stage')),
        matching: find.byType(ProviderLogo),
      ),
    );

Future<void> _select(
  WidgetTester tester,
  String stage,
  String provider,
  String model,
) async {
  final row = find.byKey(Key('model-row-$stage'));
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
  await tester.tap(find.text(provider).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(model).last);
  await tester.pumpAndSettle();
}
