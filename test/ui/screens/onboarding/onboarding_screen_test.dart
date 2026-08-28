import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/processing_mode.dart';
import 'package:transcriber/state/model_manager_controller.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/ui/screens/onboarding/onboarding_screen.dart';

import 'onboarding_test_support.dart';

void main() {
  final strings = AppStrings.of(AppLanguage.de);
  useGrantedOnboardingPermissions();
  _registerNavigationTest(strings);
  _registerGateTests(strings);
}

void _registerNavigationTest(AppStrings strings) {
  testWidgets('wizard navigates all five steps, back, and completes setup', (
    tester,
  ) async {
    final settings = AppSettings.initial();
    final controller = OnboardingTestSettingsController(settings);
    final container = await pumpOnboardingTestApp(
      tester,
      config: OnboardingTestConfig(
        settings: settings,
        models: downloadedModels(settings),
        settingsController: controller,
      ),
      child: const OnboardingScreen(),
    );

    expect(find.text(strings.obWelcomeT), findsOneWidget);
    await _next(tester, strings);
    expect(find.text(strings.obModelsT), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(strings.obWelcomeT), findsOneWidget);

    await _next(tester, strings);
    await _next(tester, strings);
    expect(find.text(strings.obLookT), findsOneWidget);
    await _next(tester, strings);
    await tester.pump();
    expect(find.text(strings.obPermsT), findsOneWidget);
    expect(find.text(strings.obPermGranted), findsOneWidget);

    await _next(tester, strings);
    expect(find.text(strings.obReadyT), findsOneWidget);
    await tester.tap(find.text(strings.obStart));
    await tester.pump();

    expect(container.read(settingsControllerProvider).onboarded, isTrue);
  });
}

void _registerGateTests(AppStrings strings) {
  testWidgets('missing local model blocks the model step with download hint', (
    tester,
  ) async {
    await pumpOnboardingTestApp(tester, child: const OnboardingScreen());

    await _next(tester, strings);

    expect(find.text(strings.obDownloadHint), findsOneWidget);
    expect(find.text(strings.obNext), findsNothing);
  });

  testWidgets('disconnected cloud provider blocks with connection hint', (
    tester,
  ) async {
    final settings = AppSettings.initial().copyWith(
      asrMode: ProcessingMode.cloud,
      summarizeEnabled: false,
    );
    await pumpOnboardingTestApp(
      tester,
      config: OnboardingTestConfig(settings: settings),
      child: const OnboardingScreen(),
    );

    await _next(tester, strings);

    expect(find.text(strings.obConnectHint), findsOneWidget);
    expect(find.text(strings.obNext), findsNothing);
  });

  testWidgets('connected cloud provider passes while summary is disabled', (
    tester,
  ) async {
    await pumpOnboardingTestApp(
      tester,
      config: connectedCloudOnboardingConfig(),
      child: const OnboardingScreen(),
    );

    await _next(tester, strings);
    expect(find.text(strings.obNext), findsOneWidget);
    await _next(tester, strings);

    expect(find.text(strings.obLookT), findsOneWidget);
  });

  testWidgets('summary-off ignores an unavailable local summary model', (
    tester,
  ) async {
    final settings = AppSettings.initial().copyWith(summarizeEnabled: false);
    final models = ModelManagerState(
      whisper: {
        settings.whisperModelId: const ModelStatus(
          status: DownloadStatus.downloaded,
        ),
      },
    );
    await pumpOnboardingTestApp(
      tester,
      config: OnboardingTestConfig(settings: settings, models: models),
      child: const OnboardingScreen(),
    );

    await _next(tester, strings);

    expect(find.text(strings.obNext), findsOneWidget);
    expect(find.text(strings.obDownloadHint), findsNothing);
  });
}

Future<void> _next(WidgetTester tester, AppStrings strings) async {
  await tester.tap(find.text(strings.obNext));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
