import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/state/providers.dart';
import 'package:transcriber/state/remote_models_provider.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/ui/screens/settings/widgets/privacy_section.dart';
import 'package:transcriber/ui/screens/settings/widgets/summary_section.dart';

void main() {
  final strings = AppStrings.of(AppLanguage.de);

  testWidgets('privacy switch reveals warning and updates settings', (
    tester,
  ) async {
    final controller = _TestSettingsController();
    await tester.pumpWidget(
      _settingsApp(child: const PrivacySection(), controller: controller),
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
  });

  testWidgets('summary switch controls cloud settings visibility', (
    tester,
  ) async {
    final controller = _TestSettingsController(
      AppSettings.initial().copyWith(
        summary: const SummarySettings(enabled: false),
      ),
    );
    await tester.pumpWidget(
      _settingsApp(child: const SummarySection(), controller: controller),
    );

    expect(find.text(strings.chooseModel), findsNothing);
    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(controller.state.summarizeEnabled, isTrue);
    expect(find.text(strings.connectFirst), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(controller.state.summarizeEnabled, isFalse);
    expect(find.text(strings.connectFirst), findsNothing);
  });
}

Widget _settingsApp({
  required Widget child,
  required _TestSettingsController controller,
}) => ProviderScope(
  overrides: [
    initialConnectionsProvider.overrideWithValue(const {}),
    settingsControllerProvider.overrideWith(() => controller),
    remoteModelsProvider.overrideWith((ref, query) async => const []),
  ],
  child: MaterialApp(
    theme: ThemeData(
      extensions: <ThemeExtension<dynamic>>[AppPalette.light(AppAccent.blue)],
    ),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

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
    state = state.copyWith(summary: state.summary.copyWith(enabled: value));
  }
}
