import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/state/connections_controller.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/ui/screens/settings/widgets/provider_connect_card.dart';
import 'package:transcriber/ui/screens/onboarding/widgets/onboarding_cloud_step.dart';
import 'package:transcriber/ui/widgets/provider_logo.dart';
import 'package:transcriber/ui/widgets/surfaces.dart';

import 'settings_test_app.dart';

void main() {
  final strings = AppStrings.of(AppLanguage.de);

  for (final provider in RemoteProviderId.values) {
    group(provider.name, () {
      _registerConnectionTests(provider, strings);
      _registerCredentialTests(provider, strings);
      _registerExpansionTests(provider, strings);
    });
  }
  _registerResponsiveTest();
  _registerAccordionTest();
}

void _registerExpansionTests(RemoteProviderId provider, AppStrings strings) {
  testWidgets('starts compact and preserves masked input when collapsed', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      provider,
      _FakeConnectionsController(),
      expand: false,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.text(strings.keyMissing), findsOneWidget);
    expect(find.byType(ProviderLogo), findsOneWidget);
    expect(
      tester.getSize(find.byType(ListTile)).height,
      greaterThanOrEqualTo(48),
    );

    await tester.tap(find.byType(ListTile));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'draft-value');
    await tester.tap(find.byType(ListTile));
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byType(ListTile));
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'draft-value');
    expect(field.obscureText, isTrue);
  });

  testWidgets('reports checking until the connection succeeds', (tester) async {
    final pending = Completer<void>();
    final controller = _FakeConnectionsController()..pendingConnect = pending;
    await _pumpCard(tester, provider, controller);
    await tester.enterText(find.byType(TextField), 'candidate-value');
    await tester.tap(find.text(strings.connect));
    await tester.pump();
    expect(find.text(strings.providerChecking), findsOneWidget);
    expect(find.text(strings.connected), findsNothing);
    await tester.tap(find.byType(ListTile));
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    pending.complete();
    await tester.pump();
    expect(find.text(strings.connected), findsOneWidget);
    expect(controller.connectCalls, hasLength(1));
  });
}

void _registerAccordionTest() {
  testWidgets('onboarding only expands one provider at a time', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsControllerProvider.overrideWith(_FakeSettingsController.new),
          connectionsControllerProvider.overrideWith(
            _FakeConnectionsController.new,
          ),
        ],
        child: settingsTestApp(
          home: const Scaffold(
            body: SingleChildScrollView(child: OnboardingCloudStep()),
          ),
        ),
      ),
    );
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byType(ListTile).first);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'first-provider-draft');
    await tester.tap(find.byType(ListTile).last);
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    await tester.tap(find.byType(ListTile).first);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'first-provider-draft',
    );
  });
}

void _registerConnectionTests(RemoteProviderId provider, AppStrings strings) {
  testWidgets('reports connection errors and accepts a valid key', (
    tester,
  ) async {
    final controller = _FakeConnectionsController()..failConnect = true;
    await _pumpCard(tester, provider, controller);

    await tester.enterText(find.byType(TextField), '  test-key  ');
    await tester.tap(find.text(strings.connect));
    await tester.pump();

    expect(controller.connectCalls, [(provider, '  test-key  ')]);
    expect(find.text(strings.keyCheckFailed), findsOneWidget);
    expect(find.text(strings.providerConnectionFailed), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    controller.failConnect = false;
    await tester.tap(find.text(strings.connect));
    await tester.pump();

    expect(controller.connectCalls, hasLength(2));
    expect(find.text(strings.keyVerified), findsOneWidget);
    expect(find.text(strings.replaceKey), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('checks a stored key and reports verification failures', (
    tester,
  ) async {
    final controller = _FakeConnectionsController(initial: {provider: true});
    await _pumpCard(tester, provider, controller);

    await tester.tap(find.text(strings.testKey));
    await tester.pump();
    expect(controller.testCalls, [provider]);
    expect(find.text(strings.keyVerified), findsOneWidget);

    controller.failTest = true;
    await tester.tap(find.text(strings.testKey));
    await tester.pump();
    expect(controller.testCalls, [provider, provider]);
    expect(find.text(strings.keyCheckFailed), findsOneWidget);
    expect(find.text(strings.providerConnectionFailed), findsOneWidget);
  });
}

void _registerCredentialTests(RemoteProviderId provider, AppStrings strings) {
  testWidgets('replaces the stored key for the selected provider', (
    tester,
  ) async {
    final controller = _FakeConnectionsController(initial: {provider: true});
    await _pumpCard(tester, provider, controller);

    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'replacement-key');
    await tester.tap(find.text(strings.replaceKey));
    await tester.pump();

    expect(controller.connectCalls, [(provider, 'replacement-key')]);
    expect(find.text(strings.keyVerified), findsOneWidget);
  });

  testWidgets('keeps a failed removal and disconnects on retry', (
    tester,
  ) async {
    final controller = _FakeConnectionsController(initial: {provider: true})
      ..failDisconnect = true;
    await _pumpCard(tester, provider, controller);

    await tester.tap(find.text(strings.disconnect));
    await tester.pump();
    expect(controller.disconnectCalls, [provider]);
    expect(find.text(strings.keyCheckFailed), findsOneWidget);
    expect(find.text(strings.disconnect), findsOneWidget);

    controller.failDisconnect = false;
    await tester.tap(find.text(strings.disconnect));
    await tester.pump();
    expect(controller.disconnectCalls, [provider, provider]);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text(strings.disconnect), findsNothing);
  });

  testWidgets('editable card pre-fills and keeps a stored key obscured', (
    tester,
  ) async {
    final controller = _FakeConnectionsController(
      initial: {provider: true},
      storedKeys: {provider: 'stored-value'},
    );
    await _pumpCard(tester, provider, controller);
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isTrue);
    expect(field.controller!.text, 'stored-value');
    expect(find.byType(ProviderLogo), findsOneWidget);
    expect(find.text(strings.disconnect), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'replacement-value');
    await tester.tap(find.text(strings.replaceKey));
    await tester.pump();

    expect(controller.connectCalls, [(provider, 'replacement-value')]);
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'replacement-value',
    );
  });
}

