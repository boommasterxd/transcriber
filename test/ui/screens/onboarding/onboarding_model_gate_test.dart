import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/remote/remote_api_client.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/state/remote_models_provider.dart';
import 'package:transcriber/ui/screens/settings/widgets/summary_section.dart';
import 'package:transcriber/ui/screens/settings/widgets/transcription_section.dart';

import 'onboarding_test_support.dart';

void main() {
  final strings = AppStrings.of(AppLanguage.de);
  useGrantedOnboardingPermissions();
  _registerUnavailableCatalogs(strings);
  _registerModelSelection(strings);
  _registerOptionalSummary(strings);
}

void _registerUnavailableCatalogs(AppStrings strings) {
  testWidgets(
    'empty catalogs block model selection despite a connected provider',
    (tester) async {
      await _openModels(
        tester,
        config: OnboardingTestConfig(
          connections: const {RemoteProviderId.google: true},
          modelCatalog: (_) async => const [],
        ),
      );
      _expectBlocked(strings);
    },
  );
  testWidgets('catalog failures block model selection', (tester) async {
    await _openModels(
      tester,
      config: OnboardingTestConfig(
        connections: const {RemoteProviderId.google: true},
        modelCatalog: (_) async => throw StateError('Test catalog unavailable'),
      ),
    );
    _expectBlocked(strings);
  });
  testWidgets('pending catalogs block until available models arrive', (
    tester,
  ) async {
    final pending = Completer<List<RemoteModelInfo>>();
    await _openModels(
      tester,
      config: OnboardingTestConfig(
        connections: const {RemoteProviderId.google: true},
        settings: AppSettings.initial().copyWith(
          summary: const SummarySettings(enabled: false),
        ),
        modelCatalog: (_) => pending.future,
      ),
    );
    _expectBlocked(strings);
    pending.complete(const [RemoteModelInfo(id: 'gemini-3.5-transcribe')]);
    await tester.pumpAndSettle();
    expect(find.text(strings.obNext), findsOneWidget);
  });
}

void _registerModelSelection(AppStrings strings) {
  testWidgets(
    'unavailable stored models require explicit available choices for both stages',
    (tester) async {
      final container = await _openModels(
        tester,
        config: OnboardingTestConfig(
          connections: const {RemoteProviderId.google: true},
          modelCatalog: (query) async => [
            RemoteModelInfo(
              id: query.forTranscription
                  ? 'available-transcription'
                  : 'available-summary',
            ),
          ],
        ),
      );
      _expectBlocked(strings);
      await _choose(tester, TranscriptionSection, 'available-transcription');
      _expectBlocked(strings);
      await _choose(tester, SummarySection, 'available-summary');
      expect(find.text(strings.obNext), findsOneWidget);
      await backOnboardingStep(tester);
      await tapOnboardingText(tester, strings.obNext);
      final settings = container.read(settingsControllerProvider);
      expect(
        settings.asrModelId(RemoteProviderId.google),
        'available-transcription',
      );
      expect(
        settings.summaryModelId(RemoteProviderId.google),
        'available-summary',
      );
      expect(find.text(strings.obNext), findsOneWidget);
      await tapOnboardingText(tester, strings.obNext);
      expect(find.text(strings.obLookT), findsOneWidget);
    },
  );
}

void _registerOptionalSummary(AppStrings strings) {
  testWidgets('disabled summary never requests its catalog during onboarding', (
    tester,
  ) async {
    final queries = <RemoteModelsQuery>[];
    final container = await openOnboardingStep(
      tester,
      1,
      config: OnboardingTestConfig(
        connections: const {RemoteProviderId.google: true},
        settings: AppSettings.initial().copyWith(
          summary: const SummarySettings(enabled: false),
        ),
        modelCatalog: (query) {
          queries.add(query);
          return defaultOnboardingModels(query);
        },
      ),
    );
    expect(queries, isEmpty);
    await tapOnboardingText(tester, strings.obNext);
    expect(queries, isNotEmpty);
    expect(queries.every((query) => query.forTranscription), isTrue);
    expect(
      container.read(settingsControllerProvider).summarizeEnabled,
      isFalse,
    );
    expect(find.text(strings.obNext), findsOneWidget);
  });

  testWidgets('disabling summary removes its unavailable model requirement', (
    tester,
  ) async {
    final container = await _openModels(
      tester,
      config: OnboardingTestConfig(
        connections: const {RemoteProviderId.google: true},
        modelCatalog: (query) async => query.forTranscription
            ? const [RemoteModelInfo(id: 'gemini-3.5-transcribe')]
            : const [],
      ),
    );
    _expectBlocked(strings);
    final toggle = find.descendant(
      of: find.byType(SummarySection),
      matching: find.byType(Switch),
    );
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(
      container.read(settingsControllerProvider).summarizeEnabled,
      isFalse,
    );
    expect(find.text(strings.obNext), findsOneWidget);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    _expectBlocked(strings);
  });
}

Future<ProviderContainer> _openModels(
  WidgetTester tester, {
  required OnboardingTestConfig config,
}) => openOnboardingStep(tester, 2, config: config);

void _expectBlocked(AppStrings strings) {
  expect(find.text(strings.obSelectModelsHint), findsOneWidget);
  expect(find.text(strings.obNext), findsNothing);
}

Future<void> _choose(WidgetTester tester, Type stage, String model) async {
  final within = find.byType(stage);
  final row = find.descendant(
    of: within,
    matching: find.byKey(
      Key(
        stage == TranscriptionSection
            ? 'model-row-transcription'
            : 'model-row-summary',
      ),
    ),
  );
  await tester.ensureVisible(row);
  await tester.tap(row);
  await tester.pumpAndSettle();
  await tapOnboardingText(tester, model);
}
