import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/state/settings_controller.dart';

import 'onboarding_test_support.dart';

void main() {
  useGrantedOnboardingPermissions();
  testWidgets('wizard traverses six sequential screens and completes setup', (
    tester,
  ) async {
    final strings = AppStrings.of(AppLanguage.de);
    final container = await openOnboardingStep(
      tester,
      1,
      config: const OnboardingTestConfig(
        connections: {RemoteProviderId.google: true},
      ),
    );
    expect(find.text(strings.obConnectStep), findsOneWidget);
    await backOnboardingStep(tester);
    expect(find.text(strings.obWelcomeT), findsOneWidget);
    final titles = [
      strings.obConnectStep,
      strings.obModelsT,
      strings.obLookT,
      strings.obPermsT,
      strings.obReadyT,
    ];
    for (final title in titles) {
      await tapOnboardingText(tester, strings.obNext);
      expect(find.text(title), findsOneWidget);
    }
    await tapOnboardingText(tester, strings.obStart);
    expect(container.read(settingsControllerProvider).onboarded, isTrue);
  });
}