void _registerResponsiveTest() {
  testWidgets('stacks key controls on a narrow screen with larger text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpCard(
      tester,
      RemoteProviderId.openai,
      _FakeConnectionsController(),
      textScaler: const TextScaler.linear(2),
    );

    final fieldBottom = tester.getBottomLeft(find.byType(TextField)).dy;
    final buttonTop = tester.getTopLeft(find.byType(FilledButton)).dy;
    expect(buttonTop, greaterThan(fieldBottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('fills connected key actions equally at larger text sizes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpCard(
      tester,
      RemoteProviderId.openai,
      _FakeConnectionsController(initial: {RemoteProviderId.openai: true}),
      textScaler: const TextScaler.linear(2),
    );

    final strings = AppStrings.of(AppLanguage.de);
    final testButton = find.ancestor(
      of: find.text(strings.testKey),
      matching: find.byType(TextButton),
    );
    final disconnectButton = find.ancestor(
      of: find.text(strings.disconnect),
      matching: find.byType(TextButton),
    );
    expect(testButton, findsOneWidget);
    expect(disconnectButton, findsOneWidget);

    final testSize = tester.getSize(testButton);
    final disconnectSize = tester.getSize(disconnectButton);
    final cardSize = tester.getSize(find.byType(SurfaceCard));
    final actionWidth = (cardSize.width - 32 - 8) / 2;
    expect(testSize.width, closeTo(actionWidth, 1));
    expect(disconnectSize.width, closeTo(actionWidth, 1));
    expect(testSize.height, greaterThanOrEqualTo(48));
    expect(disconnectSize.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpCard(
  WidgetTester tester,
  RemoteProviderId provider,
  _FakeConnectionsController connections, {
  TextScaler textScaler = TextScaler.noScaling,
  bool expand = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsControllerProvider.overrideWith(_FakeSettingsController.new),
        connectionsControllerProvider.overrideWith(() => connections),
      ],
      child: settingsTestApp(
        textScaler: textScaler,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProviderConnectCard(provider: provider),
          ),
        ),
      ),
    ),
  );
  if (expand) {
    await tester.tap(find.byType(ListTile));
    await tester.pump();
  }
}

class _FakeSettingsController extends SettingsController {
  @override
  AppSettings build() => AppSettings.initial();
}

class _FakeConnectionsController extends ConnectionsController {
  _FakeConnectionsController({
    this.initial = const {},
    this.storedKeys = const {},
  });

  final Map<RemoteProviderId, bool> initial;
  final Map<RemoteProviderId, String> storedKeys;
  final List<(RemoteProviderId, String)> connectCalls = [];
  final List<RemoteProviderId> testCalls = [];
  final List<RemoteProviderId> disconnectCalls = [];
  bool failConnect = false;
  bool failTest = false;
  bool failDisconnect = false;
  Completer<void>? pendingConnect;

  @override
  Map<RemoteProviderId, bool> build() => Map.of(initial);

  @override
  Future<void> connect(RemoteProviderId provider, String key) async {
    connectCalls.add((provider, key));
    if (failConnect) throw StateError('connection failed');
    await pendingConnect?.future;
    state = {...state, provider: true};
  }

  @override
  Future<void> test(RemoteProviderId provider) async {
    testCalls.add(provider);
    if (failTest) throw StateError('verification failed');
  }

  @override
  Future<void> disconnect(RemoteProviderId provider) async {
    disconnectCalls.add(provider);
    if (failDisconnect) throw StateError('removal failed');
    state = {...state, provider: false};
  }

  @override
  Future<String> apiKey(RemoteProviderId provider) async =>
      storedKeys[provider] ?? '';
}
