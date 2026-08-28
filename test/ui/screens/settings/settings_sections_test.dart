import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/state/connections_controller.dart';
import 'package:transcriber/state/model_manager_controller.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/ui/screens/settings/widgets/privacy_section.dart';
import 'package:transcriber/ui/screens/settings/widgets/provider_connect_card.dart';
import 'package:transcriber/ui/screens/settings/widgets/summary_section.dart';

import '../../../support/widget_test_utils.dart';

void main() {
  _registerSectionTests();
  _registerProviderTests();
}

void _registerSectionTests() {
  final strings = AppStrings.of(AppLanguage.de);

  testWidgets('privacy switch reveals warning and updates settings', (
    tester,
  ) async {
    late _TestSettingsController controller;
    await tester.pumpWidget(
      _settingsApp(
        child: const PrivacySection(),
        createSettings: () => controller = _TestSettingsController(),
      ),
    );

    expect(find.text(strings.autoDelNote), findsNothing);
    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(controller.state.autoDeleteAudio, isTrue);
    expect(find.text(strings.autoDelNote), findsOneWidget);
    expect(find.text(strings.privacyStatement), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(controller.state.autoDeleteAudio, isFalse);
    expect(find.text(strings.autoDelNote), findsNothing);
  });

  testWidgets('summary switch controls stage settings visibility', (
    tester,
  ) async {
    late _TestSettingsController controller;
    await tester.pumpWidget(
      _settingsApp(
        child: const SummarySection(),
        createSettings: () => controller = _TestSettingsController(
          AppSettings.initial().copyWith(summarizeEnabled: false),
        ),
      ),
    );

    expect(find.text(strings.modeLocalT), findsNothing);
    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(controller.state.summarizeEnabled, isTrue);
    expect(find.text(strings.modeLocalT), findsOneWidget);
    expect(find.text(strings.modeRemoteT), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(controller.state.summarizeEnabled, isFalse);
    expect(find.text(strings.modeLocalT), findsNothing);
  });
}

void _registerProviderTests() {
  final strings = AppStrings.of(AppLanguage.de);
  testWidgets('provider form ignores blank keys and connects with a key', (
    tester,
  ) async {
    late _TestConnectionsController connections;
    await tester.pumpWidget(
      _settingsApp(
        child: const ProviderConnectCard(provider: RemoteProviderId.openai),
        createSettings: _TestSettingsController.new,
        createConnections: () => connections = _TestConnectionsController(),
      ),
    );

    await tester.tap(find.text(strings.connect));
    await tester.pump();
    expect(connections.submittedKey, isNull);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  test-key  ');
    await tester.tap(find.text(strings.connect));
    await tester.pump();

    expect(connections.submittedKey, 'test-key');
    expect(find.textContaining(strings.connected), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('provider key help shows provider-specific guidance', (
    tester,
  ) async {
    await tester.pumpWidget(
      _settingsApp(
        child: const ProviderConnectCard(provider: RemoteProviderId.openai),
        createSettings: _TestSettingsController.new,
        createConnections: _TestConnectionsController.new,
      ),
    );

    await tester.tap(find.text(strings.keyHelp));
    await tester.pumpUntilSettled();

    expect(find.text(strings.keyHelpTitle('OpenAI')), findsOneWidget);
    expect(find.text(strings.keyHelpStep1('OpenAI')), findsOneWidget);
    expect(find.text(strings.keyHelpNote), findsOneWidget);
  });

  testWidgets('connected provider can be disconnected', (tester) async {
    late _TestConnectionsController connections;
    await tester.pumpWidget(
      _settingsApp(
        child: const ProviderConnectCard(provider: RemoteProviderId.openai),
        createSettings: _TestSettingsController.new,
        createConnections: () => connections = _TestConnectionsController(
          const {RemoteProviderId.openai: true},
        ),
      ),
    );

    expect(find.textContaining(strings.connected), findsOneWidget);
    await tester.tap(find.text(strings.disconnect));
    await tester.pump();

    expect(connections.disconnectedProvider, RemoteProviderId.openai);
    expect(find.byType(TextField), findsOneWidget);
  });
}

Widget _settingsApp({
  required Widget child,
  required _TestSettingsController Function() createSettings,
  _TestConnectionsController Function()? createConnections,
}) {
  return ProviderScope(
    overrides: [
      settingsControllerProvider.overrideWith(createSettings),
      connectionsControllerProvider.overrideWith(
        createConnections ?? _TestConnectionsController.new,
      ),
      modelManagerControllerProvider.overrideWith(_TestModelManager.new),
    ],
    child: MaterialApp(
      theme: ThemeData(
        extensions: <ThemeExtension<dynamic>>[AppPalette.light(AppAccent.blue)],
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      ),
    ),
  );
}

class _TestSettingsController extends SettingsController {
  _TestSettingsController([AppSettings? initial])
    : _initial = initial ?? AppSettings.initial();

  final AppSettings _initial;

  @override
  AppSettings build() => _initial;

  @override
  Future<void> setAutoDelete(bool value) async {
    state = state.copyWith(autoDeleteAudio: value);
  }

  @override
  Future<void> setSummarizeEnabled(bool value) async {
    state = state.copyWith(summarizeEnabled: value);
  }
}

class _TestConnectionsController extends ConnectionsController {
  _TestConnectionsController([Map<RemoteProviderId, bool> initial = const {}])
    : _initial = initial;

  final Map<RemoteProviderId, bool> _initial;
  String? submittedKey;
  RemoteProviderId? disconnectedProvider;

  @override
  Map<RemoteProviderId, bool> build() => Map.of(_initial);

  @override
  Future<void> connect(RemoteProviderId provider, String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return;
    submittedKey = trimmed;
    state = {...state, provider: true};
  }

  @override
  Future<void> disconnect(RemoteProviderId provider) async {
    disconnectedProvider = provider;
    state = {...state, provider: false};
  }
}

class _TestModelManager extends ModelManagerController {
  @override
  ModelManagerState build() => const ModelManagerState();
}
