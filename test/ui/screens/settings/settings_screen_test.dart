import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/ui/screens/settings/widgets/appearance_section.dart';
import 'package:transcriber/ui/screens/settings/widgets/keyboard_section.dart';
import 'package:transcriber/ui/screens/settings/widgets/keyboard_guide.dart';
import 'package:transcriber/ui/screens/settings/widgets/language_section.dart';
import 'package:transcriber/ui/screens/settings/widgets/privacy_section.dart';
import 'package:transcriber/ui/screens/settings/widgets/provider_connect_card.dart';
import 'package:transcriber/ui/screens/settings/widgets/settings_navigation_tile.dart';
import 'package:transcriber/ui/screens/settings/widgets/summary_section.dart';
import 'package:transcriber/ui/screens/settings/widgets/transcription_section.dart';

import '../../keyboard/keyboard_settings_test_support.dart';
import 'settings_navigation_test_support.dart';

void main() {
  _registerOverviewTests();
  _registerGeneralTests();
  _registerKeyboardGuideTest();
  _registerModelNavigationTests();
  _registerResponsiveNavigationTest();
}

void _registerOverviewTests() {
  final strings = AppStrings.of(AppLanguage.de);
  final categories = [
    (strings.keyboardSection, KeyboardSection),
    (strings.setGeneral, LanguageSection),
  ];
  for (final (title, sectionType) in categories) {
    testWidgets('overview opens $title and returns to categories', (
      tester,
    ) async {
      final keyboard = FakeKeyboardSettingsChannel(
        const MethodChannel('app/keyboard/settings'),
      )..install();
      addTearDown(keyboard.uninstall);
      await pumpSettingsNavigation(tester);
      expect(find.byType(SettingsNavigationTile), findsNWidgets(3));
      expect(find.text(strings.setLang), findsNothing);
      expect(find.text(strings.setAppear), findsNothing);
      expect(find.text(strings.setPriv), findsNothing);
      expect(find.byType(ProviderConnectCard), findsNothing);
      expect(find.byType(Switch), findsNothing);

      await openSettingsDestination(tester, title);
      expect(find.byType(sectionType), findsOneWidget);
      expect(find.text(title), findsOneWidget);
      await goBackInSettings(tester);
      expect(find.text(strings.setTitle), findsOneWidget);
      expect(find.byType(SettingsNavigationTile), findsNWidgets(3));
    });
  }
}

void _registerGeneralTests() {
  final strings = AppStrings.of(AppLanguage.de);
  testWidgets('language change updates page title and overview on return', (
    tester,
  ) async {
    final container = await pumpSettingsNavigation(tester);
    await openSettingsDestination(tester, strings.setGeneral);
    await tester.tap(find.text('English').first);
    await tester.pumpAndSettle();
    final english = AppStrings.of(AppLanguage.en);
    expect(find.text(english.setGeneral), findsOneWidget);
    expect(container.read(settingsControllerProvider).language, AppLanguage.en);
    await goBackInSettings(tester);
    expect(find.text(english.setTitle), findsOneWidget);
    expect(find.text(english.setModels), findsOneWidget);
  });
  testWidgets('general combines language, appearance and privacy controls', (
    tester,
  ) async {
    await pumpSettingsNavigation(tester);
    await openSettingsDestination(tester, strings.setGeneral);
    expect(find.byType(LanguageSection), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(AppearanceSection), 200);
    expect(find.byType(AppearanceSection), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(PrivacySection), 200);
    expect(find.byType(PrivacySection), findsOneWidget);
    expect(find.byType(SettingsNavigationTile), findsNothing);
    expect(find.text(strings.setGeneral), findsOneWidget);
  });
}

void _registerKeyboardGuideTest() {
  final strings = AppStrings.of(AppLanguage.de);
  testWidgets('keyboard keeps setup and explains three dictation steps', (
    tester,
  ) async {
    final keyboard = FakeKeyboardSettingsChannel(
      const MethodChannel('app/keyboard/settings'),
    )..install();
    addTearDown(keyboard.uninstall);
    await pumpSettingsNavigation(tester);
    await openSettingsDestination(tester, strings.keyboardSection);
    expect(find.byType(KeyboardSection), findsOneWidget);
    expect(find.text(strings.keyboardPrivacy), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(KeyboardGuide), 200);
    expect(find.text(strings.keyboardGuideTitle), findsOneWidget);
    expect(find.text(strings.keyboardGuideBenefit), findsOneWidget);
    expect(find.text(strings.keyboardGuideEnable), findsOneWidget);
    expect(find.text(strings.keyboardGuideDictate), findsOneWidget);
    expect(find.text(strings.keyboardGuideFinish), findsOneWidget);
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
    expect(find.text('3.'), findsOneWidget);
  });
}

void _registerModelNavigationTests() {
  testWidgets('model choices and shared API keys have separate nested pages', (
    tester,
  ) async {
    final strings = AppStrings.of(AppLanguage.de);
    await pumpSettingsNavigation(tester);
    await openSettingsDestination(tester, strings.setModels);
    expect(find.byType(TranscriptionSection), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(SummarySection), 250);
    await tester.pumpAndSettle();
    expect(find.byType(SummarySection), findsOneWidget);
    expect(find.byType(ProviderConnectCard), findsNothing);

    await openSettingsDestination(tester, strings.providerConnectionsTitle);
    await tester.ensureVisible(find.byType(ProviderConnectCard).last);
    final cards = tester.widgetList<ProviderConnectCard>(
      find.byType(ProviderConnectCard),
    );
    expect(cards.map((card) => card.provider), RemoteProviderId.values);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TranscriptionSection), findsNothing);
    await goBackInSettings(tester);
    expect(find.text(strings.setModels), findsOneWidget);
    await goBackInSettings(tester);
    expect(find.text(strings.setTitle), findsOneWidget);
  });
}

void _registerResponsiveNavigationTest() {
  testWidgets('overview and nested pages fit narrow screens with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSettingsNavigation(
      tester,
      textScaler: const TextScaler.linear(2),
    );
    final strings = AppStrings.of(AppLanguage.de);
    expect(tester.takeException(), isNull);
    await openSettingsDestination(tester, strings.setModels);
    expect(tester.takeException(), isNull);
    await openSettingsDestination(tester, strings.providerConnectionsTitle);
    expect(tester.takeException(), isNull);
    await goBackInSettings(tester);
    await goBackInSettings(tester);
    await openSettingsDestination(tester, strings.setGeneral);
    await tester.scrollUntilVisible(find.byType(AppearanceSection), 200);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.byType(PrivacySection), 200);
    expect(tester.takeException(), isNull);
    await goBackInSettings(tester);
    final keyboard = FakeKeyboardSettingsChannel(
      const MethodChannel('app/keyboard/settings'),
    )..install();
    addTearDown(keyboard.uninstall);
    await tester.scrollUntilVisible(find.text(strings.keyboardSection), -250);
    await openSettingsDestination(tester, strings.keyboardSection);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text(strings.keyboardGuideFinish),
      250,
    );
    expect(tester.takeException(), isNull);
  });
}
