import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_theme.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/state/connections_controller.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/ui/screens/settings/widgets/provider_connect_card.dart';

void main() {
  final strings = AppStrings.of(AppLanguage.de);

  for (final provider in RemoteProviderId.values) {
    group(provider.name, () {
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
        expect(find.byType(TextField), findsOneWidget);

        controller.failConnect = false;
        await tester.tap(find.text(strings.connect));
        await tester.pump();

        expect(controller.connectCalls, hasLength(2));
        expect(find.textContaining(strings.connected), findsOneWidget);
        expect(find.text(strings.keyVerified), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
      });

      testWidgets('checks a stored key and reports verification failures', (
        tester,
      ) async {
        final controller = _FakeConnectionsController(
          initial: {provider: true},
        );
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
      });

      testWidgets('replaces the stored key for the selected provider', (
        tester,
      ) async {
        final controller = _FakeConnectionsController(
          initial: {provider: true},
        );
        await _pumpCard(tester, provider, controller);

        await tester.tap(find.text(strings.replaceKey));
        await tester.pump();
        expect(find.byType(TextField), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'replacement-key');
        await tester.tap(find.text(strings.connect));
        await tester.pump();

        expect(controller.connectCalls, [(provider, 'replacement-key')]);
        expect(find.textContaining(strings.connected), findsOneWidget);
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
        expect(find.textContaining(strings.connected), findsOneWidget);

        controller.failDisconnect = false;
        await tester.tap(find.text(strings.disconnect));
        await tester.pump();
        expect(controller.disconnectCalls, [provider, provider]);
        expect(find.byType(TextField), findsOneWidget);
      });
    });
  }
}

Future<void> _pumpCard(
  WidgetTester tester,
  RemoteProviderId provider,
  _FakeConnectionsController connections,
) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      settingsControllerProvider.overrideWith(_FakeSettingsController.new),
      connectionsControllerProvider.overrideWith(() => connections),
    ],
    child: MaterialApp(
      theme: AppTheme.build(Brightness.light, AppAccent.blue),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ProviderConnectCard(provider: provider),
        ),
      ),
    ),
  ),
);

class _FakeSettingsController extends SettingsController {
  @override
  AppSettings build() => AppSettings.initial();
}

class _FakeConnectionsController extends ConnectionsController {
  _FakeConnectionsController({this.initial = const {}});

  final Map<RemoteProviderId, bool> initial;
  final List<(RemoteProviderId, String)> connectCalls = [];
  final List<RemoteProviderId> testCalls = [];
  final List<RemoteProviderId> disconnectCalls = [];
  bool failConnect = false;
  bool failTest = false;
  bool failDisconnect = false;

  @override
  Map<RemoteProviderId, bool> build() => Map.of(initial);

  @override
  Future<void> connect(RemoteProviderId provider, String key) async {
    connectCalls.add((provider, key));
    if (failConnect) throw StateError('connection failed');
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
}
