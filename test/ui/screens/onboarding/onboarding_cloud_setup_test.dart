import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/ui/screens/settings/widgets/provider_connect_card.dart';
import 'package:transcriber/ui/screens/settings/widgets/remote_model_sheet.dart';
import 'package:transcriber/ui/screens/settings/widgets/settings_navigation_tile.dart';
import 'package:transcriber/ui/screens/settings/widgets/summary_section.dart';

import 'onboarding_test_support.dart';

void main() {
  final strings = AppStrings.of(AppLanguage.de);
  useGrantedOnboardingPermissions();
  _registerConnections(strings);
  _registerIndependentStages(strings);
  _registerDisconnect(strings);
  _registerCompactLayout(strings);
}

void _registerConnections(AppStrings strings) {
  testWidgets(
    'rejected connection stays on key setup until another provider succeeds',
    (tester) async {
      await openOnboardingStep(
        tester,
        1,
        config: const OnboardingTestConfig(
          failedConnections: {RemoteProviderId.openai},
        ),
      );
      expect(find.text(strings.obConnectHint), findsOneWidget);
      await _connect(tester, RemoteProviderId.openai, strings);
      expect(find.text(strings.keyCheckFailed), findsOneWidget);
      expect(find.text(strings.obNext), findsNothing);
      await _connect(tester, RemoteProviderId.google, strings);
      expect(find.text(strings.obNext), findsOneWidget);
      await tapOnboardingText(tester, strings.obNext);
      expect(find.text(strings.obModelsT), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(SettingsNavigationTile), findsNothing);
      expect(find.text('OpenAI'), findsNothing);
    },
  );

  testWidgets(
    'OpenAI alone becomes the provider for both stages and keeps its key on back',
    (tester) async {
      final container = await openOnboardingStep(tester, 1);
      await _connect(tester, RemoteProviderId.openai, strings);
      await tapOnboardingText(tester, strings.obNext);
      final settings = container.read(settingsControllerProvider);
      expect(settings.asrProvider, RemoteProviderId.openai);
      expect(settings.summaryProvider, RemoteProviderId.openai);
      expect(find.text('Google Gemini'), findsNothing);
      expect(find.text(strings.transcriptionTaskDescription), findsOneWidget);
      expect(find.text(strings.summaryTaskDescription), findsOneWidget);
      expect(find.text(strings.obNext), findsOneWidget);
      await backOnboardingStep(tester);
      await _expand(tester, RemoteProviderId.openai);
      final openAiField = tester.widget<TextField>(
        _field(RemoteProviderId.openai),
      );
      expect(openAiField.controller!.text, 'test-openai-value');
      expect(openAiField.obscureText, isTrue);
      expect(_field(RemoteProviderId.google), findsNothing);
    },
  );
}

void _registerIndependentStages(AppStrings strings) {
  testWidgets(
    'connected selections stay independent across wizard back navigation',
    (tester) async {
      final initial = AppSettings.initial().copyWith(
        summary: const SummarySettings(provider: RemoteProviderId.openai),
      );
      final container = await openOnboardingStep(
        tester,
        2,
        config: OnboardingTestConfig(
          settings: initial,
          connections: const {
            RemoteProviderId.google: true,
            RemoteProviderId.openai: true,
          },
          keys: const {
            RemoteProviderId.google: 'google-value',
            RemoteProviderId.openai: 'openai-value',
          },
        ),
      );
      expect(
        container.read(settingsControllerProvider).summaryProvider,
        RemoteProviderId.openai,
      );
      await _chooseProvider(
        tester,
        'transcription',
        'OpenAI',
        'gpt-transcribe',
      );
      await _chooseProvider(
        tester,
        'summary',
        'Google Gemini',
        'gemini-3.7-flash',
      );
      await backOnboardingStep(tester);
      for (final provider in RemoteProviderId.values) {
        await _expand(tester, provider);
        final field = tester.widget<TextField>(_field(provider));
        expect(field.controller!.text, '${provider.name}-value');
        expect(field.obscureText, isTrue);
      }
      await tapOnboardingText(tester, strings.obNext);
      final settings = container.read(settingsControllerProvider);
      expect(settings.asrProvider, RemoteProviderId.openai);
      expect(settings.summaryProvider, RemoteProviderId.google);
    },
  );
}

