import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
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
  final strings = AppStrings.of(AppLanguage.de);
  _registerCatalogStates(strings);
  _registerImmediateSelection(strings);
  _registerDismissal();
  _registerRefresh(strings);
  _registerKeyboardRefresh();
  _registerConnectionChanges(strings);
  _registerResponsiveSheet();
}

void _registerCatalogStates(AppStrings strings) {
  testWidgets('loading catalog cannot change settings before models arrive', (
    tester,
  ) async {
    final pending = Completer<List<RemoteModelInfo>>();
    final container = await _openSheet(tester, catalog: (_) => pending.future);
    final initial = container.read(settingsControllerProvider);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.byType(RawRadio<String>), findsNothing);
    expect(container.read(settingsControllerProvider), initial);
    pending.complete(const [RemoteModelInfo(id: 'new-api-model')]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('new-api-model'));
    await tester.pumpAndSettle();
    expect(find.byType(RemoteModelSheet), findsNothing);
    expect(
      container
          .read(settingsControllerProvider)
          .asrModelId(RemoteProviderId.google),
      'new-api-model',
    );
  });

  testWidgets('catalog error is private and retry loads fresh API data', (
    tester,
  ) async {
    var calls = 0;
    await _openSheet(
      tester,
      catalog: (_) async {
        calls++;
        if (calls == 1) throw StateError('sensitive-provider-response');
        return const [RemoteModelInfo(id: 'fresh-model')];
      },
    );
    await tester.pumpAndSettle();
    expect(find.text(strings.modelLoadFailed), findsWidgets);
    expect(find.textContaining('sensitive-provider-response'), findsNothing);
    expect(find.byType(RawRadio<String>), findsNothing);
    await tester.tap(find.text(strings.retry).last);
    await tester.pumpAndSettle();
    expect(find.text('fresh-model'), findsOneWidget);
    expect(calls, greaterThan(1));
  });

  testWidgets('empty catalog can be recovered with Retry', (tester) async {
    var available = false;
    final container = await _openSheet(
      tester,
      catalog: (_) async =>
          available ? const [RemoteModelInfo(id: 'recovered-model')] : const [],
    );
    await tester.pumpAndSettle();
    final initial = container.read(settingsControllerProvider);
    expect(find.textContaining(strings.noModels), findsWidgets);
    expect(find.byType(RawRadio<String>), findsNothing);
    available = true;
    await tester.tap(find.text(strings.retry).last);
    await tester.pumpAndSettle();
    expect(find.text('recovered-model'), findsOneWidget);
    expect(container.read(settingsControllerProvider), initial);
  });
}

