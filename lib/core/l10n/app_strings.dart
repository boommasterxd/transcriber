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

  String get obTag => _string(_StringKey.obTag);
  String get obTitle => _string(_StringKey.obTitle);
  String get obSub => _string(_StringKey.obSub);
  String get obF1t => _string(_StringKey.obF1t);
  String get obF1s => _string(_StringKey.obF1s);
  String get obF2t => _string(_StringKey.obF2t);
  String get obF2s => _string(_StringKey.obF2s);
  String get obF3t => _string(_StringKey.obF3t);
  String get obF3s => _string(_StringKey.obF3s);
  String get obCta => _string(_StringKey.obCta);
  String get obModels => _string(_StringKey.obModels);
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
  String get dl => _string(_StringKey.dl);
  String get delete => _string(_StringKey.delete);
  String get runningLocal => _string(_StringKey.runningLocal);
  String get autoLang => _string(_StringKey.autoLang);
  String get transLang => _string(_StringKey.transLang);
  String get proc => _string(_StringKey.proc);
  String get modeLocalT => _string(_StringKey.modeLocalT);
  String get modeLocalS => _string(_StringKey.modeLocalS);
  String get modeRemoteT => _string(_StringKey.modeRemoteT);
  String get modeRemoteS => _string(_StringKey.modeRemoteS);
  String get noteLocal => _string(_StringKey.noteLocal);
  String get noteRemote => _string(_StringKey.noteRemote);
  String get provider => _string(_StringKey.provider);
  String get apiKey => _string(_StringKey.apiKey);
  String get connect => _string(_StringKey.connect);
  String get connected => _string(_StringKey.connected);
  String get disconnect => _string(_StringKey.disconnect);
  String get keyPlaceholder => _string(_StringKey.keyPlaceholder);
  String get keyHint => _string(_StringKey.keyHint);
  String get remoteModel => _string(_StringKey.remoteModel);
  String get connectFirst => _string(_StringKey.connectFirst);
  String get processedWith => _string(_StringKey.processedWith);
  String get autoDel => _string(_StringKey.autoDel);
  String get autoDelSub => _string(_StringKey.autoDelSub);
  String get storageTemplate => _string(_StringKey.storageTemplate);
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
  String get modelMissingTitle => _string(_StringKey.modelMissingTitle);
  String get modelMissingBody => _string(_StringKey.modelMissingBody);
  String get goToSettings => _string(_StringKey.goToSettings);
  String get downloading => _string(_StringKey.downloading);
  String get todoSingular => _string(_StringKey.todoSingular);
  String get todoPlural => _string(_StringKey.todoPlural);
  String get tabEmptyTitle => _string(_StringKey.tabEmptyTitle);
  String get tabEmptySub => _string(_StringKey.tabEmptySub);
  String get tabRecord => _string(_StringKey.tabRecord);
  String get tabFile => _string(_StringKey.tabFile);
  String get audioDelTitle => _string(_StringKey.audioDelTitle);
  String get audioDelSub => _string(_StringKey.audioDelSub);
  String get keyMissing => _string(_StringKey.keyMissing);
  String get notLoaded => _string(_StringKey.notLoaded);
  String get deleteModelConfirm => _string(_StringKey.deleteModelConfirm);
  String get cancel => _string(_StringKey.cancel);
  String get toastDownloaded => _string(_StringKey.toastDownloaded);
  String get toastRemoved => _string(_StringKey.toastRemoved);
  String get privacyStatement => _string(_StringKey.privacyStatement);
  String get recommended => _string(_StringKey.recommended);
  String get asrExplain => _string(_StringKey.asrExplain);
  String get summaryExplain => _string(_StringKey.summaryExplain);
  String get obModelsT => _string(_StringKey.obModelsT);
  String get obModelsS => _string(_StringKey.obModelsS);
  String get obSimple => _string(_StringKey.obSimple);
  String get obAdvanced => _string(_StringKey.obAdvanced);
  String get obRecommendedSetup => _string(_StringKey.obRecommendedSetup);
  String get obDownloadGo => _string(_StringKey.obDownloadGo);
  String get obSkip => _string(_StringKey.obSkip);
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
  String get obTranscribeT => _string(_StringKey.obTranscribeT);
  String get obTranscribeS => _string(_StringKey.obTranscribeS);
  String get obSummaryT => _string(_StringKey.obSummaryT);
  String get obSummaryS => _string(_StringKey.obSummaryS);
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
  String get obPermNotifT => _string(_StringKey.obPermNotifT);
  String get obPermNotifS => _string(_StringKey.obPermNotifS);
  String get obPermEnable => _string(_StringKey.obPermEnable);
  String get obPermGranted => _string(_StringKey.obPermGranted);
  String get obPermRequiredHint => _string(_StringKey.obPermRequiredHint);
  String get obPermDeniedNote => _string(_StringKey.obPermDeniedNote);
  String get obPermBlockedNote => _string(_StringKey.obPermBlockedNote);
  String get obPermOpenSettings => _string(_StringKey.obPermOpenSettings);
  String get obPermLocked => _string(_StringKey.obPermLocked);
  String get svcChannelName => _string(_StringKey.svcChannelName);
  String get svcChannelDesc => _string(_StringKey.svcChannelDesc);
  String get deleteNoteTitle => _string(_StringKey.deleteNoteTitle);
  String get deleteNoteBody => _string(_StringKey.deleteNoteBody);
  String get noteDeleted => _string(_StringKey.noteDeleted);
  String get undo => _string(_StringKey.undo);
  String get summaryQualityHint => _string(_StringKey.summaryQualityHint);
  String get summarizeTitle => _string(_StringKey.summarizeTitle);
  String get summarizeSub => _string(_StringKey.summarizeSub);
  String get summaryOff => _string(_StringKey.summaryOff);
  String get backendSummary => _string(_StringKey.backendSummary);
  String get backendHint => _string(_StringKey.backendHint);
  String get whisperThreads => _string(_StringKey.whisperThreads);
  String get whisperThreadsHint => _string(_StringKey.whisperThreadsHint);
  String get autoDelNote => _string(_StringKey.autoDelNote);
  String get keyHelpTitleTemplate => _string(_StringKey.keyHelpTitleTemplate);
  String get keyHelpStep1Template => _string(_StringKey.keyHelpStep1Template);
  String get keyHelpStep2 => _string(_StringKey.keyHelpStep2);
  String get keyHelpStep3 => _string(_StringKey.keyHelpStep3);
  String get keyHelpNote => _string(_StringKey.keyHelpNote);
  String get openPage => _string(_StringKey.openPage);
  String get keyHelp => _string(_StringKey.keyHelp);
  String get badgeVeryFast => _string(_StringKey.badgeVeryFast);
  String get badgeFast => _string(_StringKey.badgeFast);
  String get badgeBalanced => _string(_StringKey.badgeBalanced);
  String get badgeAccurate => _string(_StringKey.badgeAccurate);
  String get badgeDetailed => _string(_StringKey.badgeDetailed);
  String get badgeMostCapable => _string(_StringKey.badgeMostCapable);
  String get badgeCheap => _string(_StringKey.badgeCheap);
  String get badgeReasoning => _string(_StringKey.badgeReasoning);
  String get providerSubOpenRouter => _string(_StringKey.providerSubOpenRouter);
  String get obConnectHint => _string(_StringKey.obConnectHint);
  String get obDownloadHint => _string(_StringKey.obDownloadHint);
  String get modelsReady => _string(_StringKey.modelsReady);
  String get ownRecording => _string(_StringKey.ownRecording);
  String get minutesAgoTemplate => _string(_StringKey.minutesAgoTemplate);
  String get hoursAgoTemplate => _string(_StringKey.hoursAgoTemplate);
  String get dateMonthDayTemplate => _string(_StringKey.dateMonthDayTemplate);

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

  String keyHelpStep1(String name) =>
      keyHelpStep1Template.replaceAll('{name}', name);

  String homeSub(int count) => homeSubTemplate.replaceAll('{n}', '$count');

  String storage(int models, String size) =>
      storageTemplate.replaceAll('{n}', '$models').replaceAll('{size}', size);

  String todoLabel(int count) =>
      '$count ${count == 1 ? todoSingular : todoPlural}';

  static AppStrings of(AppLanguage language) => _catalogs[language]!;

  static const Map<AppLanguage, AppStrings> _catalogs = {
    AppLanguage.de: AppStrings._(AppLanguage.de, _deStrings),
    AppLanguage.en: AppStrings._(AppLanguage.en, _enStrings),
  };
}