void _registerDisconnect(AppStrings strings) {
  testWidgets(
    'disconnecting on back removes the provider from subsequent model choices',
    (tester) async {
      final container = await openOnboardingStep(
        tester,
        2,
        config: const OnboardingTestConfig(
          connections: {
            RemoteProviderId.google: true,
            RemoteProviderId.openai: true,
          },
          keys: {
            RemoteProviderId.google: 'google-value',
            RemoteProviderId.openai: 'openai-value',
          },
        ),
      );
      await backOnboardingStep(tester);
      await _expand(tester, RemoteProviderId.google);
      await tapOnboardingText(
        tester,
        strings.disconnect,
        within: _card(RemoteProviderId.google),
      );
      expect(
        tester
            .widget<TextField>(_field(RemoteProviderId.google))
            .controller!
            .text,
        isEmpty,
      );
      await tapOnboardingText(tester, strings.obNext);
      expect(find.text('Google Gemini'), findsNothing);
      final settings = container.read(settingsControllerProvider);
      expect(settings.asrProvider, RemoteProviderId.openai);
      expect(settings.summaryProvider, RemoteProviderId.openai);
      await backOnboardingStep(tester);
      await _expand(tester, RemoteProviderId.openai);
      await tapOnboardingText(
        tester,
        strings.disconnect,
        within: _card(RemoteProviderId.openai),
      );
      expect(find.text(strings.obConnectHint), findsOneWidget);
      expect(find.text(strings.obNext), findsNothing);
    },
  );
}

void _registerCompactLayout(AppStrings strings) {
  testWidgets(
    'both sequential screens remain usable at 320 dp with doubled text',
    (tester) async {
      await openOnboardingStep(
        tester,
        1,
        config: const OnboardingTestConfig(
          viewport: MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await _connect(tester, RemoteProviderId.google, strings);
      await tapOnboardingText(tester, strings.obNext);
      expect(find.text(strings.obModelsT), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.ensureVisible(find.byType(SummarySection));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tapOnboardingText(tester, strings.obNext);
      expect(find.text(strings.obLookT), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Finder _card(RemoteProviderId provider) => find.byWidgetPredicate(
  (widget) => widget is ProviderConnectCard && widget.provider == provider,
);

Finder _field(RemoteProviderId provider) =>
    find.descendant(of: _card(provider), matching: find.byType(TextField));

Future<void> _connect(
  WidgetTester tester,
  RemoteProviderId provider,
  AppStrings strings,
) async {
  await _expand(tester, provider);
  final field = _field(provider);
  await tester.ensureVisible(field);
  await tester.enterText(field, 'test-${provider.name}-value');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tapOnboardingText(tester, strings.connect, within: _card(provider));
}

Future<void> _expand(WidgetTester tester, RemoteProviderId provider) async {
  if (_field(provider).evaluate().isNotEmpty) return;
  await tapOnboardingText(
    tester,
    provider == RemoteProviderId.google ? 'Google Gemini' : 'OpenAI',
    within: _card(provider),
  );
}

Future<void> _chooseProvider(
  WidgetTester tester,
  String stage,
  String provider,
  String model,
) async {
  final row = find.byKey(Key('model-row-$stage'));
  await tester.ensureVisible(row);
  await tester.tap(row);
  await tester.pumpAndSettle();
  final sheet = find.byType(RemoteModelSheet);
  await tapOnboardingText(tester, provider, within: sheet);
  await tapOnboardingText(tester, model, within: sheet);
  expect(find.byType(RemoteModelSheet), findsNothing);
}
