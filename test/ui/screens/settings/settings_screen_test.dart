import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/state/connections_controller.dart';
import 'package:transcriber/state/remote_models_provider.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/ui/screens/settings/settings_screen.dart';
import 'package:transcriber/ui/screens/settings/widgets/provider_connect_card.dart';

void main() {
  final strings = AppStrings.of(AppLanguage.de);

  testWidgets('screen renders credentials inline with both cloud stages', (
    tester,
  ) async {
    await tester.pumpWidget(_settingsScreenApp());

    expect(find.text(strings.setTitle), findsOneWidget);
    expect(find.text(strings.setAsr.toUpperCase()), findsOneWidget);
    await _scrollToText(tester, strings.setLlm.toUpperCase());
    expect(find.text(strings.setLlm.toUpperCase()), findsOneWidget);

    final cards = tester
        .widgetList<ProviderConnectCard>(find.byType(ProviderConnectCard))
        .toList();
    expect(cards, hasLength(2));
    expect(
      cards.map((card) => card.provider),
      orderedEquals(RemoteProviderId.values),
    );
    expect(find.text(strings.apiKey.toUpperCase()), findsNothing);

    await _scrollToText(tester, strings.setLang.toUpperCase());
    expect(find.text(strings.setLang.toUpperCase()), findsOneWidget);
    await _scrollToText(tester, strings.setAppear.toUpperCase());
    expect(find.text(strings.setAppear.toUpperCase()), findsOneWidget);
    await _scrollToText(tester, strings.setPriv.toUpperCase());
    expect(find.text(strings.setPriv.toUpperCase()), findsOneWidget);
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

Widget _settingsScreenApp() => ProviderScope(
  overrides: [
    settingsControllerProvider.overrideWith(_ScreenSettingsController.new),
    connectionsControllerProvider.overrideWith(_ScreenConnections.new),
    remoteModelsProvider.overrideWith((ref, query) async => const []),
  ],
  child: MaterialApp(
    theme: ThemeData(extensions: [AppPalette.light(AppAccent.blue)]),
    home: const SettingsScreen(),
  ),
);

class _ScreenSettingsController extends SettingsController {
  @override
  AppSettings build() => AppSettings.initial().copyWith(
    asrProvider: RemoteProviderId.openai,
    summaryProvider: RemoteProviderId.google,
  );
}

class _ScreenConnections extends ConnectionsController {
  @override
  Map<RemoteProviderId, bool> build() => const {};

  @override
  Future<String> apiKey(RemoteProviderId provider) async => '';
}
