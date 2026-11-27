import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:transcriber/core/theme/app_theme.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/data/repositories/settings_repository.dart';
import 'package:transcriber/services/remote/remote_api_client.dart';
import 'package:transcriber/state/providers.dart';
import 'package:transcriber/state/remote_models_provider.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/ui/screens/settings/widgets/remote_stage.dart';
import 'package:transcriber/ui/screens/settings/widgets/remote_stage_settings.dart';

import '../../../support/app_test_fakes.dart';

const _initialModelId = 'offline-openai';
const _initial = (provider: RemoteProviderId.openai, modelId: _initialModelId);
const _chosen = (
  provider: RemoteProviderId.google,
  modelId: 'offline-model-15',
);

void main() {
  testWidgets('catalog traversal saves the pair only after activation', (
    tester,
  ) async {
    final database = testDatabase();
    addTearDown(database.close);
    final repository = SettingsRepository(database);
    const settings = AppSettings(
      transcription: TranscriptionSettings(
        provider: RemoteProviderId.openai,
        models: {RemoteProviderId.openai: _initialModelId},
      ),
    );
    await repository.save(settings);
    final container = _testContainer(repository, settings);
    final changes = <RemoteModelSelection>[];
    final subscription = container.listen(settingsControllerProvider, (
      _,
      value,
    ) {
      changes.add(_selection(value));
    });
    addTearDown(subscription.close);

    await _openCatalog(tester, container, settings);
    await _traverseModels(tester);
    expect(changes, isEmpty);
    expect(_selection(await repository.load()), _initial);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(changes, [_chosen]);
    expect(_selection(await repository.load()), _chosen);
  });
}

ProviderContainer _testContainer(
  SettingsRepository repository,
  AppSettings settings,
) {
  final container = ProviderContainer(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(repository),
      initialSettingsProvider.overrideWithValue(settings),
      initialConnectionsProvider.overrideWithValue(const {
        RemoteProviderId.openai: true,
        RemoteProviderId.google: true,
      }),
      remoteModelsProvider.overrideWith(
        (_, query) => query.provider == RemoteProviderId.openai
            ? const [RemoteModelInfo(id: _initialModelId)]
            : List.generate(
                18,
                (index) => RemoteModelInfo(id: 'offline-model-$index'),
              ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _openCatalog(
  WidgetTester tester,
  ProviderContainer container,
  AppSettings settings,
) async {
  await tester.binding.setSurfaceSize(const Size(400, 480));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.build(Brightness.light, settings.accent),
        home: const Scaffold(
          body: RemoteStageSettings(stage: RemoteStage.transcription),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('model-row-transcription')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('provider-google')));
  await tester.pumpAndSettle();
}

Future<void> _traverseModels(WidgetTester tester) async {
  Focus.of(tester.element(find.text('offline-model-0'))).requestFocus();
  await tester.pump();

  for (var step = 0; step < 15; step++) {
    final key = step < 7
        ? LogicalKeyboardKey.arrowDown
        : LogicalKeyboardKey.tab;
    await tester.sendKeyEvent(key);
    await tester.pump();
  }
}

RemoteModelSelection _selection(AppSettings settings) => (
  provider: settings.asrProvider,
  modelId: settings.asrModelId(settings.asrProvider),
);
