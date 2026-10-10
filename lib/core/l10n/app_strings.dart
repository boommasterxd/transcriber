/// All user-facing copy for the app, in German and English. The active set is
/// chosen by [AppLanguage] and exposed through the settings controller.
///
/// Strings are a direct port of the DE/EN dictionaries from the original design.
library;

part 'app_string_key.dart';
part 'app_strings_de.dart';
part 'app_strings_en.dart';

enum AppLanguage {
  de('de'),
  en('en');

  const AppLanguage(this.code);

  final String code;

  static AppLanguage fromCode(String? code) => AppLanguage.values.firstWhere(
    (language) => language.code == code,
    orElse: () => AppLanguage.de,
  );
}

class AppStrings {
  const AppStrings._(this.language, this._values);

  final AppLanguage language;
  final Map<_StringKey, Object> _values;

  bool get isDe => language == AppLanguage.de;

  String _string(_StringKey key) => _values[key]! as String;

  String get homeTitle => _string(_StringKey.homeTitle);
  String get homeSubTemplate => _string(_StringKey.homeSubTemplate);
  String get search => _string(_StringKey.search);
  String get modelActive => _string(_StringKey.modelActive);
  String get secToday => _string(_StringKey.secToday);
  String get secWeek => _string(_StringKey.secWeek);
  String get secEarlier => _string(_StringKey.secEarlier);
  String get emptyTitle => _string(_StringKey.emptyTitle);
  String get emptySub => _string(_StringKey.emptySub);
  String get pickTitle => _string(_StringKey.pickTitle);
  String get pickSub => _string(_StringKey.pickSub);
  String get recTitle => _string(_StringKey.recTitle);
  String get recording => _string(_StringKey.recording);
  String get recPaused => _string(_StringKey.recPaused);
  String get recHint => _string(_StringKey.recHint);
  String get recResume => _string(_StringKey.recResume);
  String get recPause => _string(_StringKey.recPause);
  String get recStopShort => _string(_StringKey.recStopShort);
  String get recCancel => _string(_StringKey.recCancel);
  String get micPermissionTitle => _string(_StringKey.micPermissionTitle);
  String get micPermissionBody => _string(_StringKey.micPermissionBody);
  String get setTitle => _string(_StringKey.setTitle);
  String get setModels => _string(_StringKey.setModels);
  String get setGeneral => _string(_StringKey.setGeneral);
  String get appVersion => _string(_StringKey.appVersion);
  String get versionUnavailable => _string(_StringKey.versionUnavailable);
  String get apiKeysDescription => _string(_StringKey.apiKeysDescription);
  String get setAppear => _string(_StringKey.setAppear);
  String get setAsr => _string(_StringKey.setAsr);
  String get setLlm => _string(_StringKey.setLlm);
  String get setLang => _string(_StringKey.setLang);
  String get setPriv => _string(_StringKey.setPriv);
  String get uiLang => _string(_StringKey.uiLang);
  String get theme => _string(_StringKey.theme);
  String get system => _string(_StringKey.system);
  String get light => _string(_StringKey.light);
  String get dark => _string(_StringKey.dark);
  String get accentC => _string(_StringKey.accentC);
  String get delete => _string(_StringKey.delete);
  String get autoLang => _string(_StringKey.autoLang);
  String get transLang => _string(_StringKey.transLang);
  String get proc => _string(_StringKey.proc);
  String get provider => _string(_StringKey.provider);
  String get apiKey => _string(_StringKey.apiKey);
  String get connect => _string(_StringKey.connect);
  String get connected => _string(_StringKey.connected);
  String get disconnect => _string(_StringKey.disconnect);
  String get testKey => _string(_StringKey.testKey);
  String get replaceKey => _string(_StringKey.replaceKey);
  String get keyVerified => _string(_StringKey.keyVerified);
  String get keyCheckFailed => _string(_StringKey.keyCheckFailed);
  String get keyPlaceholder => _string(_StringKey.keyPlaceholder);
  String get openAiKeyPlaceholder => _string(_StringKey.openAiKeyPlaceholder);
  String get googleKeyPlaceholder => _string(_StringKey.googleKeyPlaceholder);
  String get keyHint => _string(_StringKey.keyHint);
  String get remoteModel => _string(_StringKey.remoteModel);
  String get showModels => _string(_StringKey.showModels);
  String get hideModels => _string(_StringKey.hideModels);
  String get transcriptionOpenAiDescription =>
      _string(_StringKey.transcriptionOpenAiDescription);
  String get transcriptionGoogleDescription =>
      _string(_StringKey.transcriptionGoogleDescription);
  String get summaryOpenAiDescription =>
      _string(_StringKey.summaryOpenAiDescription);
  String get summaryGoogleDescription =>
      _string(_StringKey.summaryGoogleDescription);
  String get connectFirst => _string(_StringKey.connectFirst);
  String get noModels => _string(_StringKey.noModels);
  String get modelUnavailable => _string(_StringKey.modelUnavailable);
  String get chooseModel => _string(_StringKey.chooseModel);
  String get processedWith => _string(_StringKey.processedWith);
  String get autoDel => _string(_StringKey.autoDel);
  String get autoDelSub => _string(_StringKey.autoDelSub);
  String get shTranscribe => _string(_StringKey.shTranscribe);
  String get shSummarize => _string(_StringKey.shSummarize);
  String get shStep1 => _string(_StringKey.shStep1);
  String get shStep2 => _string(_StringKey.shStep2);
  String get shFrom => _string(_StringKey.shFrom);
  String get shSummary => _string(_StringKey.shSummary);
  String get shPoints => _string(_StringKey.shPoints);
  String get shActions => _string(_StringKey.shActions);
  String get shShow => _string(_StringKey.shShow);
  String get shHide => _string(_StringKey.shHide);
  String get shTranscript => _string(_StringKey.shTranscript);
  String get shCopy => _string(_StringKey.shCopy);
  String get shCopied => _string(_StringKey.shCopied);
  String get shShare => _string(_StringKey.shShare);
  String get shSave => _string(_StringKey.shSave);
  String get mSpkTemplate => _string(_StringKey.mSpkTemplate);
  String get voiceNote => _string(_StringKey.voiceNote);
  String get recordingLabel => _string(_StringKey.recordingLabel);
  String get justNow => _string(_StringKey.justNow);
  String get processingTitle => _string(_StringKey.processingTitle);
  String get errorTitle => _string(_StringKey.errorTitle);
  String get retry => _string(_StringKey.retry);
  String get dismiss => _string(_StringKey.dismiss);
  String get goToSettings => _string(_StringKey.goToSettings);
  String get todoSingular => _string(_StringKey.todoSingular);
  String get todoPlural => _string(_StringKey.todoPlural);
  String get tabEmptyTitle => _string(_StringKey.tabEmptyTitle);
  String get tabEmptySub => _string(_StringKey.tabEmptySub);
  String get tabRecord => _string(_StringKey.tabRecord);
  String get tabFile => _string(_StringKey.tabFile);
  String get audioDelTitle => _string(_StringKey.audioDelTitle);
  String get audioDelSub => _string(_StringKey.audioDelSub);
  String get keyMissing => _string(_StringKey.keyMissing);
  String get cancel => _string(_StringKey.cancel);
  String get privacyStatement => _string(_StringKey.privacyStatement);
  String get obModelsT => _string(_StringKey.obModelsT);
  String get obModelsS => _string(_StringKey.obModelsS);
  String get obNext => _string(_StringKey.obNext);
  String get obStart => _string(_StringKey.obStart);
  String get obWelcomeT => _string(_StringKey.obWelcomeT);
  String get obWelcomeS => _string(_StringKey.obWelcomeS);
  String get obHiw1T => _string(_StringKey.obHiw1T);
  String get obHiw1S => _string(_StringKey.obHiw1S);
  String get obHiw2T => _string(_StringKey.obHiw2T);
  String get obHiw2S => _string(_StringKey.obHiw2S);
  String get obHiw3T => _string(_StringKey.obHiw3T);
  String get obHiw3S => _string(_StringKey.obHiw3S);
  String get obLookT => _string(_StringKey.obLookT);
  String get obLookS => _string(_StringKey.obLookS);
  String get obPrivacyT => _string(_StringKey.obPrivacyT);
  String get obPrivacyS => _string(_StringKey.obPrivacyS);
  String get obReadyT => _string(_StringKey.obReadyT);
  String get obReadyS => _string(_StringKey.obReadyS);
  String get obPermsT => _string(_StringKey.obPermsT);
  String get obPermsS => _string(_StringKey.obPermsS);
  String get obPermMicT => _string(_StringKey.obPermMicT);
  String get obPermMicS => _string(_StringKey.obPermMicS);
  String get obPermEnable => _string(_StringKey.obPermEnable);
  String get obPermGranted => _string(_StringKey.obPermGranted);
  String get obPermRequiredHint => _string(_StringKey.obPermRequiredHint);
  String get obPermDeniedNote => _string(_StringKey.obPermDeniedNote);
  String get obPermBlockedNote => _string(_StringKey.obPermBlockedNote);
  String get obPermOpenSettings => _string(_StringKey.obPermOpenSettings);
  String get obPermLocked => _string(_StringKey.obPermLocked);
  String get deleteNoteTitle => _string(_StringKey.deleteNoteTitle);
  String get deleteNoteBody => _string(_StringKey.deleteNoteBody);
  String get noteDeleted => _string(_StringKey.noteDeleted);
  String get undo => _string(_StringKey.undo);
  String get summarizeTitle => _string(_StringKey.summarizeTitle);
  String get summarizeSub => _string(_StringKey.summarizeSub);
  String get summaryOff => _string(_StringKey.summaryOff);
  String get summaryFailedTitle => _string(_StringKey.summaryFailedTitle);
  String get summaryFailedBody => _string(_StringKey.summaryFailedBody);
  String get autoDelNote => _string(_StringKey.autoDelNote);
  String get keyHelpTitleTemplate => _string(_StringKey.keyHelpTitleTemplate);
  String get keyHelpNote => _string(_StringKey.keyHelpNote);
  List<String> get keyHelpOpenAiSteps =>
      _values[_StringKey.keyHelpOpenAiSteps]! as List<String>;
  List<String> get keyHelpGoogleSteps =>
      _values[_StringKey.keyHelpGoogleSteps]! as List<String>;
  String get openPage => _string(_StringKey.openPage);
  String get keyHelp => _string(_StringKey.keyHelp);
  String get obConnectHint => _string(_StringKey.obConnectHint);
  String get ownRecording => _string(_StringKey.ownRecording);
  String get minutesAgoTemplate => _string(_StringKey.minutesAgoTemplate);
  String get hoursAgoTemplate => _string(_StringKey.hoursAgoTemplate);
  String get dateMonthDayTemplate => _string(_StringKey.dateMonthDayTemplate);
  String get keyboardSection => _string(_StringKey.keyboardSection);
  String get keyboardTitle => _string(_StringKey.keyboardTitle);
  String get keyboardDescription => _string(_StringKey.keyboardDescription);
  String get keyboardGuideTitle => _string(_StringKey.keyboardGuideTitle);
  String get keyboardGuideBenefit => _string(_StringKey.keyboardGuideBenefit);
  String get keyboardGuideEnable => _string(_StringKey.keyboardGuideEnable);
  String get keyboardGuideDictate => _string(_StringKey.keyboardGuideDictate);
  String get keyboardGuideFinish => _string(_StringKey.keyboardGuideFinish);
  String get keyboardEnabled => _string(_StringKey.keyboardEnabled);
  String get keyboardDisabled => _string(_StringKey.keyboardDisabled);
  String get keyboardSelected => _string(_StringKey.keyboardSelected);
  String get keyboardOpenSettings => _string(_StringKey.keyboardOpenSettings);
  String get keyboardChoose => _string(_StringKey.keyboardChoose);
  String get keyboardPrivacy => _string(_StringKey.keyboardPrivacy);
  String get keyboardReady => _string(_StringKey.keyboardReady);
  String get keyboardConnect => _string(_StringKey.keyboardConnect);
  String get keyboardRecording => _string(_StringKey.keyboardRecording);
  String get keyboardCorrecting => _string(_StringKey.keyboardCorrecting);
  String get keyboardReconnect => _string(_StringKey.keyboardReconnect);
  String get keyboardStopping => _string(_StringKey.keyboardStopping);
  String get keyboardSensitiveField =>
      _string(_StringKey.keyboardSensitiveField);
  String get keyboardMicMissing => _string(_StringKey.keyboardMicMissing);
  String get keyboardKeyMissing => _string(_StringKey.keyboardKeyMissing);
  String get keyboardConnectionError =>
      _string(_StringKey.keyboardConnectionError);
  String get keyboardAuthenticationError =>
      _string(_StringKey.keyboardAuthenticationError);
  String get keyboardQuotaError => _string(_StringKey.keyboardQuotaError);
  String get keyboardModelError => _string(_StringKey.keyboardModelError);
  String get keyboardConfigurationError =>
      _string(_StringKey.keyboardConfigurationError);
  String get keyboardTimeoutError => _string(_StringKey.keyboardTimeoutError);
  String get keyboardRetry => _string(_StringKey.keyboardRetry);
  String get keyboardCancel => _string(_StringKey.keyboardCancel);
  String get keyboardStop => _string(_StringKey.keyboardStop);
  String get keyboardSwitchBack => _string(_StringKey.keyboardSwitchBack);
  String get keyboardDeleteCharacter =>
      _string(_StringKey.keyboardDeleteCharacter);
  String get keyboardLivePreview => _string(_StringKey.keyboardLivePreview);
  String get keyboardSetup => _string(_StringKey.keyboardSetup);
  String get keyboardManage => _string(_StringKey.keyboardManage);
  String get keyboardSetupTitle => _string(_StringKey.keyboardSetupTitle);
  String get keyboardSetupSubtitle => _string(_StringKey.keyboardSetupSubtitle);
  String get keyboardConfiguredTitle =>
      _string(_StringKey.keyboardConfiguredTitle);
  String get keyboardConfiguredBody =>
      _string(_StringKey.keyboardConfiguredBody);
  String get keyboardSetupProviderTitle =>
      _string(_StringKey.keyboardSetupProviderTitle);
  String get keyboardSetupProviderBody =>
      _string(_StringKey.keyboardSetupProviderBody);
  String get keyboardSetupEnableTitle =>
      _string(_StringKey.keyboardSetupEnableTitle);
  String get keyboardSetupEnableBody =>
      _string(_StringKey.keyboardSetupEnableBody);
  String get keyboardSetupChooseTitle =>
      _string(_StringKey.keyboardSetupChooseTitle);
  String get keyboardSetupChooseBody =>
      _string(_StringKey.keyboardSetupChooseBody);
  String get keyboardSetupDone => _string(_StringKey.keyboardSetupDone);
  String get keyboardDone => _string(_StringKey.keyboardDone);

