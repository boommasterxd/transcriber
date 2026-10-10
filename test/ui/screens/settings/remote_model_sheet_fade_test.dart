import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/remote/remote_api_client.dart';
import 'package:transcriber/state/remote_models_provider.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/ui/screens/onboarding/widgets/onboarding_models_step.dart';
import 'package:transcriber/ui/screens/settings/model_settings_screen.dart';
import 'package:transcriber/ui/screens/settings/widgets/remote_model_sheet.dart';
import 'package:transcriber/ui/widgets/surfaces.dart';

import '../onboarding/onboarding_test_support.dart';

void main() {
  _registerTaskFlows();
  _registerCatalogResize();
}

void _registerTaskFlows() {
  for (final setup in [false, true]) {
    for (final transcription in [false, true]) {
      testWidgets(
        'scroll edges track $transcription model choices in setup=$setup',
        (tester) async {
          final container = await pumpOnboardingTestApp(
            tester,
            child: setup
                ? const Scaffold(body: OnboardingModelsStep())
                : const ModelSettingsScreen(),
            config: OnboardingTestConfig(
              surfaceSize: const Size(400, 800),
              textScale: 1,
              connections: const {RemoteProviderId.google: true},
              modelCatalog: (_) async => _models(40),
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
          expect(_fades(tester), [0, 1]);
          final fade = tester.widget<FadeEdges>(_inside(FadeEdges));
          final palette = tester.element(_inside(FadeEdges)).palette;
          expect(fade.color, palette.surface);

          final controller = tester
              .widget<CustomScrollView>(_inside(CustomScrollView))
              .controller!;
          controller.jumpTo(controller.position.maxScrollExtent / 2);
          await tester.pumpAndSettle();
          expect(_fades(tester), [1, 1]);
          controller.jumpTo(controller.position.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(_fades(tester), [1, 0]);
          await tester.tap(find.text('Fade model 39'));
          await tester.pumpAndSettle();
          expect(find.byType(RemoteModelSheet), findsNothing);
          final saved = container.read(settingsControllerProvider);
          expect(
            transcription
                ? saved.asrModelId(RemoteProviderId.google)
                : saved.summaryModelId(RemoteProviderId.google),
            'fade-model-39',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

void _registerCatalogResize() {
  testWidgets('shortened API catalog removes both fades and excess height', (
    tester,
  ) async {
    var count = 40;
    final container = await pumpOnboardingTestApp(
      tester,
      child: const ModelSettingsScreen(),
      config: OnboardingTestConfig(
        surfaceSize: const Size(400, 800),
        textScale: 1,
        connections: const {RemoteProviderId.google: true},
        modelCatalog: (_) async => _models(count),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('model-row-transcription')));
    await tester.pumpAndSettle();
    final fullHeight = tester.getSize(find.byType(RemoteModelSheet)).height;
    final controller = tester
        .widget<CustomScrollView>(_inside(CustomScrollView))
        .controller!;
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(_fades(tester), [1, 0]);
    count = 1;
    container.invalidate(remoteModelsProvider);
    await tester.pumpAndSettle();
    expect(_fades(tester), [0, 0]);
    expect(controller.position.maxScrollExtent, 0);
    expect(
      tester.getSize(find.byType(RemoteModelSheet)).height,
      lessThan(fullHeight),
    );
    expect(find.text('Fade model 0').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Finder _inside(Type type) => find.descendant(
  of: find.byType(RemoteModelSheet),
  matching: find.byType(type),
);

List<double> _fades(WidgetTester tester) => tester
    .widgetList<AnimatedOpacity>(_inside(AnimatedOpacity))
    .map((fade) => fade.opacity)
    .toList();

List<RemoteModelInfo> _models(int count) => List.generate(
  count,
  (index) =>
      RemoteModelInfo(id: 'fade-model-$index', label: 'Fade model $index'),
);
