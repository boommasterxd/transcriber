import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/transcription_language.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/ui/screens/settings/widgets/appearance_section.dart';
import 'package:transcriber/ui/screens/settings/widgets/language_section.dart';
import 'package:transcriber/ui/widgets/buttons.dart';
import 'package:transcriber/ui/widgets/segmented_control.dart';

void main() {
  testWidgets('appearance section changes every theme mode', (tester) async {
    late _FakeSettingsController controller;
    await tester.pumpWidget(
      _settingsApp(
        child: const AppearanceSection(),
        createController: () => controller = _FakeSettingsController(),
      ),
    );

    final strings = AppStrings.of(AppLanguage.de);
    await tester.tap(find.text(strings.light));
    await tester.pump();
    expect(controller.state.themeMode, AppThemeMode.light);

    await tester.tap(find.text(strings.dark));
    await tester.pump();
    expect(controller.state.themeMode, AppThemeMode.dark);

    await tester.tap(find.text(strings.system));
    await tester.pump();
    expect(controller.state.themeMode, AppThemeMode.system);
  });

  testWidgets('appearance section changes every accent swatch', (tester) async {
    late _FakeSettingsController controller;
    await tester.pumpWidget(
      _settingsApp(
        child: const AppearanceSection(),
        createController: () => controller = _FakeSettingsController(),
      ),
    );

    final swatches = find.descendant(
      of: find.byType(AccentSwatches),
      matching: find.byType(GestureDetector),
    );
    expect(swatches, findsNWidgets(AppAccent.values.length));

    for (var i = 0; i < AppAccent.values.length; i++) {
      await tester.tap(swatches.at(i));
      await tester.pump();
      expect(controller.state.accent, AppAccent.values[i]);
    }
  });

  testWidgets('language section switches app and transcription languages', (
    tester,
  ) async {
    late _FakeSettingsController controller;
    await tester.pumpWidget(
      _settingsApp(
        child: const LanguageSection(),
        createController: () => controller = _FakeSettingsController(),
      ),
    );

    final controls = find.byType(AnimatedSegmentedControl);
    expect(controls, findsNWidgets(2));
    expect(find.text(AppStrings.of(AppLanguage.de).uiLang), findsOneWidget);

    await tester.tap(
      find.descendant(of: controls.at(0), matching: find.text('English')),
    );
    await tester.pump();
    expect(controller.state.language, AppLanguage.en);
    expect(find.text(AppStrings.of(AppLanguage.en).uiLang), findsOneWidget);

    await tester.tap(
      find.descendant(of: controls.at(1), matching: find.text('Deutsch')),
    );
    await tester.pump();
    expect(controller.state.transcriptionLanguage, TranscriptionLanguage.de);

    await tester.tap(
      find.descendant(of: controls.at(1), matching: find.text('English')),
    );
    await tester.pump();
    expect(controller.state.transcriptionLanguage, TranscriptionLanguage.en);

    await tester.tap(
      find.descendant(of: controls.at(1), matching: find.text('Auto')),
    );
    await tester.pump();
    expect(controller.state.transcriptionLanguage, TranscriptionLanguage.auto);
  });
}

Widget _settingsApp({
  required Widget child,
  required _FakeSettingsController Function() createController,
}) {
  return ProviderScope(
    overrides: [settingsControllerProvider.overrideWith(createController)],
    child: MaterialApp(
      theme: ThemeData(
        extensions: <ThemeExtension<dynamic>>[AppPalette.light(AppAccent.blue)],
      ),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

class _FakeSettingsController extends SettingsController {
  _FakeSettingsController([AppSettings? initial])
    : _initial = initial ?? AppSettings.initial();

  final AppSettings _initial;

  @override
  AppSettings build() => _initial;

  @override
  Future<void> setThemeMode(AppThemeMode mode) async {
    state = state.copyWith(
      appearance: state.appearance.copyWith(themeMode: mode),
    );
  }

  @override
  Future<void> setAccent(AppAccent accent) async {
    state = state.copyWith(
      appearance: state.appearance.copyWith(accent: accent),
    );
  }

  @override
  Future<void> setLanguage(AppLanguage language) async {
    state = state.copyWith(
      appearance: state.appearance.copyWith(language: language),
    );
  }

  @override
  Future<void> setTranscriptionLanguage(TranscriptionLanguage language) async {
    state = state.copyWith(
      transcription: state.transcription.copyWith(language: language),
    );
  }
}