  List<String> get weekdaysShort =>
      _values[_StringKey.weekdaysShort]! as List<String>;

  String minutesAgo(int count) =>
      minutesAgoTemplate.replaceAll('{n}', '$count');

  String hoursAgo(int count) => hoursAgoTemplate.replaceAll('{n}', '$count');

  String weekdayShort(int weekday) => weekdaysShort[weekday - 1];

  String dateMonthDay(int day, int month) {
    final paddedDay = day.toString().padLeft(2, '0');
    final paddedMonth = month.toString().padLeft(2, '0');
    return dateMonthDayTemplate
        .replaceAll('{d}', paddedDay)
        .replaceAll('{m}', paddedMonth);
  }

  String keyHelpTitle(String name) =>
      keyHelpTitleTemplate.replaceAll('{name}', name);

  String homeSub(int count) => homeSubTemplate.replaceAll('{n}', '$count');

  String todoLabel(int count) =>
      '$count ${count == 1 ? todoSingular : todoPlural}';

  static AppStrings of(AppLanguage language) => _catalogs[language]!;

  static const Map<AppLanguage, AppStrings> _catalogs = {
    AppLanguage.de: AppStrings._(AppLanguage.de, _deStrings),
    AppLanguage.en: AppStrings._(AppLanguage.en, _enStrings),
  };
}
