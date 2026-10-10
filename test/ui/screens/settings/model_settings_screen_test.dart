import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/ui/screens/settings/widgets/summary_section.dart';
import 'package:transcriber/ui/screens/settings/widgets/transcription_section.dart';

import 'settings_navigation_test_support.dart';

void main() {
  testWidgets(
    'stage choices stay independent across provider and page changes',
    (tester) async {
      final strings = AppStrings.of(AppLanguage.de);
      final container = await pumpSettingsNavigation(tester);
      await openSettingsDestination(tester, strings.setModels);
      await _tapStageText(tester, TranscriptionSection, 'OpenAI');
      var settings = container.read(settingsControllerProvider);
      expect(settings.asrProvider, RemoteProviderId.openai);
      expect(settings.summaryProvider, RemoteProviderId.google);
      await _tapStageText(tester, TranscriptionSection, strings.showModels);
      await tester.tap(find.text('openai-model'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(settingsControllerProvider)
            .asrModelId(RemoteProviderId.openai),
        'openai-model',
      );

      final summary = find.byType(SummarySection);
      await tester.scrollUntilVisible(summary, 250);
      await tester.pumpAndSettle();
      await _tapStageText(tester, SummarySection, strings.showModels);
      await tester.ensureVisible(find.text('google-model'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('google-model'));
      await tester.pumpAndSettle();
      settings = container.read(settingsControllerProvider);
      expect(settings.summaryModelId(RemoteProviderId.google), 'google-model');
      expect(settings.asrModelId(RemoteProviderId.openai), 'openai-model');

      await _tapStageText(tester, SummarySection, 'OpenAI');
      await _tapStageText(tester, SummarySection, strings.showModels);
      await _tapStageText(tester, SummarySection, 'openai-model');
      settings = container.read(settingsControllerProvider);
      expect(settings.summaryProvider, RemoteProviderId.openai);
      expect(settings.summaryModelId(RemoteProviderId.openai), 'openai-model');
      expect(settings.asrModelId(RemoteProviderId.openai), 'openai-model');
      await _tapStageText(tester, SummarySection, 'Google Gemini');
      expect(
        container
            .read(settingsControllerProvider)
            .summaryModelId(RemoteProviderId.google),
        'google-model',
      );

      await tester.scrollUntilVisible(find.text(strings.apiKey), -250);
      await openSettingsDestination(tester, strings.apiKey);
      await goBackInSettings(tester);
      await goBackInSettings(tester);
      await openSettingsDestination(tester, strings.setModels);
      expect(find.text('openai-model'), findsOneWidget);
      expect(
        container
            .read(settingsControllerProvider)
            .summaryModelId(RemoteProviderId.google),
        'google-model',
      );
    },
  );
}

Future<void> _tapStageText(WidgetTester tester, Type stage, String text) async {
  final target = find.descendant(
    of: find.byType(stage),
    matching: find.text(text),
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}
