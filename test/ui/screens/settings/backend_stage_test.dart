import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/inference_backend.dart';
import 'package:transcriber/data/models/processing_mode.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/ui/screens/settings/widgets/backend_section.dart';
import 'package:transcriber/ui/screens/settings/widgets/stage_explainer.dart';

void main() {
  final strings = AppStrings.of(AppLanguage.de);

  testWidgets(
    'backend section shows local summary and transcription controls',
    (tester) async {
      late _TestSettingsController controller;
      await tester.pumpWidget(
        _settingsApp(
          const BackendSection(),
          createController: () => controller = _TestSettingsController(),
        ),
      );

      expect(find.text(strings.backendSummary), findsOneWidget);
      expect(find.text(strings.backendHint), findsOneWidget);
      expect(find.text(strings.whisperThreads), findsOneWidget);
      expect(find.text(strings.whisperThreadsHint), findsOneWidget);
      expect(find.text('Auto'), findsOneWidget);
      expect(find.text('GPU'), findsOneWidget);
      expect(find.text('CPU'), findsOneWidget);
      expect(find.text('NPU'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);

      for (final backend in InferenceBackend.values) {
        await tester.tap(find.text(backend.label));
        await tester.pump();
        expect(controller.state.gemmaBackend, backend);
      }
    },
  );

  testWidgets('backend section updates thread count from slider', (
    tester,
  ) async {
    late _TestSettingsController controller;
    await tester.pumpWidget(
      _settingsApp(
        const BackendSection(),
        createController: () => controller = _TestSettingsController(),
      ),
    );

    final slider = find.byType(Slider);
    expect(slider, findsOneWidget);
    await tester.drag(slider, const Offset(160, 0));
    await tester.pump();

    expect(controller.state.whisperThreads, greaterThan(4));
    expect(controller.state.whisperThreads, lessThanOrEqualTo(8));
    expect(find.text('${controller.state.whisperThreads}'), findsOneWidget);
  });

  testWidgets('backend controls follow local and cloud stage visibility', (
    tester,
  ) async {
    late _TestSettingsController controller;
    await tester.pumpWidget(
      _settingsApp(
        const BackendSection(),
        createController: () => controller = _TestSettingsController(
          AppSettings.initial().copyWith(summaryMode: ProcessingMode.cloud),
        ),
      ),
    );

    expect(find.text(strings.backendSummary), findsNothing);
    expect(find.text(strings.whisperThreads), findsOneWidget);

    await controller.setAsrMode(ProcessingMode.cloud);
    await tester.pump();
    expect(find.text(strings.backendSummary), findsNothing);
    expect(find.text(strings.whisperThreads), findsNothing);

    await controller.setSummaryMode(ProcessingMode.onDevice);
    await tester.pump();
    expect(find.text(strings.backendSummary), findsOneWidget);
    expect(find.text(strings.whisperThreads), findsNothing);

    await controller.setSummarizeEnabled(false);
    await tester.pump();
    expect(find.text(strings.backendSummary), findsNothing);
  });

  testWidgets('stage explainer renders its text and information icon', (
    tester,
  ) async {
    await tester.pumpWidget(_themed(StageExplainer(text: strings.asrExplain)));

    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    expect(find.text(strings.asrExplain), findsOneWidget);

    await tester.pumpWidget(
      _themed(StageExplainer(text: strings.summaryExplain)),
    );
    expect(find.text(strings.summaryExplain), findsOneWidget);
  });
}

Widget _settingsApp(
  Widget child, {
  required _TestSettingsController Function() createController,
}) {
  return ProviderScope(
    overrides: [settingsControllerProvider.overrideWith(createController)],
    child: _themed(Scaffold(body: SingleChildScrollView(child: child))),
  );
}

Widget _themed(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      extensions: <ThemeExtension<dynamic>>[AppPalette.light(AppAccent.blue)],
    ),
    home: child,
  );
}

class _TestSettingsController extends SettingsController {
  _TestSettingsController([AppSettings? initial])
    : _initial = initial ?? AppSettings.initial();

  final AppSettings _initial;

  @override
  AppSettings build() => _initial;

  @override
  Future<void> setAsrMode(ProcessingMode mode) async {
    state = state.copyWith(asrMode: mode);
  }

  @override
  Future<void> setSummaryMode(ProcessingMode mode) async {
    state = state.copyWith(summaryMode: mode);
  }

  @override
  Future<void> setSummarizeEnabled(bool value) async {
    state = state.copyWith(summarizeEnabled: value);
  }

  @override
  Future<void> setGemmaBackend(InferenceBackend backend) async {
    state = state.copyWith(gemmaBackend: backend);
  }

  @override
  Future<void> setWhisperThreads(int threads) async {
    state = state.copyWith(whisperThreads: threads.clamp(1, 8));
  }
}
