import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/core/utils/formatting.dart';
import 'package:transcriber/data/catalog/gemma_catalog.dart';
import 'package:transcriber/data/catalog/whisper_catalog.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/processing_mode.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/state/connections_controller.dart';
import 'package:transcriber/state/model_manager_controller.dart';
import 'package:transcriber/state/remote_models_provider.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/ui/screens/settings/settings_screen.dart';

void main() {
  final strings = AppStrings.of(AppLanguage.de);

  testWidgets('screen renders every settings section and local backend', (
    tester,
  ) async {
    await tester.pumpWidget(
      _settingsScreenApp(settings: AppSettings.initial()),
    );

    expect(find.text(strings.setTitle), findsOneWidget);
    expect(find.text(strings.setAsr.toUpperCase()), findsOneWidget);
    await _scrollToText(tester, strings.setLlm.toUpperCase());
    expect(find.text(strings.setLlm.toUpperCase()), findsOneWidget);
    await _scrollToText(tester, 'BACKEND');
    expect(find.text('BACKEND'), findsOneWidget);
    await _scrollToText(tester, strings.setLang.toUpperCase());
    expect(find.text(strings.setLang.toUpperCase()), findsOneWidget);
    await _scrollToText(tester, strings.setAppear.toUpperCase());
    expect(find.text(strings.setAppear.toUpperCase()), findsOneWidget);
    await _scrollToText(tester, strings.setPriv.toUpperCase());
    expect(find.text(strings.setPriv.toUpperCase()), findsOneWidget);
  });

  testWidgets('backend is hidden when no enabled stage runs locally', (
    tester,
  ) async {
    final settings = AppSettings.initial().copyWith(
      asrMode: ProcessingMode.cloud,
      summarizeEnabled: false,
    );

    await tester.pumpWidget(_settingsScreenApp(settings: settings));
    await _scrollToText(tester, strings.setPriv.toUpperCase());

    expect(find.text('BACKEND'), findsNothing);
    expect(find.text(strings.setPriv.toUpperCase()), findsOneWidget);
  });

  testWidgets('storage summary counts downloaded local models', (tester) async {
    final whisper = WhisperCatalog.models.first;
    final gemma = GemmaCatalog.models.first;
    final manager = ModelManagerState(
      whisper: {
        whisper.id: const ModelStatus(status: DownloadStatus.downloaded),
      },
      gemma: {gemma.id: const ModelStatus(status: DownloadStatus.downloaded)},
    );
    final expected = strings.storage(
      2,
      formatBytes(whisper.sizeBytes + gemma.sizeBytes),
    );

    await tester.pumpWidget(
      _settingsScreenApp(settings: AppSettings.initial(), manager: manager),
    );
    await _scrollToText(tester, expected);

    expect(find.text(expected), findsOneWidget);
  });
}

Future<void> _scrollToText(WidgetTester tester, String text) async {
  final target = find.text(text);
  for (var attempt = 0; attempt < 30 && target.evaluate().isEmpty; attempt++) {
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
  }
  expect(target, findsOneWidget);
}

Widget _settingsScreenApp({
  required AppSettings settings,
  ModelManagerState manager = const ModelManagerState(),
}) {
  return ProviderScope(
    overrides: [
      settingsControllerProvider.overrideWith(
        () => _ScreenSettingsController(settings),
      ),
      connectionsControllerProvider.overrideWith(_ScreenConnections.new),
      modelManagerControllerProvider.overrideWith(
        () => _ScreenModelManager(manager),
      ),
      remoteModelsProvider.overrideWith((ref, query) async => const []),
    ],
    child: MaterialApp(
      theme: ThemeData(
        extensions: <ThemeExtension<dynamic>>[AppPalette.light(AppAccent.blue)],
      ),
      home: const SettingsScreen(),
    ),
  );
}

class _ScreenSettingsController extends SettingsController {
  _ScreenSettingsController(this.initial);

  final AppSettings initial;

  @override
  AppSettings build() => initial;
}

class _ScreenConnections extends ConnectionsController {
  @override
  Map<RemoteProviderId, bool> build() => const {};
}

class _ScreenModelManager extends ModelManagerController {
  _ScreenModelManager(this.initial);

  final ModelManagerState initial;

  @override
  ModelManagerState build() => initial;
}
