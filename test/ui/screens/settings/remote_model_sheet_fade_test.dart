import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/remote/remote_api_client.dart';
import 'package:transcriber/state/remote_models_provider.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/ui/screens/onboarding/widgets/onboarding_models_step.dart';
import 'package:transcriber/ui/screens/settings/model_settings_screen.dart';
import 'package:transcriber/ui/screens/settings/widgets/remote_model_sheet.dart';

import '../onboarding/onboarding_test_support.dart';

void main() {
  _registerTaskFlows();
  _registerCatalogResize();
}

void _registerTaskFlows() {
  for (final setup in [false, true]) {
    for (final transcription in [false, true]) {
      testWidgets(
        'model selection persists for transcription=$transcription setup=$setup',
        (tester) async {
          final container = await pumpOnboardingTestApp(
            tester,
            child: setup
                ? const Scaffold(body: OnboardingModelsStep())
                : const ModelSettingsScreen(),
            config: OnboardingTestConfig(
              viewport: const MediaQueryData(size: Size(400, 800)),
              connections: const {RemoteProviderId.google: true},
              modelCatalog: (_) async => _models(2),
            ),
          );
          await tester.pumpAndSettle();
          final row = find.byKey(
            ValueKey(
              'model-row-${transcription ? 'transcription' : 'summary'}',
            ),
          );
          await tester.ensureVisible(row);
          await tester.tap(row);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Fade model 1'));
          await tester.pumpAndSettle();
          expect(find.byType(RemoteModelSheet), findsNothing);
          final saved = container.read(settingsControllerProvider);
          expect(
            transcription
                ? saved.asrModelId(RemoteProviderId.google)
                : saved.summaryModelId(RemoteProviderId.google),
            'fade-model-1',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

void _registerCatalogResize() {
  testWidgets(
    'shortened API catalog resets scroll extent and exposes its model',
    (tester) async {
      var count = 40;
      final container = await pumpOnboardingTestApp(
        tester,
        child: const ModelSettingsScreen(),
        config: OnboardingTestConfig(
          viewport: const MediaQueryData(size: Size(400, 800)),
          connections: const {RemoteProviderId.google: true},
          modelCatalog: (_) async => _models(count),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('model-row-transcription')));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<CustomScrollView>(_inside(CustomScrollView))
          .controller!;
      await tester.scrollUntilVisible(
        find.text('Fade model 39'),
        300,
        scrollable: _inside(Scrollable),
      );
      await tester.pumpAndSettle();
      count = 1;
      container.invalidate(remoteModelsProvider);
      await tester.pumpAndSettle();
      expect(controller.position.maxScrollExtent, 0);
      expect(find.text('Fade model 0').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Finder _inside(Type type) => find.descendant(
  of: find.byType(RemoteModelSheet),
  matching: find.byType(type),
);

List<RemoteModelInfo> _models(int count) => List.generate(
  count,
  (index) =>
      RemoteModelInfo(id: 'fade-model-$index', label: 'Fade model $index'),
);
