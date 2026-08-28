import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';

const _expectedGermanCatalogFingerprint = 3993902868;
const _expectedEnglishCatalogFingerprint = 705188084;
const _fnvOffsetBasis = 0x811c9dc5;
const _fnvPrime = 0x01000193;

void main() {
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
      expect(germanValues, hasLength(199));
      expect(englishValues, hasLength(199));
      expect(germanValues, everyElement(isNotEmpty));
      expect(englishValues, everyElement(isNotEmpty));
      expect(_fingerprint(germanValues), _expectedGermanCatalogFingerprint);
      expect(_fingerprint(englishValues), _expectedEnglishCatalogFingerprint);
    });
  });

  group('templates and pluralization', () {
    final german = AppStrings.of(AppLanguage.de);
    final english = AppStrings.of(AppLanguage.en);

    test('substitutes numeric and named placeholders', () {
      expect(german.homeSub(0), '0 Sprachnachrichten verarbeitet');
      expect(english.homeSub(12), '12 voice notes processed');
      expect(german.storage(2, '1,5 GB'), '2 Modelle · 1,5 GB belegt');
      expect(english.storage(1, '500 MB'), '1 models · 500 MB used');
      expect(german.keyHelpTitle('OpenAI'), 'API-Schlüssel von OpenAI');
      expect(english.keyHelpTitle('OpenAI'), 'OpenAI API key');
      expect(
        german.keyHelpStep1('Anthropic'),
        '1. Bei Anthropic anmelden oder registrieren.',
      );
      expect(
        english.keyHelpStep1('Anthropic'),
        '1. Sign in or sign up at Anthropic.',
      );
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
  ..._catalogStart(strings),
  ..._catalogMiddle(strings),
  ..._catalogEnd(strings),
  ...strings.weekdaysShort,
];

List<String> _catalogStart(AppStrings strings) => [
  strings.obTag,
  strings.obTitle,
  strings.obSub,
  strings.obF1t,
  strings.obF1s,
  strings.obF2t,
  strings.obF2s,
  strings.obF3t,
  strings.obF3s,
  strings.obCta,
  strings.obModels,
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
  strings.dl,
  strings.delete,
  strings.runningLocal,
  strings.autoLang,
  strings.transLang,
  strings.proc,
  strings.modeLocalT,
  strings.modeLocalS,
  strings.modeRemoteT,
  strings.modeRemoteS,
  strings.noteLocal,
  strings.noteRemote,
  strings.provider,
  strings.apiKey,
  strings.connect,
  strings.connected,
  strings.disconnect,
  strings.keyPlaceholder,
  strings.keyHint,
  strings.remoteModel,
];

List<String> _catalogMiddle(AppStrings strings) => [
  strings.connectFirst,
  strings.processedWith,
  strings.autoDel,
  strings.autoDelSub,
  strings.storageTemplate,
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
  strings.mSpkTemplate,
  strings.voiceNote,
  strings.recordingLabel,
  strings.justNow,
  strings.processingTitle,
  strings.errorTitle,
  strings.retry,
  strings.dismiss,
  strings.modelMissingTitle,
  strings.modelMissingBody,
  strings.goToSettings,
  strings.downloading,
  strings.todoSingular,
  strings.todoPlural,
  strings.tabEmptyTitle,
  strings.tabEmptySub,
  strings.tabRecord,
  strings.tabFile,
  strings.audioDelTitle,
  strings.audioDelSub,
  strings.keyMissing,
  strings.notLoaded,
  strings.deleteModelConfirm,
  strings.cancel,
  strings.toastDownloaded,
  strings.toastRemoved,
  strings.privacyStatement,
  strings.recommended,
  strings.asrExplain,
  strings.summaryExplain,
  strings.obModelsT,
  strings.obModelsS,
  strings.obSimple,
  strings.obAdvanced,
  strings.obRecommendedSetup,
  strings.obDownloadGo,
  strings.obSkip,
  strings.obNext,
  strings.obStart,
  strings.obWelcomeT,
  strings.obWelcomeS,
  strings.obHiw1T,
  strings.obHiw1S,
  strings.obHiw2T,
];

List<String> _catalogEnd(AppStrings strings) => [
  strings.obHiw2S,
  strings.obHiw3T,
  strings.obHiw3S,
  strings.obTranscribeT,
  strings.obTranscribeS,
  strings.obSummaryT,
  strings.obSummaryS,
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
  strings.obPermNotifT,
  strings.obPermNotifS,
  strings.obPermEnable,
  strings.obPermGranted,
  strings.obPermRequiredHint,
  strings.obPermDeniedNote,
  strings.obPermBlockedNote,
  strings.obPermOpenSettings,
  strings.obPermLocked,
  strings.svcChannelName,
  strings.svcChannelDesc,
  strings.deleteNoteTitle,
  strings.deleteNoteBody,
  strings.noteDeleted,
  strings.undo,
  strings.summaryQualityHint,
  strings.summarizeTitle,
  strings.summarizeSub,
  strings.summaryOff,
  strings.backendSummary,
  strings.backendHint,
  strings.whisperThreads,
  strings.whisperThreadsHint,
  strings.autoDelNote,
  strings.keyHelpTitleTemplate,
  strings.keyHelpStep1Template,
  strings.keyHelpStep2,
  strings.keyHelpStep3,
  strings.keyHelpNote,
  strings.openPage,
  strings.keyHelp,
  strings.badgeVeryFast,
  strings.badgeFast,
  strings.badgeBalanced,
  strings.badgeAccurate,
  strings.badgeDetailed,
  strings.badgeMostCapable,
  strings.badgeCheap,
  strings.badgeReasoning,
  strings.providerSubOpenRouter,
  strings.obConnectHint,
  strings.obDownloadHint,
  strings.modelsReady,
  strings.ownRecording,
  strings.minutesAgoTemplate,
  strings.hoursAgoTemplate,
  strings.dateMonthDayTemplate,
];

int _fingerprint(List<String> values) {
  var hash = _fnvOffsetBasis;
  for (final value in values) {
    for (final codeUnit in [...value.codeUnits, 0]) {
      hash = ((hash ^ codeUnit) * _fnvPrime) & 0xffffffff;
    }
  }
  return hash;
}
