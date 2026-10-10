import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/remote/remote_api_client.dart';
import 'package:transcriber/state/connections_controller.dart';
import 'package:transcriber/state/remote_models_provider.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/ui/screens/settings/widgets/remote_model_sheet.dart';
import 'package:transcriber/ui/screens/settings/widgets/transcription_section.dart';

import '../onboarding/onboarding_test_support.dart';

void main() {
  testWidgets('two synchronous model selections pop and persist only once', (
    tester,
  ) async {
    final observer = _SheetPopObserver();
    final container = await _openObservedPicker(tester, observer);
    final updates = <AppSettings>[];
    final subscription = container.listen(
      settingsControllerProvider,
      (_, next) => updates.add(next),
    );
    addTearDown(subscription.close);
    final select = _selectionCallback(tester);

    select('new-api-model');
    select('new-api-model');
    await tester.pumpAndSettle();

    expect(observer.sheetPops, 1);
    expect(updates, hasLength(1));
    expect(updates.single.asrModelId(RemoteProviderId.google), 'new-api-model');
    expect(find.byType(RemoteModelSheet), findsNothing);
    expect(find.byType(TranscriptionSection), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disconnect after model selection prevents caller persistence', (
    tester,
  ) async {
    final observer = _SheetPopObserver();
    final container = await _openObservedPicker(tester, observer);
    final initial = container.read(settingsControllerProvider);
    final select = _selectionCallback(tester);

    select('new-api-model');
    final disconnect = container
        .read(connectionsControllerProvider.notifier)
        .disconnect(RemoteProviderId.google);
    expect(
      container.read(connectionsControllerProvider)[RemoteProviderId.google],
      isFalse,
    );
    await disconnect;
    await tester.pumpAndSettle();

    expect(observer.sheetPops, 1);
    expect(find.byType(RemoteModelSheet), findsNothing);
    expect(container.read(settingsControllerProvider), initial);
    expect(find.byType(TranscriptionSection), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

ValueChanged<String?> _selectionCallback(WidgetTester tester) => tester
    .widget<RadioGroup<String>>(
      find.descendant(
        of: find.byType(RemoteModelSheet),
        matching: find.byType(RadioGroup<String>),
      ),
    )
    .onChanged;

Future<ProviderContainer> _openObservedPicker(
  WidgetTester tester,
  NavigatorObserver observer,
) async {
  final container = await pumpOnboardingTestApp(
    tester,
    child: const SizedBox.shrink(),
    config: const OnboardingTestConfig(
      connections: {RemoteProviderId.google: true},
      modelCatalog: _catalog,
    ),
  );
  final theme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: theme,
        navigatorObservers: [observer],
        home: const Scaffold(body: TranscriptionSection()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('model-row-transcription')));
  await tester.pumpAndSettle();
  return container;
}

Future<List<RemoteModelInfo>> _catalog(RemoteModelsQuery _) async => const [
  RemoteModelInfo(id: 'new-api-model'),
];

class _SheetPopObserver extends NavigatorObserver {
  int sheetPops = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is ModalBottomSheetRoute<dynamic>) sheetPops++;
    super.didPop(route, previousRoute);
  }
}
