import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';

void main() {
  _registerAppLanguageTests();
  _registerCatalogTests();
  _registerByokTests();
  _registerMicrophoneTests();
  _registerTemplateTests();
  _registerWeekdayTests();
}

void _registerAppLanguageTests() {
  group('AppLanguage', () {
    test('exposes stable codes and defaults unknown values to German', () {
      expect(AppLanguage.de.code, 'de');
      expect(AppLanguage.en.code, 'en');
      expect(AppLanguage.fromCode('de'), AppLanguage.de);
      expect(AppLanguage.fromCode('en'), AppLanguage.en);
      expect(AppLanguage.fromCode(null), AppLanguage.de);
      expect(AppLanguage.fromCode('EN'), AppLanguage.de);
      expect(AppLanguage.fromCode('unknown'), AppLanguage.de);
    });
  });
}

void _registerCatalogTests() {
  group('AppStrings catalogs', () {
    test('selects complete German and English catalogs', () {
      final german = AppStrings.of(AppLanguage.de);
      final english = AppStrings.of(AppLanguage.en);
      final germanValues = _catalogValues(german);
      final englishValues = _catalogValues(english);

      expect(german.language, AppLanguage.de);
      expect(english.language, AppLanguage.en);
      expect(german.isDe, isTrue);
      expect(english.isDe, isFalse);
      expect(germanValues.length, englishValues.length);
      expect(germanValues, everyElement(isNotEmpty));
      expect(englishValues, everyElement(isNotEmpty));
    });

    test('keeps privacy copy explicit about cloud processing and storage', () {
      final german = AppStrings.of(AppLanguage.de);
      final english = AppStrings.of(AppLanguage.en);

      expect(german.privacyStatement, contains('Keine Telemetrie'));
      expect(german.privacyStatement, contains('zur Transkription'));
      expect(german.privacyStatement, contains('sicheren Gerätespeicher'));
      expect(english.privacyStatement, contains('No telemetry'));
      expect(english.privacyStatement, contains('transcription provider'));
      expect(english.privacyStatement, contains('secure device storage'));
    });
  });
}

void _registerByokTests() {
  group('BYOK key actions', () {
    final german = AppStrings.of(AppLanguage.de);
    final english = AppStrings.of(AppLanguage.en);
    _registerByokLifecycleTest(german, english);
    _registerByokInputTest(german, english);
    _registerByokHelpTest(german, english);
  });
}

void _registerByokLifecycleTest(AppStrings german, AppStrings english) {
  test('exposes the current key lifecycle actions in both languages', () {
    expect(german.connect, 'Verbinden');
    expect(german.connected, 'Verbunden');
    expect(german.disconnect, 'Trennen');
    expect(german.testKey, 'Testen');
    expect(german.replaceKey, 'Ersetzen');
    expect(german.keyVerified, 'Schlüssel erfolgreich geprüft.');
    expect(german.keyCheckFailed, contains('Abrechnung'));
    expect(english.connect, 'Connect');
    expect(english.connected, 'Connected');
    expect(english.disconnect, 'Disconnect');
    expect(english.testKey, 'Test');
    expect(english.replaceKey, 'Replace');
    expect(english.keyVerified, 'Key verified successfully.');
    expect(english.keyCheckFailed, contains('billing'));
  });
}

void _registerByokInputTest(AppStrings german, AppStrings english) {
  test('keeps key input guidance local and actionable', () {
    expect(german.keyPlaceholder, contains('Schlüssel einfügen'));
    expect(german.openAiKeyPlaceholder, contains('OpenAI'));
    expect(german.googleKeyPlaceholder, contains('Gemini'));
    expect(german.keyHint, contains('nur lokal'));
    expect(english.keyPlaceholder, contains('paste key'));
    expect(english.openAiKeyPlaceholder, contains('OpenAI'));
    expect(english.googleKeyPlaceholder, contains('Gemini'));
    expect(english.keyHint, contains('locally on device only'));
    expect(german.keyMissing, isNotEmpty);
    expect(english.keyMissing, isNotEmpty);
  });

  test('keeps provider descriptions specific to each processing stage', () {
    expect(german.transcriptionGoogleDescription, contains('Transcribe'));
    expect(german.summaryGoogleDescription, contains('Flash'));
    expect(german.summaryGoogleDescription, isNot(contains('Transcribe')));
    expect(german.summaryOpenAiDescription, contains('GPT-5'));
    expect(english.transcriptionOpenAiDescription, contains('gpt-transcribe'));
    expect(english.summaryOpenAiDescription, isNot(contains('transcribe')));
  });
}

