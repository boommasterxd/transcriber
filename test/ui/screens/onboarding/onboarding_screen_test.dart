import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/state/settings_controller.dart';

import 'onboarding_test_support.dart';

void main() {
  testWidgets(
    'wizard completes without checking or requesting microphone access',
    (tester) async {
      final permissions = OnboardingPermissionChannel()..install();
      addTearDown(permissions.uninstall);
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
        strings.obReadyT,
      ];
      for (final title in titles) {
        await tapOnboardingText(tester, strings.obNext);
        expect(find.text(title), findsOneWidget);
      }
      await tapOnboardingText(tester, strings.obStart);
      expect(container.read(settingsControllerProvider).onboarded, isTrue);
      expect(permissions.statusCalls, 0);
      expect(permissions.requestCalls, 0);
    },
  );
}
