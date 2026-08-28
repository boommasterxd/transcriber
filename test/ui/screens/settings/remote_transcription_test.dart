import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_theme.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/remote/remote_api_client.dart';
import 'package:transcriber/state/connections_controller.dart';
import 'package:transcriber/state/remote_models_provider.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/ui/screens/settings/widgets/remote_model_list.dart';
import 'package:transcriber/ui/screens/settings/widgets/transcription_section.dart';
import 'package:transcriber/ui/widgets/model_tile.dart';

import '../../../support/widget_test_utils.dart';

typedef _RemoteModelsLoader =
    Future<List<RemoteModelInfo>> Function(RemoteModelsQuery query);

void main() {
  _registerRemoteModelListTests();
  _registerTranscriptionTests();
}

void _registerRemoteModelListTests() {
  testWidgets('RemoteModelList displays loading state', (tester) async {
    final pending = Completer<List<RemoteModelInfo>>();
    await tester.pumpWidget(
      _testApp(
        child: const RemoteModelList(
          provider: RemoteProviderId.openai,
          forTranscription: true,
          selectedId: '',
          onSelect: _ignoreString,
        ),
        loadRemoteModels: (_) => pending.future,
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(const []);
    await tester.pumpUntilSettled();
  });

  testWidgets('RemoteModelList displays provider errors', (tester) async {
    await tester.pumpWidget(
      _testApp(
        child: const RemoteModelList(
          provider: RemoteProviderId.google,
          forTranscription: true,
          selectedId: '',
          onSelect: _ignoreString,
        ),
        loadRemoteModels: (_) async => throw StateError('request failed'),
      ),
    );
    await tester.pumpUntilSettled();

    expect(find.textContaining('request failed'), findsOneWidget);
  });

  testWidgets('RemoteModelList displays empty state', (tester) async {
    final strings = AppStrings.of(AppLanguage.de);
    await tester.pumpWidget(
      _testApp(
        child: const RemoteModelList(
          provider: RemoteProviderId.openai,
          forTranscription: false,
          selectedId: 'friendly-id',
          onSelect: _ignoreString,
        ),
        loadRemoteModels: (_) async => const [],
      ),
    );
    await tester.pumpUntilSettled();
    expect(find.text(strings.connectFirst), findsOneWidget);
  });

  testWidgets('RemoteModelList displays data and selects a model', (
    tester,
  ) async {
    var selectedId = '';
    await tester.pumpWidget(
      _testApp(
        child: RemoteModelList(
          provider: RemoteProviderId.openai,
          forTranscription: false,
          selectedId: 'friendly-id',
          onSelect: (id) => selectedId = id,
        ),
        loadRemoteModels: (_) async => const [
          RemoteModelInfo(id: 'friendly-id', label: 'Friendly model'),
          RemoteModelInfo(id: 'plain-id'),
        ],
      ),
    );
    await tester.pumpUntilSettled();

    expect(find.text('Friendly model'), findsOneWidget);
    expect(find.text('friendly-id'), findsOneWidget);
    expect(find.text('plain-id'), findsNothing);
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();
    expect(find.text('plain-id'), findsOneWidget);
    expect(find.byType(SelectionIndicator), findsNWidgets(2));
    final indicators = tester
        .widgetList<SelectionIndicator>(find.byType(SelectionIndicator))
        .toList();
    expect(indicators.first.selected, isTrue);
    expect(indicators.last.selected, isFalse);

    await tester.tap(find.text('plain-id'));
    expect(selectedId, 'plain-id');
  });
}

void _registerTranscriptionTests() {
  testWidgets('TranscriptionSection selects each cloud provider and model', (
    tester,
  ) async {
    final settingsController = _FakeSettingsController(AppSettings.initial());
    final queries = <RemoteModelsQuery>[];
    await tester.pumpWidget(
      _testApp(
        child: const TranscriptionSection(),
        settingsController: settingsController,
        connections: const {
          RemoteProviderId.openai: true,
          RemoteProviderId.google: true,
        },
        loadRemoteModels: (query) {
          queries.add(query);
          final id = query.provider == RemoteProviderId.google
              ? 'gemini-cloud'
              : 'gpt-cloud';
          return Future.value([RemoteModelInfo(id: id)]);
        },
      ),
    );
    await tester.pumpUntilSettled();

    expect(find.text('OpenAI'), findsOneWidget);
    expect(find.text('Google Gemini'), findsOneWidget);
    expect(find.text('gemini-3.5-transcribe'), findsOneWidget);
    expect(
      queries,
      contains((provider: RemoteProviderId.google, forTranscription: true)),
    );

    await tester.tap(find.text('OpenAI'));
    await tester.pumpUntilSettled();
    expect(settingsController.state.asrProvider, RemoteProviderId.openai);
    expect(find.text('gpt-transcribe'), findsOneWidget);
    expect(
      queries,
      contains((provider: RemoteProviderId.openai, forTranscription: true)),
    );

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();
    expect(find.text('gpt-cloud'), findsOneWidget);
    await tester.tap(find.text('gpt-cloud'));
    expect(
      settingsController.state.asrModelByProvider[RemoteProviderId.openai],
      'gpt-cloud',
    );
  });
}

Widget _testApp({
  required Widget child,
  _FakeSettingsController? settingsController,
  Map<RemoteProviderId, bool> connections = const {},
  _RemoteModelsLoader? loadRemoteModels,
}) {
  final settings =
      settingsController ?? _FakeSettingsController(AppSettings.initial());
  return ProviderScope(
    overrides: [
      settingsControllerProvider.overrideWith(() => settings),
      connectionsControllerProvider.overrideWith(
        () => _FakeConnectionsController(connections),
      ),
      if (loadRemoteModels != null)
        remoteModelsProvider.overrideWith(
          (ref, query) => loadRemoteModels(query),
        ),
    ],
    child: MaterialApp(
      theme: AppTheme.build(Brightness.light, AppAccent.blue),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      ),
    ),
  );
}

void _ignoreString(String _) {}

final class _FakeSettingsController extends SettingsController {
  _FakeSettingsController(this._initial);

  final AppSettings _initial;

  @override
  AppSettings build() => _initial;

  @override
  Future<void> setAsrProvider(RemoteProviderId provider) async {
    state = state.copyWith(asrProvider: provider);
  }

  @override
  Future<void> setAsrModel(RemoteProviderId provider, String modelId) async {
    state = state.copyWith(
      asrModelByProvider: {...state.asrModelByProvider, provider: modelId},
    );
  }
}

final class _FakeConnectionsController extends ConnectionsController {
  _FakeConnectionsController(this._initial);

  final Map<RemoteProviderId, bool> _initial;

  @override
  Map<RemoteProviderId, bool> build() => Map.of(_initial);
}