void _registerByokHelpTest(AppStrings german, AppStrings english) {
  test('provides distinct provider-specific key help steps', () {
    expect(german.keyHelpTitle('OpenAI'), 'API-Schlüssel von OpenAI');
    expect(english.keyHelpTitle('Google Gemini'), 'Google Gemini API key');
    expect(german.keyHelpOpenAiSteps, hasLength(4));
    expect(german.keyHelpGoogleSteps, hasLength(4));
    expect(english.keyHelpOpenAiSteps, hasLength(4));
    expect(english.keyHelpGoogleSteps, hasLength(4));
    expect(
      german.keyHelpOpenAiSteps.join(' '),
      allOf(contains('OpenAI'), isNot(contains('Google AI Studio'))),
    );
    expect(
      german.keyHelpGoogleSteps.join(' '),
      allOf(contains('Google'), isNot(contains('OpenAI Platform'))),
    );
    expect(
      english.keyHelpOpenAiSteps.join(' '),
      allOf(contains('OpenAI'), isNot(contains('Google AI Studio'))),
    );
    expect(
      english.keyHelpGoogleSteps.join(' '),
      allOf(contains('Google'), isNot(contains('OpenAI Platform'))),
    );
    expect(german.keyHelpNote, contains('Cloud-Anbieter'));
    expect(english.keyHelpNote, contains('cloud providers'));
  });
}

void _registerMicrophoneTests() {
  group('microphone permission copy', () {
    final german = AppStrings.of(AppLanguage.de);
    final english = AppStrings.of(AppLanguage.en);

    test(
      'explains that microphone access is only needed for in-app recording',
      () {
        expect(german.micPermissionBody, contains('Mikrofon'));
        expect(german.obPermMicS, contains('direkt in der App'));
        expect(german.obPermsS, contains('nur für Aufnahmen'));
        expect(
          german.obPermsS.toLowerCase(),
          isNot(contains('benachrichtigung')),
        );
        expect(english.micPermissionBody, contains('microphone'));
        expect(english.obPermMicS, contains('right inside the app'));
        expect(english.obPermsS, contains('only required for recordings'));
        expect(english.obPermsS.toLowerCase(), isNot(contains('notification')));
      },
    );
  });
}

void _registerTemplateTests() {
  group('templates and pluralization', () {
    final german = AppStrings.of(AppLanguage.de);
    final english = AppStrings.of(AppLanguage.en);

    test('substitutes numeric and named placeholders', () {
      expect(german.homeSub(0), '0 Sprachnachrichten verarbeitet');
      expect(english.homeSub(12), '12 voice notes processed');
      expect(german.keyHelpTitle('OpenAI'), 'API-Schlüssel von OpenAI');
      expect(english.keyHelpTitle('OpenAI'), 'OpenAI API key');
      expect(german.minutesAgo(3), 'vor 3 Min');
      expect(english.minutesAgo(3), '3 min ago');
      expect(german.hoursAgo(4), 'vor 4 Std');
      expect(english.hoursAgo(4), '4h ago');
    });

    test('uses singular only for exactly one to-do', () {
      expect(german.todoLabel(1), '1 To-do');
      expect(german.todoLabel(0), '0 To-dos');
      expect(german.todoLabel(2), '2 To-dos');
      expect(english.todoLabel(1), '1 to-do');
      expect(english.todoLabel(-1), '-1 to-dos');
    });
  });
}

