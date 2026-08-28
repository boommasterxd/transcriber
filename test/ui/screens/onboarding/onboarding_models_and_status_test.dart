import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/data/catalog/gemma_catalog.dart';
import 'package:transcriber/data/catalog/whisper_catalog.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/state/model_manager_controller.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/ui/screens/onboarding/widgets/onboarding_models_step.dart';
import 'package:transcriber/ui/screens/onboarding/widgets/onboarding_status_row.dart';

import 'onboarding_test_support.dart';

void main() {
  final strings = AppStrings.of(AppLanguage.de);
  _registerSimpleModelTests(strings);
  _registerModelStateTests(strings);
}

void _registerSimpleModelTests(AppStrings strings) {
  testWidgets('status row presents its icon, content, and trailing widget', (
    tester,
  ) async {
    const trailingKey = Key('status-trailing');
    await pumpOnboardingTestApp(
      tester,
      child: const Scaffold(
        body: OnboardingStatusRow(
          icon: Icons.mic_none_rounded,
          title: 'Microphone title',
          subtitle: 'Microphone explanation',
          trailing: Icon(Icons.check, key: trailingKey),
        ),
      ),
    );

    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    expect(find.text('Microphone title'), findsOneWidget);
    expect(find.text('Microphone explanation'), findsOneWidget);
    expect(find.byKey(trailingKey), findsOneWidget);
  });

  testWidgets(
    'simple mode downloads the recommended models and reports ready',
    (tester) async {
      final settings = AppSettings.initial();
      final settingsController = OnboardingTestSettingsController(settings);
      final modelController = OnboardingTestModelController(
        const ModelManagerState(),
      );
      final container = await pumpOnboardingTestApp(
        tester,
        config: OnboardingTestConfig(
          settings: settings,
          settingsController: settingsController,
          modelController: modelController,
        ),
        child: const Scaffold(
          body: SingleChildScrollView(child: OnboardingModelsStep()),
        ),
      );

      expect(find.text(strings.obRecommendedSetup), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsNWidgets(2));
      await tester.tap(find.text(strings.obDownloadGo));
      await tester.pump();
      await tester.pump();

      expect(modelController.whisperDownloads, [WhisperCatalog.defaultId]);
      expect(modelController.gemmaDownloads, [GemmaCatalog.defaultId]);
      expect(
        container.read(settingsControllerProvider).whisperModelId,
        WhisperCatalog.defaultId,
      );
      expect(
        container.read(settingsControllerProvider).gemmaModelId,
        GemmaCatalog.defaultId,
      );
      expect(find.text(strings.modelsReady), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(3));
    },
  );
}

void _registerModelStateTests(AppStrings strings) {
  testWidgets('simple mode exposes active download progress', (tester) async {
    final settings = AppSettings.initial();
    final models = ModelManagerState(
      whisper: {
        settings.whisperModelId: const ModelStatus(
          status: DownloadStatus.downloading,
          progress: 0.4,
        ),
      },
    );
    await pumpOnboardingTestApp(
      tester,
      config: OnboardingTestConfig(settings: settings, models: models),
      child: const Scaffold(
        body: SingleChildScrollView(child: OnboardingModelsStep()),
      ),
    );

    expect(find.text(strings.downloading), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('advanced mode reveals stage controls and summary-off state', (
    tester,
  ) async {
    final settings = AppSettings.initial().copyWith(summarizeEnabled: false);
    await pumpOnboardingTestApp(
      tester,
      config: OnboardingTestConfig(
        settings: settings,
        models: downloadedModels(settings),
      ),
      child: const Scaffold(
        body: SingleChildScrollView(child: OnboardingModelsStep()),
      ),
    );

    await tester.tap(find.text(strings.obAdvanced));
    await tester.pump();

    expect(find.text(strings.obRecommendedSetup), findsNothing);
    expect(find.text(strings.modeLocalT), findsOneWidget);
    expect(find.text(strings.modeRemoteT), findsOneWidget);
    expect(find.text(strings.summarizeTitle), findsOneWidget);
    expect(
      find.text(WhisperCatalog.byId(settings.whisperModelId).displayName),
      findsOneWidget,
    );
  });

  testWidgets('advanced cloud mode presents a connected provider', (
    tester,
  ) async {
    await pumpOnboardingTestApp(
      tester,
      config: connectedCloudOnboardingConfig(),
      child: const Scaffold(
        body: SingleChildScrollView(child: OnboardingModelsStep()),
      ),
    );

    await tester.tap(find.text(strings.obAdvanced));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining(strings.connected), findsOneWidget);
    expect(find.text('OpenAI'), findsWidgets);
  });
}
