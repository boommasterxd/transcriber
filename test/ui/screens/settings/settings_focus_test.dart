import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/ui/navigation.dart';
import 'package:transcriber/ui/screens/settings/widgets/provider_connect_card.dart';

import '../onboarding/onboarding_test_support.dart';
import 'settings_navigation_test_support.dart';

void main() {
  final strings = AppStrings.of(AppLanguage.de);
  for (final systemBack in [false, true]) {
    testWidgets('return from API keys keeps keyboard hidden ($systemBack)', (
      tester,
    ) async {
      await pumpSettingsNavigation(tester);
      await openSettingsDestination(tester, strings.setModels);
      await openSettingsDestination(tester, strings.providerConnectionsTitle);
      await tester.tap(find.byType(ProviderConnectCard).first);
      await tester.pumpAndSettle();
      await tester.showKeyboard(find.byType(TextField));
      expect(tester.testTextInput.isVisible, isTrue);
      await _back(tester, systemBack);
      expect(tester.testTextInput.isVisible, isFalse);
      await _back(tester, systemBack);
      expect(find.text(strings.setTitle), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
    });
  }

  testWidgets('hidden home search cannot regain focus during settings return', (
    tester,
  ) async {
    await pumpOnboardingTestApp(
      tester,
      config: const OnboardingTestConfig(
        connections: {RemoteProviderId.google: true},
      ),
      child: Scaffold(
        body: Column(
          children: [
            const TextField(key: ValueKey('home-search')),
            Builder(
              builder: (context) => IconButton(
                onPressed: () => AppNavigator.openSettings(context),
                icon: const Icon(Icons.settings),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.showKeyboard(find.byKey(const ValueKey('home-search')));
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await openSettingsDestination(tester, strings.setGeneral);
    await goBackInSettings(tester);
    expect(find.text(strings.setTitle), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
    await goBackInSettings(tester);
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.showKeyboard(find.byKey(const ValueKey('home-search')));
    expect(tester.testTextInput.isVisible, isTrue);
  });
}

Future<void> _back(WidgetTester tester, bool systemBack) async {
  if (systemBack) {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  } else {
    await goBackInSettings(tester);
  }
}