void _registerImmediateSelection(AppStrings strings) {
  testWidgets('model tap saves immediately only for the selected task', (
    tester,
  ) async {
    final container = await _openSheet(tester);
    final initial = container.read(settingsControllerProvider);
    await tester.pumpAndSettle();
    expect(find.text(strings.transcriptionModelTitle), findsOneWidget);
    expect(find.byKey(const ValueKey('provider-google')), findsNothing);
    await tester.tap(find.text('New API model'));
    await tester.pumpAndSettle();
    final saved = container.read(settingsControllerProvider);
    expect(saved.asrModelId(RemoteProviderId.google), 'new-api-model');
    expect(saved.summaryProvider, initial.summaryProvider);
    expect(saved.chatModelByProvider, initial.chatModelByProvider);
    expect(find.byType(RemoteModelSheet), findsNothing);
    expect(find.text('New API model'), findsOneWidget);
    await tester.tap(find.byKey(const Key('model-row-transcription')));
    await tester.pumpAndSettle();
    final option = find.ancestor(
      of: find.text('New API model').last,
      matching: find.byType(RawRadio<String>),
    );
    expect(
      find.descendant(of: option, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
  });

  testWidgets(
    'provider and model persist together after browsing another provider',
    (tester) async {
      final container = await _openSheet(
        tester,
        connections: _bothProviders,
        catalog: _providerModels,
      );
      await tester.pumpAndSettle();
      final initial = container.read(settingsControllerProvider);
      final updates = <AppSettings>[];
      final subscription = container.listen(
        settingsControllerProvider,
        (_, next) => updates.add(next),
      );
      addTearDown(subscription.close);
      await tester.tap(find.byKey(const ValueKey('provider-openai')));
      await tester.pumpAndSettle();
      expect(container.read(settingsControllerProvider), initial);
      expect(updates, isEmpty);
      await tester.tap(find.text('openai-api'));
      await tester.pumpAndSettle();
      expect(find.byType(RemoteModelSheet), findsNothing);
      expect(updates, hasLength(1));
      final saved = updates.single;
      expect(saved.asrProvider, RemoteProviderId.openai);
      expect(saved.asrModelId(RemoteProviderId.openai), 'openai-api');
      expect(saved.summaryProvider, initial.summaryProvider);
      expect(saved.chatModelByProvider, initial.chatModelByProvider);
    },
  );
}

void _registerDismissal() {
  for (final dismissal in ['back', 'backdrop', 'drag']) {
    testWidgets(
      'provider browsing preserves settings on $dismissal dismissal',
      (tester) async {
        final container = await _openSheet(
          tester,
          connections: _bothProviders,
          catalog: _providerModels,
        );
        await tester.pumpAndSettle();
        final initial = container.read(settingsControllerProvider);
        await tester.tap(find.byKey(const ValueKey('provider-openai')));
        await tester.pumpAndSettle();
        expect(find.text('openai-api'), findsOneWidget);
        expect(container.read(settingsControllerProvider), initial);
        if (dismissal == 'back') {
          await tester.binding.handlePopRoute();
        } else if (dismissal == 'backdrop') {
          await tester.tapAt(const Offset(10, 10));
        } else {
          final top = tester.getTopLeft(find.byType(RemoteModelSheet));
          await tester.flingFrom(
            top + const Offset(300, 12),
            const Offset(0, 1000),
            2000,
          );
        }
        await tester.pumpAndSettle();
        expect(find.byType(RemoteModelSheet), findsNothing);
        expect(container.read(settingsControllerProvider), initial);
      },
    );
  }
}

void _registerRefresh(AppStrings strings) {
  testWidgets('pull refresh discovers newly published models without saving', (
    tester,
  ) async {
    var refreshed = false;
    final container = await _openSheet(
      tester,
      catalog: (_) async => [
        RemoteModelInfo(id: refreshed ? 'published-model' : 'old-model'),
      ],
    );
    await tester.pumpAndSettle();
    final initial = container.read(settingsControllerProvider);
    expect(find.text('published-model'), findsNothing);
    refreshed = true;
    await _pullRefresh(tester);
    expect(find.text('published-model'), findsOneWidget);
    expect(container.read(settingsControllerProvider), initial);
    await tester.tap(find.text('published-model'));
    await tester.pumpAndSettle();
    expect(
      container
          .read(settingsControllerProvider)
          .asrModelId(RemoteProviderId.google),
      'published-model',
    );
  });

  testWidgets(
    'pull refresh removes unavailable models without replacing saved choice',
    (tester) async {
      var removed = false;
      final savedId = AppSettings.initial().asrModelId(RemoteProviderId.google);
      final container = await _openSheet(
        tester,
        catalog: (_) async => [
          RemoteModelInfo(id: removed ? 'replacement' : savedId),
        ],
      );
      await tester.pumpAndSettle();
      final initial = container.read(settingsControllerProvider);
      removed = true;
      await _pullRefresh(tester);
      expect(
        find.descendant(
          of: find.byType(RemoteModelSheet),
          matching: find.text(savedId),
        ),
        findsNothing,
      );
      expect(find.text('replacement'), findsOneWidget);
      expect(container.read(settingsControllerProvider), initial);
    },
  );

  testWidgets(
    'failed pull refresh removes stale choices and retains saved settings',
    (tester) async {
      var fail = false;
      final container = await _openSheet(
        tester,
        catalog: (_) async {
          if (fail) throw StateError('sensitive-refresh-response');
          return const [RemoteModelInfo(id: 'old-model')];
        },
      );
      await tester.pumpAndSettle();
      final initial = container.read(settingsControllerProvider);
      fail = true;
      await _pullRefresh(tester);
      expect(find.text(strings.modelLoadFailed), findsWidgets);
      expect(find.textContaining('sensitive-refresh-response'), findsNothing);
      expect(find.byType(RawRadio<String>), findsNothing);
      expect(container.read(settingsControllerProvider), initial);
      fail = false;
      await tester.tap(find.text(strings.retry).last);
      await tester.pumpAndSettle();
      expect(find.text('old-model'), findsOneWidget);
    },
  );
}

void _registerConnectionChanges(AppStrings strings) {
  testWidgets('unconnected provider never requests a catalog or opens picker', (
    tester,
  ) async {
    var calls = 0;
    await pumpOnboardingTestApp(
      tester,
      child: const Scaffold(body: TranscriptionSection()),
      config: OnboardingTestConfig(
        modelCatalog: (_) async {
          calls++;
          return const [RemoteModelInfo(id: 'unexpected')];
        },
      ),
    );
    await tester.tap(find.byKey(const Key('model-row-transcription')));
    await tester.pumpAndSettle();
    expect(find.text(strings.connectFirst), findsOneWidget);
    expect(find.byType(RemoteModelSheet), findsNothing);
    expect(calls, 0);
  });

  testWidgets('disconnect before a stale model tap cannot save', (
    tester,
  ) async {
    final container = await _openSheet(tester);
    await tester.pumpAndSettle();
    final initial = container.read(settingsControllerProvider);
    await container
        .read(connectionsControllerProvider.notifier)
        .disconnect(RemoteProviderId.google);
    await tester.tap(find.text('New API model'));
    await tester.pumpAndSettle();
    expect(container.read(settingsControllerProvider), initial);
    expect(find.byType(RemoteModelSheet), findsOneWidget);
    expect(find.byType(RawRadio<String>), findsNothing);
  });

  testWidgets('invalidated catalog rejects a stale tap while reloading', (
    tester,
  ) async {
    final pending = Completer<List<RemoteModelInfo>>();
    var refresh = false;
    final container = await _openSheet(
      tester,
      catalog: (_) => refresh
          ? pending.future
          : Future.value(const [RemoteModelInfo(id: 'new-api-model')]),
    );
    await tester.pumpAndSettle();
    final initial = container.read(settingsControllerProvider);
    refresh = true;
    container.invalidate(remoteModelsProvider);
    await tester.tap(find.text('new-api-model'));
    await tester.pump();
    expect(container.read(settingsControllerProvider), initial);
    expect(find.byType(RemoteModelSheet), findsOneWidget);
    expect(find.byType(RawRadio<String>), findsNothing);
    pending.complete(const [RemoteModelInfo(id: 'replacement')]);
    await tester.pumpAndSettle();
    expect(find.text('replacement'), findsOneWidget);
  });
}

void _registerKeyboardRefresh() {
  testWidgets('F5 refreshes the current catalog without changing settings', (
    tester,
  ) async {
    var refreshed = false;
    final container = await _openSheet(
      tester,
      catalog: (_) async => [
        RemoteModelInfo(id: refreshed ? 'keyboard-model' : 'original-model'),
      ],
    );
    await tester.pumpAndSettle();
    final initial = container.read(settingsControllerProvider);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    refreshed = true;
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    expect(find.text('keyboard-model'), findsOneWidget);
    expect(container.read(settingsControllerProvider), initial);
  });
}

void _registerResponsiveSheet() {
  for (final (size, width) in [
    (const Size(400, 800), 400.0),
    (const Size(800, 800), 600.0),
  ]) {
    testWidgets('model picker matches share sheet width at $size', (
      tester,
    ) async {
      await _openSheet(tester, surfaceSize: size);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(RemoteModelSheet)).width, width);
    });
  }
  for (final size in [const Size(320, 640), const Size(568, 320)]) {
    testWidgets('model tap remains usable at $size with doubled text', (
      tester,
    ) async {
      final container = await _openSheet(
        tester,
        surfaceSize: size,
        textScale: 2,
        connections: _bothProviders,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final model = find.text('New API model');
      if (model.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          model,
          150,
          scrollable: _sheetScrollable,
        );
      }
      await tester.ensureVisible(model);
      await tester.pumpAndSettle();
      await tester.tap(model);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(RemoteModelSheet), findsNothing);
      expect(
        container
            .read(settingsControllerProvider)
            .asrModelId(RemoteProviderId.google),
        'new-api-model',
      );
    });
  }
}

