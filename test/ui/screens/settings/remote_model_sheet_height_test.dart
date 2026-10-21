import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/remote/remote_api_client.dart';
import 'package:transcriber/state/remote_models_provider.dart';
import 'package:transcriber/ui/screens/settings/widgets/remote_model_sheet.dart';
import 'package:transcriber/ui/screens/settings/widgets/remote_stage.dart';

import '../onboarding/onboarding_test_support.dart';

const _screen = Size(400, 1000);

void main() {
  _registerCatalogGrowth();
  _registerLoadingResize();
  _registerCompactMessages();
  _registerConstrainedDisplays();
}

void _registerCatalogGrowth() {
  testWidgets('catalog becomes scrollable when content exceeds the viewport', (
    tester,
  ) async {
    var count = 1;
    final container = await _launchPicker(
      tester,
      _configuration((_) async => _models(count)),
    );
    await tester.pumpAndSettle();
    expect(_scrollPosition(tester).maxScrollExtent, 0);

    count = 5;
    container.invalidate(remoteModelsProvider);
    await tester.pumpAndSettle();
    expect(_scrollPosition(tester).maxScrollExtent, 0);

    count = 40;
    container.invalidate(remoteModelsProvider);
    await tester.pumpAndSettle();
    expect(_scrollPosition(tester).maxScrollExtent, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('capped catalog scrolls to and immediately returns last model', (
    tester,
  ) async {
    RemoteModelSelection? result;
    await _launchPicker(
      tester,
      _configuration((_) async => _models(40)),
      onSelected: (selection) => result = selection,
    );
    await tester.pumpAndSettle();
    expect(find.text('Catalog model 39').hitTestable(), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Catalog model 39'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Catalog model 39'));
    await tester.pumpAndSettle();
    expect(result, (provider: RemoteProviderId.google, modelId: 'catalog-39'));
    expect(find.byType(RemoteModelSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

void _registerLoadingResize() {
  testWidgets(
    'loading catalog replaces its progress indicator with model choices',
    (tester) async {
      final catalog = Completer<List<RemoteModelInfo>>();
      await _launchPicker(tester, _configuration((_) => catalog.future));
      // Complete the modal route transition while the catalog remains pending.
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      catalog.complete(_models(2));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Catalog model 1'), findsOneWidget);
      expect(_scrollPosition(tester).maxScrollExtent, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

void _registerCompactMessages() {
  final strings = AppStrings.of(AppLanguage.de);
  for (final failed in [false, true]) {
    testWidgets(
      '${failed ? 'error' : 'empty'} catalog exposes a reachable retry',
      (tester) async {
        await _launchPicker(
          tester,
          _configuration((_) async {
            if (failed) throw StateError('catalog unavailable');
            return [];
          }),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(failed ? strings.modelLoadFailed : strings.noModels),
          findsOneWidget,
        );
        expect(find.text(strings.retry).hitTestable(), findsOneWidget);
        expect(_scrollPosition(tester).maxScrollExtent, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

void _registerConstrainedDisplays() {
  for (final size in [const Size(320, 640), const Size(568, 320)]) {
    testWidgets('large text catalog fits and remains selectable at $size', (
      tester,
    ) async {
      RemoteModelSelection? selected;
      await _launchPicker(
        tester,
        _configuration((_) async => _models(15), size: size, textScale: 2),
        onSelected: (selection) => selected = selection,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Catalog model 14'),
        150,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      expect(find.text('Catalog model 14').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Catalog model 14'));
      await tester.pumpAndSettle();
      expect(selected?.modelId, 'catalog-14');
      expect(find.byType(RemoteModelSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

OnboardingTestConfig _configuration(
  Future<List<RemoteModelInfo>> Function(RemoteModelsQuery) catalog, {
  Size size = _screen,
  double textScale = 1,
}) => OnboardingTestConfig(
  modelCatalog: catalog,
  viewport: MediaQueryData(
    size: size,
    textScaler: TextScaler.linear(textScale),
  ),
  connections: const {RemoteProviderId.google: true},
);

List<RemoteModelInfo> _models(int count) => List.generate(
  count,
  (index) =>
      RemoteModelInfo(id: 'catalog-$index', label: 'Catalog model $index'),
);

ScrollPosition _scrollPosition(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position;

Future<ProviderContainer> _launchPicker(
  WidgetTester tester,
  OnboardingTestConfig config, {
  ValueChanged<RemoteModelSelection?>? onSelected,
}) async {
  final app = Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          final selection = await showRemoteModelSheet(
            context,
            stage: RemoteStage.transcription,
            selection: (provider: RemoteProviderId.google, modelId: ''),
            allowedProviders: const [RemoteProviderId.google],
          );
          onSelected?.call(selection);
        },
        child: const Text('Open catalog'),
      ),
    ),
  );
  final container = await pumpOnboardingTestApp(
    tester,
    config: config,
    child: app,
  );
  await tester.tap(find.text('Open catalog'));
  await tester.pump();
  return container;
}