void _registerWeekdayTests() {
  group('weekdays and dates', () {
    final german = AppStrings.of(AppLanguage.de);
    final english = AppStrings.of(AppLanguage.en);

    test('provides every weekday in ISO weekday order', () {
      expect(german.weekdaysShort, ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']);
      expect(english.weekdaysShort, [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ]);
      expect(german.weekdayShort(DateTime.monday), 'Mo');
      expect(german.weekdayShort(DateTime.sunday), 'So');
      expect(english.weekdayShort(DateTime.monday), 'Mon');
      expect(english.weekdayShort(DateTime.sunday), 'Sun');
      expect(() => german.weekdayShort(0), throwsRangeError);
      expect(() => english.weekdayShort(8), throwsRangeError);
    });

    test('formats zero-padded month and day in language order', () {
      expect(german.dateMonthDay(4, 9), '04.09.');
      expect(german.dateMonthDay(14, 12), '14.12.');
      expect(english.dateMonthDay(4, 9), '09/04');
      expect(english.dateMonthDay(14, 12), '12/14');
    });
  });
}

List<String> _catalogValues(AppStrings strings) => [
  ..._catalogHomeValues(strings),
  ..._catalogSettingsValues(strings),
  ..._catalogKeyboardValues(strings),
  ..._catalogProviderValues(strings),
  ..._catalogShareValues(strings),
  ..._catalogNoteValues(strings),
  ..._catalogOnboardingValues(strings),
  ..._catalogActionValues(strings),
];

List<String> _catalogKeyboardValues(AppStrings strings) => [
  strings.keyboardSection,
  strings.keyboardTitle,
  strings.keyboardDescription,
  strings.keyboardEnabled,
  strings.keyboardDisabled,
  strings.keyboardSelected,
  strings.keyboardOpenSettings,
  strings.keyboardChoose,
  strings.keyboardPrivacy,
  strings.keyboardReady,
  strings.keyboardConnect,
  strings.keyboardRecording,
  strings.keyboardCorrecting,
  strings.keyboardReconnect,
  strings.keyboardStopping,
  strings.keyboardSensitiveField,
  strings.keyboardMicMissing,
  strings.keyboardKeyMissing,
  strings.keyboardConnectionError,
  strings.keyboardRetry,
  strings.keyboardCancel,
  strings.keyboardStop,
  strings.keyboardSwitchBack,
  strings.keyboardLivePreview,
  strings.keyboardSetup,
  strings.keyboardSetupTitle,
  strings.keyboardSetupSubtitle,
  strings.keyboardSetupProviderTitle,
  strings.keyboardSetupProviderBody,
  strings.keyboardSetupEnableTitle,
  strings.keyboardSetupEnableBody,
  strings.keyboardSetupChooseTitle,
  strings.keyboardSetupChooseBody,
  strings.keyboardSetupDone,
];

List<String> _catalogHomeValues(AppStrings strings) => [
  strings.homeTitle,
  strings.homeSubTemplate,
  strings.search,
  strings.modelActive,
  strings.secToday,
  strings.secWeek,
  strings.secEarlier,
  strings.emptyTitle,
  strings.emptySub,
  strings.pickTitle,
  strings.pickSub,
  strings.recTitle,
  strings.recording,
  strings.recPaused,
  strings.recHint,
  strings.recResume,
  strings.recPause,
  strings.recStopShort,
  strings.recCancel,
];

List<String> _catalogSettingsValues(AppStrings strings) => [
  strings.micPermissionTitle,
  strings.micPermissionBody,
  strings.setTitle,
  strings.setAppear,
  strings.setAsr,
  strings.setLlm,
  strings.setLang,
  strings.setPriv,
  strings.uiLang,
  strings.theme,
  strings.system,
  strings.light,
  strings.dark,
  strings.accentC,
  strings.delete,
  strings.autoLang,
  strings.transLang,
  strings.proc,
];

List<String> _catalogProviderValues(AppStrings strings) => [
  strings.provider,
  strings.apiKey,
  strings.connect,
  strings.connected,
  strings.disconnect,
  strings.testKey,
  strings.replaceKey,
  strings.keyVerified,
  strings.keyCheckFailed,
  strings.keyPlaceholder,
  strings.openAiKeyPlaceholder,
  strings.googleKeyPlaceholder,
  strings.keyHint,
  strings.remoteModel,
  strings.showModels,
  strings.hideModels,
  strings.transcriptionOpenAiDescription,
  strings.transcriptionGoogleDescription,
  strings.summaryOpenAiDescription,
  strings.summaryGoogleDescription,
  strings.connectFirst,
  strings.processedWith,
  strings.autoDel,
  strings.autoDelSub,
];

List<String> _catalogShareValues(AppStrings strings) => [
  strings.shTranscribe,
  strings.shSummarize,
  strings.shStep1,
  strings.shStep2,
  strings.shFrom,
  strings.shSummary,
  strings.shPoints,
  strings.shActions,
  strings.shShow,
  strings.shHide,
  strings.shTranscript,
  strings.shCopy,
  strings.shCopied,
  strings.shShare,
  strings.shSave,
];

List<String> _catalogNoteValues(AppStrings strings) => [
  strings.mSpkTemplate,
  strings.voiceNote,
  strings.recordingLabel,
  strings.justNow,
  strings.processingTitle,
  strings.errorTitle,
  strings.retry,
  strings.dismiss,
  strings.goToSettings,
  strings.todoSingular,
  strings.todoPlural,
  strings.tabEmptyTitle,
  strings.tabEmptySub,
  strings.tabRecord,
  strings.tabFile,
  strings.audioDelTitle,
  strings.audioDelSub,
  strings.keyMissing,
  strings.cancel,
  strings.privacyStatement,
];

List<String> _catalogOnboardingValues(AppStrings strings) => [
  strings.obModelsT,
  strings.obModelsS,
  strings.obNext,
  strings.obStart,
  strings.obWelcomeT,
  strings.obWelcomeS,
  strings.obHiw1T,
  strings.obHiw1S,
  strings.obHiw2T,
  strings.obHiw2S,
  strings.obHiw3T,
  strings.obHiw3S,
  strings.obLookT,
  strings.obLookS,
  strings.obPrivacyT,
  strings.obPrivacyS,
  strings.obReadyT,
  strings.obReadyS,
  strings.obPermsT,
  strings.obPermsS,
  strings.obPermMicT,
  strings.obPermMicS,
  strings.obPermEnable,
  strings.obPermGranted,
  strings.obPermRequiredHint,
  strings.obPermDeniedNote,
  strings.obPermBlockedNote,
  strings.obPermOpenSettings,
  strings.obPermLocked,
];

List<String> _catalogActionValues(AppStrings strings) => [
  strings.deleteNoteTitle,
  strings.deleteNoteBody,
  strings.noteDeleted,
  strings.undo,
  strings.summarizeTitle,
  strings.summarizeSub,
  strings.summaryOff,
  strings.autoDelNote,
  strings.keyHelpTitleTemplate,
  strings.keyHelpNote,
  strings.openPage,
  strings.keyHelp,
  strings.obConnectHint,
  strings.ownRecording,
  strings.minutesAgoTemplate,
  strings.hoursAgoTemplate,
  strings.dateMonthDayTemplate,
  ...strings.keyHelpOpenAiSteps,
  ...strings.keyHelpGoogleSteps,
  ...strings.weekdaysShort,
];