const _bothProviders = {
  RemoteProviderId.google: true,
  RemoteProviderId.openai: true,
};

Future<List<RemoteModelInfo>> _providerModels(RemoteModelsQuery query) async =>
    [RemoteModelInfo(id: '${query.provider.name}-api')];

Finder get _sheetScrollable => find.descendant(
  of: find.byType(RemoteModelSheet),
  matching: find.byType(Scrollable),
);

Future<void> _pullRefresh(WidgetTester tester) async {
  await tester.drag(_sheetScrollable, const Offset(0, 350));
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _openSheet(
  WidgetTester tester, {
  Map<RemoteProviderId, bool> connections = const {
    RemoteProviderId.google: true,
  },
  Future<List<RemoteModelInfo>> Function(RemoteModelsQuery)? catalog,
  Size surfaceSize = const Size(800, 1100),
  double textScale = 1,
}) async {
  final container = await pumpOnboardingTestApp(
    tester,
    child: const Scaffold(
      body: SingleChildScrollView(child: TranscriptionSection()),
    ),
    config: OnboardingTestConfig(
      connections: connections,
      surfaceSize: surfaceSize,
      textScale: textScale,
      modelCatalog:
          catalog ??
          (_) async => const [
            RemoteModelInfo(id: 'new-api-model', label: 'New API model'),
          ],
    ),
  );
  await tester.pump();
  final row = find.byKey(const Key('model-row-transcription'));
  await tester.ensureVisible(row);
  await tester.pump();
  await tester.tap(row);
  await tester.pump();
  return container;
}
