// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AppSettingsTableTable extends AppSettingsTable
    with TableInfo<$AppSettingsTableTable, AppSettingsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _themeModeMeta = const VerificationMeta(
    'themeMode',
  );
  @override
  late final GeneratedColumn<String> themeMode = GeneratedColumn<String>(
    'theme_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accentMeta = const VerificationMeta('accent');
  @override
  late final GeneratedColumn<String> accent = GeneratedColumn<String>(
    'accent',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transcriptionLanguageMeta =
      const VerificationMeta('transcriptionLanguage');
  @override
  late final GeneratedColumn<String> transcriptionLanguage =
      GeneratedColumn<String>(
        'transcription_language',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _asrProviderMeta = const VerificationMeta(
    'asrProvider',
  );
  @override
  late final GeneratedColumn<String> asrProvider = GeneratedColumn<String>(
    'asr_provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryProviderMeta = const VerificationMeta(
    'summaryProvider',
  );
  @override
  late final GeneratedColumn<String> summaryProvider = GeneratedColumn<String>(
    'summary_provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _asrModelMeta = const VerificationMeta(
    'asrModel',
  );
  @override
  late final GeneratedColumn<String> asrModel = GeneratedColumn<String>(
    'asr_model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryModelMeta = const VerificationMeta(
    'summaryModel',
  );
  @override
  late final GeneratedColumn<String> summaryModel = GeneratedColumn<String>(
    'summary_model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _autoDeleteAudioMeta = const VerificationMeta(
    'autoDeleteAudio',
  );
  @override
  late final GeneratedColumn<bool> autoDeleteAudio = GeneratedColumn<bool>(
    'auto_delete_audio',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_delete_audio" IN (0, 1))',
    ),
  );
  static const VerificationMeta _summarizeEnabledMeta = const VerificationMeta(
    'summarizeEnabled',
  );
  @override
  late final GeneratedColumn<bool> summarizeEnabled = GeneratedColumn<bool>(
    'summarize_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("summarize_enabled" IN (0, 1))',
    ),
  );
  static const VerificationMeta _onboardedMeta = const VerificationMeta(
    'onboarded',
  );
  @override
  late final GeneratedColumn<bool> onboarded = GeneratedColumn<bool>(
    'onboarded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("onboarded" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    themeMode,
    accent,
    language,
    transcriptionLanguage,
    asrProvider,
    summaryProvider,
    asrModel,
    summaryModel,
    autoDeleteAudio,
    summarizeEnabled,
    onboarded,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('theme_mode')) {
      context.handle(
        _themeModeMeta,
        themeMode.isAcceptableOrUnknown(data['theme_mode']!, _themeModeMeta),
      );
    } else if (isInserting) {
      context.missing(_themeModeMeta);
    }
    if (data.containsKey('accent')) {
      context.handle(
        _accentMeta,
        accent.isAcceptableOrUnknown(data['accent']!, _accentMeta),
      );
    } else if (isInserting) {
      context.missing(_accentMeta);
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    } else if (isInserting) {
      context.missing(_languageMeta);
    }
    if (data.containsKey('transcription_language')) {
      context.handle(
        _transcriptionLanguageMeta,
        transcriptionLanguage.isAcceptableOrUnknown(
          data['transcription_language']!,
          _transcriptionLanguageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transcriptionLanguageMeta);
    }
    if (data.containsKey('asr_provider')) {
      context.handle(
        _asrProviderMeta,
        asrProvider.isAcceptableOrUnknown(
          data['asr_provider']!,
          _asrProviderMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_asrProviderMeta);
    }
    if (data.containsKey('summary_provider')) {
      context.handle(
        _summaryProviderMeta,
        summaryProvider.isAcceptableOrUnknown(
          data['summary_provider']!,
          _summaryProviderMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_summaryProviderMeta);
    }
    if (data.containsKey('asr_model')) {
      context.handle(
        _asrModelMeta,
        asrModel.isAcceptableOrUnknown(data['asr_model']!, _asrModelMeta),
      );
    } else if (isInserting) {
      context.missing(_asrModelMeta);
    }
    if (data.containsKey('summary_model')) {
      context.handle(
        _summaryModelMeta,
        summaryModel.isAcceptableOrUnknown(
          data['summary_model']!,
          _summaryModelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_summaryModelMeta);
    }
    if (data.containsKey('auto_delete_audio')) {
      context.handle(
        _autoDeleteAudioMeta,
        autoDeleteAudio.isAcceptableOrUnknown(
          data['auto_delete_audio']!,
          _autoDeleteAudioMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_autoDeleteAudioMeta);
    }
    if (data.containsKey('summarize_enabled')) {
      context.handle(
        _summarizeEnabledMeta,
        summarizeEnabled.isAcceptableOrUnknown(
          data['summarize_enabled']!,
          _summarizeEnabledMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_summarizeEnabledMeta);
    }
    if (data.containsKey('onboarded')) {
      context.handle(
        _onboardedMeta,
        onboarded.isAcceptableOrUnknown(data['onboarded']!, _onboardedMeta),
      );
    } else if (isInserting) {
      context.missing(_onboardedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSettingsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      themeMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_mode'],
      )!,
      accent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accent'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      transcriptionLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcription_language'],
      )!,
      asrProvider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asr_provider'],
      )!,
      summaryProvider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_provider'],
      )!,
      asrModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asr_model'],
      )!,
      summaryModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_model'],
      )!,
      autoDeleteAudio: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_delete_audio'],
      )!,
      summarizeEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}summarize_enabled'],
      )!,
      onboarded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}onboarded'],
      )!,
    );
  }

  @override
  $AppSettingsTableTable createAlias(String alias) {
    return $AppSettingsTableTable(attachedDatabase, alias);
  }
}

class AppSettingsTableData extends DataClass
    implements Insertable<AppSettingsTableData> {
  final int id;
  final String themeMode;
  final String accent;
  final String language;
  final String transcriptionLanguage;
  final String asrProvider;
  final String summaryProvider;
  final String asrModel;
  final String summaryModel;
  final bool autoDeleteAudio;
  final bool summarizeEnabled;
  final bool onboarded;
  const AppSettingsTableData({
    required this.id,
    required this.themeMode,
    required this.accent,
    required this.language,
    required this.transcriptionLanguage,
    required this.asrProvider,
    required this.summaryProvider,
    required this.asrModel,
    required this.summaryModel,
    required this.autoDeleteAudio,
    required this.summarizeEnabled,
    required this.onboarded,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['theme_mode'] = Variable<String>(themeMode);
    map['accent'] = Variable<String>(accent);
    map['language'] = Variable<String>(language);
    map['transcription_language'] = Variable<String>(transcriptionLanguage);
    map['asr_provider'] = Variable<String>(asrProvider);
    map['summary_provider'] = Variable<String>(summaryProvider);
    map['asr_model'] = Variable<String>(asrModel);
    map['summary_model'] = Variable<String>(summaryModel);
    map['auto_delete_audio'] = Variable<bool>(autoDeleteAudio);
    map['summarize_enabled'] = Variable<bool>(summarizeEnabled);
    map['onboarded'] = Variable<bool>(onboarded);
    return map;
  }

  AppSettingsTableCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsTableCompanion(
      id: Value(id),
      themeMode: Value(themeMode),
      accent: Value(accent),
      language: Value(language),
      transcriptionLanguage: Value(transcriptionLanguage),
      asrProvider: Value(asrProvider),
      summaryProvider: Value(summaryProvider),
      asrModel: Value(asrModel),
      summaryModel: Value(summaryModel),
      autoDeleteAudio: Value(autoDeleteAudio),
      summarizeEnabled: Value(summarizeEnabled),
      onboarded: Value(onboarded),
    );
  }

  factory AppSettingsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingsTableData(
      id: serializer.fromJson<int>(json['id']),
      themeMode: serializer.fromJson<String>(json['themeMode']),
      accent: serializer.fromJson<String>(json['accent']),
      language: serializer.fromJson<String>(json['language']),
      transcriptionLanguage: serializer.fromJson<String>(
        json['transcriptionLanguage'],
      ),
      asrProvider: serializer.fromJson<String>(json['asrProvider']),
      summaryProvider: serializer.fromJson<String>(json['summaryProvider']),
      asrModel: serializer.fromJson<String>(json['asrModel']),
      summaryModel: serializer.fromJson<String>(json['summaryModel']),
      autoDeleteAudio: serializer.fromJson<bool>(json['autoDeleteAudio']),
      summarizeEnabled: serializer.fromJson<bool>(json['summarizeEnabled']),
      onboarded: serializer.fromJson<bool>(json['onboarded']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'themeMode': serializer.toJson<String>(themeMode),
      'accent': serializer.toJson<String>(accent),
      'language': serializer.toJson<String>(language),
      'transcriptionLanguage': serializer.toJson<String>(transcriptionLanguage),
      'asrProvider': serializer.toJson<String>(asrProvider),
      'summaryProvider': serializer.toJson<String>(summaryProvider),
      'asrModel': serializer.toJson<String>(asrModel),
      'summaryModel': serializer.toJson<String>(summaryModel),
      'autoDeleteAudio': serializer.toJson<bool>(autoDeleteAudio),
      'summarizeEnabled': serializer.toJson<bool>(summarizeEnabled),
      'onboarded': serializer.toJson<bool>(onboarded),
    };
  }

  AppSettingsTableData copyWith({
    int? id,
    String? themeMode,
    String? accent,
    String? language,
    String? transcriptionLanguage,
    String? asrProvider,
    String? summaryProvider,
    String? asrModel,
    String? summaryModel,
    bool? autoDeleteAudio,
    bool? summarizeEnabled,
    bool? onboarded,
  }) => AppSettingsTableData(
    id: id ?? this.id,
    themeMode: themeMode ?? this.themeMode,
    accent: accent ?? this.accent,
    language: language ?? this.language,
    transcriptionLanguage: transcriptionLanguage ?? this.transcriptionLanguage,
    asrProvider: asrProvider ?? this.asrProvider,
    summaryProvider: summaryProvider ?? this.summaryProvider,
    asrModel: asrModel ?? this.asrModel,
    summaryModel: summaryModel ?? this.summaryModel,
    autoDeleteAudio: autoDeleteAudio ?? this.autoDeleteAudio,
    summarizeEnabled: summarizeEnabled ?? this.summarizeEnabled,
    onboarded: onboarded ?? this.onboarded,
  );
  AppSettingsTableData copyWithCompanion(AppSettingsTableCompanion data) {
    return AppSettingsTableData(
      id: data.id.present ? data.id.value : this.id,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      accent: data.accent.present ? data.accent.value : this.accent,
      language: data.language.present ? data.language.value : this.language,
      transcriptionLanguage: data.transcriptionLanguage.present
          ? data.transcriptionLanguage.value
          : this.transcriptionLanguage,
      asrProvider: data.asrProvider.present
          ? data.asrProvider.value
          : this.asrProvider,
      summaryProvider: data.summaryProvider.present
          ? data.summaryProvider.value
          : this.summaryProvider,
      asrModel: data.asrModel.present ? data.asrModel.value : this.asrModel,
      summaryModel: data.summaryModel.present
          ? data.summaryModel.value
          : this.summaryModel,
      autoDeleteAudio: data.autoDeleteAudio.present
          ? data.autoDeleteAudio.value
          : this.autoDeleteAudio,
      summarizeEnabled: data.summarizeEnabled.present
          ? data.summarizeEnabled.value
          : this.summarizeEnabled,
      onboarded: data.onboarded.present ? data.onboarded.value : this.onboarded,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsTableData(')
          ..write('id: $id, ')
          ..write('themeMode: $themeMode, ')
          ..write('accent: $accent, ')
          ..write('language: $language, ')
          ..write('transcriptionLanguage: $transcriptionLanguage, ')
          ..write('asrProvider: $asrProvider, ')
          ..write('summaryProvider: $summaryProvider, ')
          ..write('asrModel: $asrModel, ')
          ..write('summaryModel: $summaryModel, ')
          ..write('autoDeleteAudio: $autoDeleteAudio, ')
          ..write('summarizeEnabled: $summarizeEnabled, ')
          ..write('onboarded: $onboarded')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    themeMode,
    accent,
    language,
    transcriptionLanguage,
    asrProvider,
    summaryProvider,
    asrModel,
    summaryModel,
    autoDeleteAudio,
    summarizeEnabled,
    onboarded,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingsTableData &&
          other.id == this.id &&
          other.themeMode == this.themeMode &&
          other.accent == this.accent &&
          other.language == this.language &&
          other.transcriptionLanguage == this.transcriptionLanguage &&
          other.asrProvider == this.asrProvider &&
          other.summaryProvider == this.summaryProvider &&
          other.asrModel == this.asrModel &&
          other.summaryModel == this.summaryModel &&
          other.autoDeleteAudio == this.autoDeleteAudio &&
          other.summarizeEnabled == this.summarizeEnabled &&
          other.onboarded == this.onboarded);
}

class AppSettingsTableCompanion extends UpdateCompanion<AppSettingsTableData> {
  final Value<int> id;
  final Value<String> themeMode;
  final Value<String> accent;
  final Value<String> language;
  final Value<String> transcriptionLanguage;
  final Value<String> asrProvider;
  final Value<String> summaryProvider;
  final Value<String> asrModel;
  final Value<String> summaryModel;
  final Value<bool> autoDeleteAudio;
  final Value<bool> summarizeEnabled;
  final Value<bool> onboarded;
  const AppSettingsTableCompanion({
    this.id = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.accent = const Value.absent(),
    this.language = const Value.absent(),
    this.transcriptionLanguage = const Value.absent(),
    this.asrProvider = const Value.absent(),
    this.summaryProvider = const Value.absent(),
    this.asrModel = const Value.absent(),
    this.summaryModel = const Value.absent(),
    this.autoDeleteAudio = const Value.absent(),
    this.summarizeEnabled = const Value.absent(),
    this.onboarded = const Value.absent(),
  });
  AppSettingsTableCompanion.insert({
    this.id = const Value.absent(),
    required String themeMode,
    required String accent,
    required String language,
    required String transcriptionLanguage,
    required String asrProvider,
    required String summaryProvider,
    required String asrModel,
    required String summaryModel,
    required bool autoDeleteAudio,
    required bool summarizeEnabled,
    required bool onboarded,
  }) : themeMode = Value(themeMode),
       accent = Value(accent),
       language = Value(language),
       transcriptionLanguage = Value(transcriptionLanguage),
       asrProvider = Value(asrProvider),
       summaryProvider = Value(summaryProvider),
       asrModel = Value(asrModel),
       summaryModel = Value(summaryModel),
       autoDeleteAudio = Value(autoDeleteAudio),
       summarizeEnabled = Value(summarizeEnabled),
       onboarded = Value(onboarded);
  static Insertable<AppSettingsTableData> custom({
    Expression<int>? id,
    Expression<String>? themeMode,
    Expression<String>? accent,
    Expression<String>? language,
    Expression<String>? transcriptionLanguage,
    Expression<String>? asrProvider,
    Expression<String>? summaryProvider,
    Expression<String>? asrModel,
    Expression<String>? summaryModel,
    Expression<bool>? autoDeleteAudio,
    Expression<bool>? summarizeEnabled,
    Expression<bool>? onboarded,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (themeMode != null) 'theme_mode': themeMode,
      if (accent != null) 'accent': accent,
      if (language != null) 'language': language,
      if (transcriptionLanguage != null)
        'transcription_language': transcriptionLanguage,
      if (asrProvider != null) 'asr_provider': asrProvider,
      if (summaryProvider != null) 'summary_provider': summaryProvider,
      if (asrModel != null) 'asr_model': asrModel,
      if (summaryModel != null) 'summary_model': summaryModel,
      if (autoDeleteAudio != null) 'auto_delete_audio': autoDeleteAudio,
      if (summarizeEnabled != null) 'summarize_enabled': summarizeEnabled,
      if (onboarded != null) 'onboarded': onboarded,
    });
  }

  AppSettingsTableCompanion copyWith({
    Value<int>? id,
    Value<String>? themeMode,
    Value<String>? accent,
    Value<String>? language,
    Value<String>? transcriptionLanguage,
    Value<String>? asrProvider,
    Value<String>? summaryProvider,
    Value<String>? asrModel,
    Value<String>? summaryModel,
    Value<bool>? autoDeleteAudio,
    Value<bool>? summarizeEnabled,
    Value<bool>? onboarded,
  }) {
    return AppSettingsTableCompanion(
      id: id ?? this.id,
      themeMode: themeMode ?? this.themeMode,
      accent: accent ?? this.accent,
      language: language ?? this.language,
      transcriptionLanguage:
          transcriptionLanguage ?? this.transcriptionLanguage,
      asrProvider: asrProvider ?? this.asrProvider,
      summaryProvider: summaryProvider ?? this.summaryProvider,
      asrModel: asrModel ?? this.asrModel,
      summaryModel: summaryModel ?? this.summaryModel,
      autoDeleteAudio: autoDeleteAudio ?? this.autoDeleteAudio,
      summarizeEnabled: summarizeEnabled ?? this.summarizeEnabled,
      onboarded: onboarded ?? this.onboarded,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(themeMode.value);
    }
    if (accent.present) {
      map['accent'] = Variable<String>(accent.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (transcriptionLanguage.present) {
      map['transcription_language'] = Variable<String>(
        transcriptionLanguage.value,
      );
    }
    if (asrProvider.present) {
      map['asr_provider'] = Variable<String>(asrProvider.value);
    }
    if (summaryProvider.present) {
      map['summary_provider'] = Variable<String>(summaryProvider.value);
    }
    if (asrModel.present) {
      map['asr_model'] = Variable<String>(asrModel.value);
    }
    if (summaryModel.present) {
      map['summary_model'] = Variable<String>(summaryModel.value);
    }
    if (autoDeleteAudio.present) {
      map['auto_delete_audio'] = Variable<bool>(autoDeleteAudio.value);
    }
    if (summarizeEnabled.present) {
      map['summarize_enabled'] = Variable<bool>(summarizeEnabled.value);
    }
    if (onboarded.present) {
      map['onboarded'] = Variable<bool>(onboarded.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsTableCompanion(')
          ..write('id: $id, ')
          ..write('themeMode: $themeMode, ')
          ..write('accent: $accent, ')
          ..write('language: $language, ')
          ..write('transcriptionLanguage: $transcriptionLanguage, ')
          ..write('asrProvider: $asrProvider, ')
          ..write('summaryProvider: $summaryProvider, ')
          ..write('asrModel: $asrModel, ')
          ..write('summaryModel: $summaryModel, ')
          ..write('autoDeleteAudio: $autoDeleteAudio, ')
          ..write('summarizeEnabled: $summarizeEnabled, ')
          ..write('onboarded: $onboarded')
          ..write(')'))
        .toString();
  }
}

class $NotesTableTable extends NotesTable
    with TableInfo<$NotesTableTable, NotesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _speakerMeta = const VerificationMeta(
    'speaker',
  );
  @override
  late final GeneratedColumn<String> speaker = GeneratedColumn<String>(
    'speaker',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecMeta = const VerificationMeta(
    'durationSec',
  );
  @override
  late final GeneratedColumn<int> durationSec = GeneratedColumn<int>(
    'duration_sec',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _asrIsLocalMeta = const VerificationMeta(
    'asrIsLocal',
  );
  @override
  late final GeneratedColumn<bool> asrIsLocal = GeneratedColumn<bool>(
    'asr_is_local',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("asr_is_local" IN (0, 1))',
    ),
  );
  static const VerificationMeta _summaryIsLocalMeta = const VerificationMeta(
    'summaryIsLocal',
  );
  @override
  late final GeneratedColumn<bool> summaryIsLocal = GeneratedColumn<bool>(
    'summary_is_local',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("summary_is_local" IN (0, 1))',
    ),
  );
  static const VerificationMeta _asrNameMeta = const VerificationMeta(
    'asrName',
  );
  @override
  late final GeneratedColumn<String> asrName = GeneratedColumn<String>(
    'asr_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _asrSubMeta = const VerificationMeta('asrSub');
  @override
  late final GeneratedColumn<String> asrSub = GeneratedColumn<String>(
    'asr_sub',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _llmNameMeta = const VerificationMeta(
    'llmName',
  );
  @override
  late final GeneratedColumn<String> llmName = GeneratedColumn<String>(
    'llm_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _llmSubMeta = const VerificationMeta('llmSub');
  @override
  late final GeneratedColumn<String> llmSub = GeneratedColumn<String>(
    'llm_sub',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gistMeta = const VerificationMeta('gist');
  @override
  late final GeneratedColumn<String> gist = GeneratedColumn<String>(
    'gist',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryErrorMeta = const VerificationMeta(
    'summaryError',
  );
  @override
  late final GeneratedColumn<String> summaryError = GeneratedColumn<String>(
    'summary_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioPathMeta = const VerificationMeta(
    'audioPath',
  );
  @override
  late final GeneratedColumn<String> audioPath = GeneratedColumn<String>(
    'audio_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioOwnershipMeta = const VerificationMeta(
    'audioOwnership',
  );
  @override
  late final GeneratedColumn<String> audioOwnership = GeneratedColumn<String>(
    'audio_ownership',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    speaker,
    source,
    durationSec,
    createdAt,
    asrIsLocal,
    summaryIsLocal,
    asrName,
    asrSub,
    llmName,
    llmSub,
    gist,
    summaryError,
    audioPath,
    audioOwnership,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotesTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('speaker')) {
      context.handle(
        _speakerMeta,
        speaker.isAcceptableOrUnknown(data['speaker']!, _speakerMeta),
      );
    } else if (isInserting) {
      context.missing(_speakerMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('duration_sec')) {
      context.handle(
        _durationSecMeta,
        durationSec.isAcceptableOrUnknown(
          data['duration_sec']!,
          _durationSecMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationSecMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('asr_is_local')) {
      context.handle(
        _asrIsLocalMeta,
        asrIsLocal.isAcceptableOrUnknown(
          data['asr_is_local']!,
          _asrIsLocalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_asrIsLocalMeta);
    }
    if (data.containsKey('summary_is_local')) {
      context.handle(
        _summaryIsLocalMeta,
        summaryIsLocal.isAcceptableOrUnknown(
          data['summary_is_local']!,
          _summaryIsLocalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_summaryIsLocalMeta);
    }
    if (data.containsKey('asr_name')) {
      context.handle(
        _asrNameMeta,
        asrName.isAcceptableOrUnknown(data['asr_name']!, _asrNameMeta),
      );
    } else if (isInserting) {
      context.missing(_asrNameMeta);
    }
    if (data.containsKey('asr_sub')) {
      context.handle(
        _asrSubMeta,
        asrSub.isAcceptableOrUnknown(data['asr_sub']!, _asrSubMeta),
      );
    } else if (isInserting) {
      context.missing(_asrSubMeta);
    }
    if (data.containsKey('llm_name')) {
      context.handle(
        _llmNameMeta,
        llmName.isAcceptableOrUnknown(data['llm_name']!, _llmNameMeta),
      );
    } else if (isInserting) {
      context.missing(_llmNameMeta);
    }
    if (data.containsKey('llm_sub')) {
      context.handle(
        _llmSubMeta,
        llmSub.isAcceptableOrUnknown(data['llm_sub']!, _llmSubMeta),
      );
    } else if (isInserting) {
      context.missing(_llmSubMeta);
    }
    if (data.containsKey('gist')) {
      context.handle(
        _gistMeta,
        gist.isAcceptableOrUnknown(data['gist']!, _gistMeta),
      );
    } else if (isInserting) {
      context.missing(_gistMeta);
    }
    if (data.containsKey('summary_error')) {
      context.handle(
        _summaryErrorMeta,
        summaryError.isAcceptableOrUnknown(
          data['summary_error']!,
          _summaryErrorMeta,
        ),
      );
    }
    if (data.containsKey('audio_path')) {
      context.handle(
        _audioPathMeta,
        audioPath.isAcceptableOrUnknown(data['audio_path']!, _audioPathMeta),
      );
    }
    if (data.containsKey('audio_ownership')) {
      context.handle(
        _audioOwnershipMeta,
        audioOwnership.isAcceptableOrUnknown(
          data['audio_ownership']!,
          _audioOwnershipMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_audioOwnershipMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NotesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotesTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      speaker: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}speaker'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      durationSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_sec'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      asrIsLocal: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}asr_is_local'],
      )!,
      summaryIsLocal: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}summary_is_local'],
      )!,
      asrName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asr_name'],
      )!,
      asrSub: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asr_sub'],
      )!,
      llmName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}llm_name'],
      )!,
      llmSub: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}llm_sub'],
      )!,
      gist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gist'],
      )!,
      summaryError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_error'],
      ),
      audioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_path'],
      ),
      audioOwnership: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_ownership'],
      )!,
    );
  }

  @override
  $NotesTableTable createAlias(String alias) {
    return $NotesTableTable(attachedDatabase, alias);
  }
}

class NotesTableData extends DataClass implements Insertable<NotesTableData> {
  final String id;
  final String title;
  final String speaker;
  final String source;
  final int durationSec;
  final int createdAt;
  final bool asrIsLocal;
  final bool summaryIsLocal;
  final String asrName;
  final String asrSub;
  final String llmName;
  final String llmSub;
  final String gist;
  final String? summaryError;
  final String? audioPath;
  final String audioOwnership;
  const NotesTableData({
    required this.id,
    required this.title,
    required this.speaker,
    required this.source,
    required this.durationSec,
    required this.createdAt,
    required this.asrIsLocal,
    required this.summaryIsLocal,
    required this.asrName,
    required this.asrSub,
    required this.llmName,
    required this.llmSub,
    required this.gist,
    this.summaryError,
    this.audioPath,
    required this.audioOwnership,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['speaker'] = Variable<String>(speaker);
    map['source'] = Variable<String>(source);
    map['duration_sec'] = Variable<int>(durationSec);
    map['created_at'] = Variable<int>(createdAt);
    map['asr_is_local'] = Variable<bool>(asrIsLocal);
    map['summary_is_local'] = Variable<bool>(summaryIsLocal);
    map['asr_name'] = Variable<String>(asrName);
    map['asr_sub'] = Variable<String>(asrSub);
    map['llm_name'] = Variable<String>(llmName);
    map['llm_sub'] = Variable<String>(llmSub);
    map['gist'] = Variable<String>(gist);
    if (!nullToAbsent || summaryError != null) {
      map['summary_error'] = Variable<String>(summaryError);
    }
    if (!nullToAbsent || audioPath != null) {
      map['audio_path'] = Variable<String>(audioPath);
    }
    map['audio_ownership'] = Variable<String>(audioOwnership);
    return map;
  }

  NotesTableCompanion toCompanion(bool nullToAbsent) {
    return NotesTableCompanion(
      id: Value(id),
      title: Value(title),
      speaker: Value(speaker),
      source: Value(source),
      durationSec: Value(durationSec),
      createdAt: Value(createdAt),
      asrIsLocal: Value(asrIsLocal),
      summaryIsLocal: Value(summaryIsLocal),
      asrName: Value(asrName),
      asrSub: Value(asrSub),
      llmName: Value(llmName),
      llmSub: Value(llmSub),
      gist: Value(gist),
      summaryError: summaryError == null && nullToAbsent
          ? const Value.absent()
          : Value(summaryError),
      audioPath: audioPath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioPath),
      audioOwnership: Value(audioOwnership),
    );
  }

  factory NotesTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotesTableData(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      speaker: serializer.fromJson<String>(json['speaker']),
      source: serializer.fromJson<String>(json['source']),
      durationSec: serializer.fromJson<int>(json['durationSec']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      asrIsLocal: serializer.fromJson<bool>(json['asrIsLocal']),
      summaryIsLocal: serializer.fromJson<bool>(json['summaryIsLocal']),
      asrName: serializer.fromJson<String>(json['asrName']),
      asrSub: serializer.fromJson<String>(json['asrSub']),
      llmName: serializer.fromJson<String>(json['llmName']),
      llmSub: serializer.fromJson<String>(json['llmSub']),
      gist: serializer.fromJson<String>(json['gist']),
      summaryError: serializer.fromJson<String?>(json['summaryError']),
      audioPath: serializer.fromJson<String?>(json['audioPath']),
      audioOwnership: serializer.fromJson<String>(json['audioOwnership']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'speaker': serializer.toJson<String>(speaker),
      'source': serializer.toJson<String>(source),
      'durationSec': serializer.toJson<int>(durationSec),
      'createdAt': serializer.toJson<int>(createdAt),
      'asrIsLocal': serializer.toJson<bool>(asrIsLocal),
      'summaryIsLocal': serializer.toJson<bool>(summaryIsLocal),
      'asrName': serializer.toJson<String>(asrName),
      'asrSub': serializer.toJson<String>(asrSub),
      'llmName': serializer.toJson<String>(llmName),
      'llmSub': serializer.toJson<String>(llmSub),
      'gist': serializer.toJson<String>(gist),
      'summaryError': serializer.toJson<String?>(summaryError),
      'audioPath': serializer.toJson<String?>(audioPath),
      'audioOwnership': serializer.toJson<String>(audioOwnership),
    };
  }

  NotesTableData copyWith({
    String? id,
    String? title,
    String? speaker,
    String? source,
    int? durationSec,
    int? createdAt,
    bool? asrIsLocal,
    bool? summaryIsLocal,
    String? asrName,
    String? asrSub,
    String? llmName,
    String? llmSub,
    String? gist,
    Value<String?> summaryError = const Value.absent(),
    Value<String?> audioPath = const Value.absent(),
    String? audioOwnership,
  }) => NotesTableData(
    id: id ?? this.id,
    title: title ?? this.title,
    speaker: speaker ?? this.speaker,
    source: source ?? this.source,
    durationSec: durationSec ?? this.durationSec,
    createdAt: createdAt ?? this.createdAt,
    asrIsLocal: asrIsLocal ?? this.asrIsLocal,
    summaryIsLocal: summaryIsLocal ?? this.summaryIsLocal,
    asrName: asrName ?? this.asrName,
    asrSub: asrSub ?? this.asrSub,
    llmName: llmName ?? this.llmName,
    llmSub: llmSub ?? this.llmSub,
    gist: gist ?? this.gist,
    summaryError: summaryError.present ? summaryError.value : this.summaryError,
    audioPath: audioPath.present ? audioPath.value : this.audioPath,
    audioOwnership: audioOwnership ?? this.audioOwnership,
  );
  NotesTableData copyWithCompanion(NotesTableCompanion data) {
    return NotesTableData(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      speaker: data.speaker.present ? data.speaker.value : this.speaker,
      source: data.source.present ? data.source.value : this.source,
      durationSec: data.durationSec.present
          ? data.durationSec.value
          : this.durationSec,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      asrIsLocal: data.asrIsLocal.present
          ? data.asrIsLocal.value
          : this.asrIsLocal,
      summaryIsLocal: data.summaryIsLocal.present
          ? data.summaryIsLocal.value
          : this.summaryIsLocal,
      asrName: data.asrName.present ? data.asrName.value : this.asrName,
      asrSub: data.asrSub.present ? data.asrSub.value : this.asrSub,
      llmName: data.llmName.present ? data.llmName.value : this.llmName,
      llmSub: data.llmSub.present ? data.llmSub.value : this.llmSub,
      gist: data.gist.present ? data.gist.value : this.gist,
      summaryError: data.summaryError.present
          ? data.summaryError.value
          : this.summaryError,
      audioPath: data.audioPath.present ? data.audioPath.value : this.audioPath,
      audioOwnership: data.audioOwnership.present
          ? data.audioOwnership.value
          : this.audioOwnership,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotesTableData(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('speaker: $speaker, ')
          ..write('source: $source, ')
          ..write('durationSec: $durationSec, ')
          ..write('createdAt: $createdAt, ')
          ..write('asrIsLocal: $asrIsLocal, ')
          ..write('summaryIsLocal: $summaryIsLocal, ')
          ..write('asrName: $asrName, ')
          ..write('asrSub: $asrSub, ')
          ..write('llmName: $llmName, ')
          ..write('llmSub: $llmSub, ')
          ..write('gist: $gist, ')
          ..write('summaryError: $summaryError, ')
          ..write('audioPath: $audioPath, ')
          ..write('audioOwnership: $audioOwnership')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    speaker,
    source,
    durationSec,
    createdAt,
    asrIsLocal,
    summaryIsLocal,
    asrName,
    asrSub,
    llmName,
    llmSub,
    gist,
    summaryError,
    audioPath,
    audioOwnership,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotesTableData &&
          other.id == this.id &&
          other.title == this.title &&
          other.speaker == this.speaker &&
          other.source == this.source &&
          other.durationSec == this.durationSec &&
          other.createdAt == this.createdAt &&
          other.asrIsLocal == this.asrIsLocal &&
          other.summaryIsLocal == this.summaryIsLocal &&
          other.asrName == this.asrName &&
          other.asrSub == this.asrSub &&
          other.llmName == this.llmName &&
          other.llmSub == this.llmSub &&
          other.gist == this.gist &&
          other.summaryError == this.summaryError &&
          other.audioPath == this.audioPath &&
          other.audioOwnership == this.audioOwnership);
}

class NotesTableCompanion extends UpdateCompanion<NotesTableData> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> speaker;
  final Value<String> source;
  final Value<int> durationSec;
  final Value<int> createdAt;
  final Value<bool> asrIsLocal;
  final Value<bool> summaryIsLocal;
  final Value<String> asrName;
  final Value<String> asrSub;
  final Value<String> llmName;
  final Value<String> llmSub;
  final Value<String> gist;
  final Value<String?> summaryError;
  final Value<String?> audioPath;
  final Value<String> audioOwnership;
  final Value<int> rowid;
  const NotesTableCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.speaker = const Value.absent(),
    this.source = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.asrIsLocal = const Value.absent(),
    this.summaryIsLocal = const Value.absent(),
    this.asrName = const Value.absent(),
    this.asrSub = const Value.absent(),
    this.llmName = const Value.absent(),
    this.llmSub = const Value.absent(),
    this.gist = const Value.absent(),
    this.summaryError = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.audioOwnership = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotesTableCompanion.insert({
    required String id,
    required String title,
    required String speaker,
    required String source,
    required int durationSec,
    required int createdAt,
    required bool asrIsLocal,
    required bool summaryIsLocal,
    required String asrName,
    required String asrSub,
    required String llmName,
    required String llmSub,
    required String gist,
    this.summaryError = const Value.absent(),
    this.audioPath = const Value.absent(),
    required String audioOwnership,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       speaker = Value(speaker),
       source = Value(source),
       durationSec = Value(durationSec),
       createdAt = Value(createdAt),
       asrIsLocal = Value(asrIsLocal),
       summaryIsLocal = Value(summaryIsLocal),
       asrName = Value(asrName),
       asrSub = Value(asrSub),
       llmName = Value(llmName),
       llmSub = Value(llmSub),
       gist = Value(gist),
       audioOwnership = Value(audioOwnership);
  static Insertable<NotesTableData> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? speaker,
    Expression<String>? source,
    Expression<int>? durationSec,
    Expression<int>? createdAt,
    Expression<bool>? asrIsLocal,
    Expression<bool>? summaryIsLocal,
    Expression<String>? asrName,
    Expression<String>? asrSub,
    Expression<String>? llmName,
    Expression<String>? llmSub,
    Expression<String>? gist,
    Expression<String>? summaryError,
    Expression<String>? audioPath,
    Expression<String>? audioOwnership,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (speaker != null) 'speaker': speaker,
      if (source != null) 'source': source,
      if (durationSec != null) 'duration_sec': durationSec,
      if (createdAt != null) 'created_at': createdAt,
      if (asrIsLocal != null) 'asr_is_local': asrIsLocal,
      if (summaryIsLocal != null) 'summary_is_local': summaryIsLocal,
      if (asrName != null) 'asr_name': asrName,
      if (asrSub != null) 'asr_sub': asrSub,
      if (llmName != null) 'llm_name': llmName,
      if (llmSub != null) 'llm_sub': llmSub,
      if (gist != null) 'gist': gist,
      if (summaryError != null) 'summary_error': summaryError,
      if (audioPath != null) 'audio_path': audioPath,
      if (audioOwnership != null) 'audio_ownership': audioOwnership,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? speaker,
    Value<String>? source,
    Value<int>? durationSec,
    Value<int>? createdAt,
    Value<bool>? asrIsLocal,
    Value<bool>? summaryIsLocal,
    Value<String>? asrName,
    Value<String>? asrSub,
    Value<String>? llmName,
    Value<String>? llmSub,
    Value<String>? gist,
    Value<String?>? summaryError,
    Value<String?>? audioPath,
    Value<String>? audioOwnership,
    Value<int>? rowid,
  }) {
    return NotesTableCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      speaker: speaker ?? this.speaker,
      source: source ?? this.source,
      durationSec: durationSec ?? this.durationSec,
      createdAt: createdAt ?? this.createdAt,
      asrIsLocal: asrIsLocal ?? this.asrIsLocal,
      summaryIsLocal: summaryIsLocal ?? this.summaryIsLocal,
      asrName: asrName ?? this.asrName,
      asrSub: asrSub ?? this.asrSub,
      llmName: llmName ?? this.llmName,
      llmSub: llmSub ?? this.llmSub,
      gist: gist ?? this.gist,
      summaryError: summaryError ?? this.summaryError,
      audioPath: audioPath ?? this.audioPath,
      audioOwnership: audioOwnership ?? this.audioOwnership,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (speaker.present) {
      map['speaker'] = Variable<String>(speaker.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (durationSec.present) {
      map['duration_sec'] = Variable<int>(durationSec.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (asrIsLocal.present) {
      map['asr_is_local'] = Variable<bool>(asrIsLocal.value);
    }
    if (summaryIsLocal.present) {
      map['summary_is_local'] = Variable<bool>(summaryIsLocal.value);
    }
    if (asrName.present) {
      map['asr_name'] = Variable<String>(asrName.value);
    }
    if (asrSub.present) {
      map['asr_sub'] = Variable<String>(asrSub.value);
    }
    if (llmName.present) {
      map['llm_name'] = Variable<String>(llmName.value);
    }
    if (llmSub.present) {
      map['llm_sub'] = Variable<String>(llmSub.value);
    }
    if (gist.present) {
      map['gist'] = Variable<String>(gist.value);
    }
    if (summaryError.present) {
      map['summary_error'] = Variable<String>(summaryError.value);
    }
    if (audioPath.present) {
      map['audio_path'] = Variable<String>(audioPath.value);
    }
    if (audioOwnership.present) {
      map['audio_ownership'] = Variable<String>(audioOwnership.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesTableCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('speaker: $speaker, ')
          ..write('source: $source, ')
          ..write('durationSec: $durationSec, ')
          ..write('createdAt: $createdAt, ')
          ..write('asrIsLocal: $asrIsLocal, ')
          ..write('summaryIsLocal: $summaryIsLocal, ')
          ..write('asrName: $asrName, ')
          ..write('asrSub: $asrSub, ')
          ..write('llmName: $llmName, ')
          ..write('llmSub: $llmSub, ')
          ..write('gist: $gist, ')
          ..write('summaryError: $summaryError, ')
          ..write('audioPath: $audioPath, ')
          ..write('audioOwnership: $audioOwnership, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotePointsTableTable extends NotePointsTable
    with TableInfo<$NotePointsTableTable, NotePointsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotePointsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES notes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [noteId, position, content];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_points';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotePointsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['text']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {noteId, position};
  @override
  NotePointsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotePointsTableData(
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
    );
  }

  @override
  $NotePointsTableTable createAlias(String alias) {
    return $NotePointsTableTable(attachedDatabase, alias);
  }
}

class NotePointsTableData extends DataClass
    implements Insertable<NotePointsTableData> {
  final String noteId;
  final int position;
  final String content;
  const NotePointsTableData({
    required this.noteId,
    required this.position,
    required this.content,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['note_id'] = Variable<String>(noteId);
    map['position'] = Variable<int>(position);
    map['text'] = Variable<String>(content);
    return map;
  }

  NotePointsTableCompanion toCompanion(bool nullToAbsent) {
    return NotePointsTableCompanion(
      noteId: Value(noteId),
      position: Value(position),
      content: Value(content),
    );
  }

  factory NotePointsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotePointsTableData(
      noteId: serializer.fromJson<String>(json['noteId']),
      position: serializer.fromJson<int>(json['position']),
      content: serializer.fromJson<String>(json['content']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'noteId': serializer.toJson<String>(noteId),
      'position': serializer.toJson<int>(position),
      'content': serializer.toJson<String>(content),
    };
  }

  NotePointsTableData copyWith({
    String? noteId,
    int? position,
    String? content,
  }) => NotePointsTableData(
    noteId: noteId ?? this.noteId,
    position: position ?? this.position,
    content: content ?? this.content,
  );
  NotePointsTableData copyWithCompanion(NotePointsTableCompanion data) {
    return NotePointsTableData(
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      position: data.position.present ? data.position.value : this.position,
      content: data.content.present ? data.content.value : this.content,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotePointsTableData(')
          ..write('noteId: $noteId, ')
          ..write('position: $position, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(noteId, position, content);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotePointsTableData &&
          other.noteId == this.noteId &&
          other.position == this.position &&
          other.content == this.content);
}

class NotePointsTableCompanion extends UpdateCompanion<NotePointsTableData> {
  final Value<String> noteId;
  final Value<int> position;
  final Value<String> content;
  final Value<int> rowid;
  const NotePointsTableCompanion({
    this.noteId = const Value.absent(),
    this.position = const Value.absent(),
    this.content = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotePointsTableCompanion.insert({
    required String noteId,
    required int position,
    required String content,
    this.rowid = const Value.absent(),
  }) : noteId = Value(noteId),
       position = Value(position),
       content = Value(content);
  static Insertable<NotePointsTableData> custom({
    Expression<String>? noteId,
    Expression<int>? position,
    Expression<String>? content,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (noteId != null) 'note_id': noteId,
      if (position != null) 'position': position,
      if (content != null) 'text': content,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotePointsTableCompanion copyWith({
    Value<String>? noteId,
    Value<int>? position,
    Value<String>? content,
    Value<int>? rowid,
  }) {
    return NotePointsTableCompanion(
      noteId: noteId ?? this.noteId,
      position: position ?? this.position,
      content: content ?? this.content,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (content.present) {
      map['text'] = Variable<String>(content.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotePointsTableCompanion(')
          ..write('noteId: $noteId, ')
          ..write('position: $position, ')
          ..write('content: $content, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteTodosTableTable extends NoteTodosTable
    with TableInfo<$NoteTodosTableTable, NoteTodosTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteTodosTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES notes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  @override
  late final GeneratedColumn<bool> done = GeneratedColumn<bool>(
    'done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("done" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [noteId, position, content, done];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_todos';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteTodosTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['text']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('done')) {
      context.handle(
        _doneMeta,
        done.isAcceptableOrUnknown(data['done']!, _doneMeta),
      );
    } else if (isInserting) {
      context.missing(_doneMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {noteId, position};
  @override
  NoteTodosTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteTodosTableData(
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      done: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}done'],
      )!,
    );
  }

  @override
  $NoteTodosTableTable createAlias(String alias) {
    return $NoteTodosTableTable(attachedDatabase, alias);
  }
}

class NoteTodosTableData extends DataClass
    implements Insertable<NoteTodosTableData> {
  final String noteId;
  final int position;
  final String content;
  final bool done;
  const NoteTodosTableData({
    required this.noteId,
    required this.position,
    required this.content,
    required this.done,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['note_id'] = Variable<String>(noteId);
    map['position'] = Variable<int>(position);
    map['text'] = Variable<String>(content);
    map['done'] = Variable<bool>(done);
    return map;
  }

  NoteTodosTableCompanion toCompanion(bool nullToAbsent) {
    return NoteTodosTableCompanion(
      noteId: Value(noteId),
      position: Value(position),
      content: Value(content),
      done: Value(done),
    );
  }

  factory NoteTodosTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteTodosTableData(
      noteId: serializer.fromJson<String>(json['noteId']),
      position: serializer.fromJson<int>(json['position']),
      content: serializer.fromJson<String>(json['content']),
      done: serializer.fromJson<bool>(json['done']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'noteId': serializer.toJson<String>(noteId),
      'position': serializer.toJson<int>(position),
      'content': serializer.toJson<String>(content),
      'done': serializer.toJson<bool>(done),
    };
  }

  NoteTodosTableData copyWith({
    String? noteId,
    int? position,
    String? content,
    bool? done,
  }) => NoteTodosTableData(
    noteId: noteId ?? this.noteId,
    position: position ?? this.position,
    content: content ?? this.content,
    done: done ?? this.done,
  );
  NoteTodosTableData copyWithCompanion(NoteTodosTableCompanion data) {
    return NoteTodosTableData(
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      position: data.position.present ? data.position.value : this.position,
      content: data.content.present ? data.content.value : this.content,
      done: data.done.present ? data.done.value : this.done,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteTodosTableData(')
          ..write('noteId: $noteId, ')
          ..write('position: $position, ')
          ..write('content: $content, ')
          ..write('done: $done')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(noteId, position, content, done);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteTodosTableData &&
          other.noteId == this.noteId &&
          other.position == this.position &&
          other.content == this.content &&
          other.done == this.done);
}

class NoteTodosTableCompanion extends UpdateCompanion<NoteTodosTableData> {
  final Value<String> noteId;
  final Value<int> position;
  final Value<String> content;
  final Value<bool> done;
  final Value<int> rowid;
  const NoteTodosTableCompanion({
    this.noteId = const Value.absent(),
    this.position = const Value.absent(),
    this.content = const Value.absent(),
    this.done = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteTodosTableCompanion.insert({
    required String noteId,
    required int position,
    required String content,
    required bool done,
    this.rowid = const Value.absent(),
  }) : noteId = Value(noteId),
       position = Value(position),
       content = Value(content),
       done = Value(done);
  static Insertable<NoteTodosTableData> custom({
    Expression<String>? noteId,
    Expression<int>? position,
    Expression<String>? content,
    Expression<bool>? done,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (noteId != null) 'note_id': noteId,
      if (position != null) 'position': position,
      if (content != null) 'text': content,
      if (done != null) 'done': done,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteTodosTableCompanion copyWith({
    Value<String>? noteId,
    Value<int>? position,
    Value<String>? content,
    Value<bool>? done,
    Value<int>? rowid,
  }) {
    return NoteTodosTableCompanion(
      noteId: noteId ?? this.noteId,
      position: position ?? this.position,
      content: content ?? this.content,
      done: done ?? this.done,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (content.present) {
      map['text'] = Variable<String>(content.value);
    }
    if (done.present) {
      map['done'] = Variable<bool>(done.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteTodosTableCompanion(')
          ..write('noteId: $noteId, ')
          ..write('position: $position, ')
          ..write('content: $content, ')
          ..write('done: $done, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TranscriptSegmentsTableTable extends TranscriptSegmentsTable
    with TableInfo<$TranscriptSegmentsTableTable, TranscriptSegmentsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranscriptSegmentsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES notes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [noteId, position, content];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transcript_segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<TranscriptSegmentsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['text']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {noteId, position};
  @override
  TranscriptSegmentsTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TranscriptSegmentsTableData(
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
    );
  }

  @override
  $TranscriptSegmentsTableTable createAlias(String alias) {
    return $TranscriptSegmentsTableTable(attachedDatabase, alias);
  }
}

class TranscriptSegmentsTableData extends DataClass
    implements Insertable<TranscriptSegmentsTableData> {
  final String noteId;
  final int position;
  final String content;
  const TranscriptSegmentsTableData({
    required this.noteId,
    required this.position,
    required this.content,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['note_id'] = Variable<String>(noteId);
    map['position'] = Variable<int>(position);
    map['text'] = Variable<String>(content);
    return map;
  }

  TranscriptSegmentsTableCompanion toCompanion(bool nullToAbsent) {
    return TranscriptSegmentsTableCompanion(
      noteId: Value(noteId),
      position: Value(position),
      content: Value(content),
    );
  }

  factory TranscriptSegmentsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TranscriptSegmentsTableData(
      noteId: serializer.fromJson<String>(json['noteId']),
      position: serializer.fromJson<int>(json['position']),
      content: serializer.fromJson<String>(json['content']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'noteId': serializer.toJson<String>(noteId),
      'position': serializer.toJson<int>(position),
      'content': serializer.toJson<String>(content),
    };
  }

  TranscriptSegmentsTableData copyWith({
    String? noteId,
    int? position,
    String? content,
  }) => TranscriptSegmentsTableData(
    noteId: noteId ?? this.noteId,
    position: position ?? this.position,
    content: content ?? this.content,
  );
  TranscriptSegmentsTableData copyWithCompanion(
    TranscriptSegmentsTableCompanion data,
  ) {
    return TranscriptSegmentsTableData(
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      position: data.position.present ? data.position.value : this.position,
      content: data.content.present ? data.content.value : this.content,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptSegmentsTableData(')
          ..write('noteId: $noteId, ')
          ..write('position: $position, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(noteId, position, content);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TranscriptSegmentsTableData &&
          other.noteId == this.noteId &&
          other.position == this.position &&
          other.content == this.content);
}

class TranscriptSegmentsTableCompanion
    extends UpdateCompanion<TranscriptSegmentsTableData> {
  final Value<String> noteId;
  final Value<int> position;
  final Value<String> content;
  final Value<int> rowid;
  const TranscriptSegmentsTableCompanion({
    this.noteId = const Value.absent(),
    this.position = const Value.absent(),
    this.content = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TranscriptSegmentsTableCompanion.insert({
    required String noteId,
    required int position,
    required String content,
    this.rowid = const Value.absent(),
  }) : noteId = Value(noteId),
       position = Value(position),
       content = Value(content);
  static Insertable<TranscriptSegmentsTableData> custom({
    Expression<String>? noteId,
    Expression<int>? position,
    Expression<String>? content,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (noteId != null) 'note_id': noteId,
      if (position != null) 'position': position,
      if (content != null) 'text': content,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TranscriptSegmentsTableCompanion copyWith({
    Value<String>? noteId,
    Value<int>? position,
    Value<String>? content,
    Value<int>? rowid,
  }) {
    return TranscriptSegmentsTableCompanion(
      noteId: noteId ?? this.noteId,
      position: position ?? this.position,
      content: content ?? this.content,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (content.present) {
      map['text'] = Variable<String>(content.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptSegmentsTableCompanion(')
          ..write('noteId: $noteId, ')
          ..write('position: $position, ')
          ..write('content: $content, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MigrationStateTableTable extends MigrationStateTable
    with TableInfo<$MigrationStateTableTable, MigrationStateTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MigrationStateTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, completedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'migration_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<MigrationStateTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MigrationStateTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MigrationStateTableData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      )!,
    );
  }

  @override
  $MigrationStateTableTable createAlias(String alias) {
    return $MigrationStateTableTable(attachedDatabase, alias);
  }
}

class MigrationStateTableData extends DataClass
    implements Insertable<MigrationStateTableData> {
  final String key;
  final int completedAt;
  const MigrationStateTableData({required this.key, required this.completedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['completed_at'] = Variable<int>(completedAt);
    return map;
  }

  MigrationStateTableCompanion toCompanion(bool nullToAbsent) {
    return MigrationStateTableCompanion(
      key: Value(key),
      completedAt: Value(completedAt),
    );
  }

  factory MigrationStateTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MigrationStateTableData(
      key: serializer.fromJson<String>(json['key']),
      completedAt: serializer.fromJson<int>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'completedAt': serializer.toJson<int>(completedAt),
    };
  }

  MigrationStateTableData copyWith({String? key, int? completedAt}) =>
      MigrationStateTableData(
        key: key ?? this.key,
        completedAt: completedAt ?? this.completedAt,
      );
  MigrationStateTableData copyWithCompanion(MigrationStateTableCompanion data) {
    return MigrationStateTableData(
      key: data.key.present ? data.key.value : this.key,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MigrationStateTableData(')
          ..write('key: $key, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, completedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MigrationStateTableData &&
          other.key == this.key &&
          other.completedAt == this.completedAt);
}

class MigrationStateTableCompanion
    extends UpdateCompanion<MigrationStateTableData> {
  final Value<String> key;
  final Value<int> completedAt;
  final Value<int> rowid;
  const MigrationStateTableCompanion({
    this.key = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MigrationStateTableCompanion.insert({
    required String key,
    required int completedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       completedAt = Value(completedAt);
  static Insertable<MigrationStateTableData> custom({
    Expression<String>? key,
    Expression<int>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MigrationStateTableCompanion copyWith({
    Value<String>? key,
    Value<int>? completedAt,
    Value<int>? rowid,
  }) {
    return MigrationStateTableCompanion(
      key: key ?? this.key,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MigrationStateTableCompanion(')
          ..write('key: $key, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppSettingsTableTable appSettingsTable = $AppSettingsTableTable(
    this,
  );
  late final $NotesTableTable notesTable = $NotesTableTable(this);
  late final $NotePointsTableTable notePointsTable = $NotePointsTableTable(
    this,
  );
  late final $NoteTodosTableTable noteTodosTable = $NoteTodosTableTable(this);
  late final $TranscriptSegmentsTableTable transcriptSegmentsTable =
      $TranscriptSegmentsTableTable(this);
  late final $MigrationStateTableTable migrationStateTable =
      $MigrationStateTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appSettingsTable,
    notesTable,
    notePointsTable,
    noteTodosTable,
    transcriptSegmentsTable,
    migrationStateTable,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'notes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('note_points', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'notes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('note_todos', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'notes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('transcript_segments', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$AppSettingsTableTableCreateCompanionBuilder =
    AppSettingsTableCompanion Function({
      Value<int> id,
      required String themeMode,
      required String accent,
      required String language,
      required String transcriptionLanguage,
      required String asrProvider,
      required String summaryProvider,
      required String asrModel,
      required String summaryModel,
      required bool autoDeleteAudio,
      required bool summarizeEnabled,
      required bool onboarded,
    });
typedef $$AppSettingsTableTableUpdateCompanionBuilder =
    AppSettingsTableCompanion Function({
      Value<int> id,
      Value<String> themeMode,
      Value<String> accent,
      Value<String> language,
      Value<String> transcriptionLanguage,
      Value<String> asrProvider,
      Value<String> summaryProvider,
      Value<String> asrModel,
      Value<String> summaryModel,
      Value<bool> autoDeleteAudio,
      Value<bool> summarizeEnabled,
      Value<bool> onboarded,
    });

class $$AppSettingsTableTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTableTable> {
  $$AppSettingsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accent => $composableBuilder(
    column: $table.accent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcriptionLanguage => $composableBuilder(
    column: $table.transcriptionLanguage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get asrProvider => $composableBuilder(
    column: $table.asrProvider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryProvider => $composableBuilder(
    column: $table.summaryProvider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get asrModel => $composableBuilder(
    column: $table.asrModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryModel => $composableBuilder(
    column: $table.summaryModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoDeleteAudio => $composableBuilder(
    column: $table.autoDeleteAudio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get summarizeEnabled => $composableBuilder(
    column: $table.summarizeEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onboarded => $composableBuilder(
    column: $table.onboarded,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTableTable> {
  $$AppSettingsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accent => $composableBuilder(
    column: $table.accent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcriptionLanguage => $composableBuilder(
    column: $table.transcriptionLanguage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get asrProvider => $composableBuilder(
    column: $table.asrProvider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryProvider => $composableBuilder(
    column: $table.summaryProvider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get asrModel => $composableBuilder(
    column: $table.asrModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryModel => $composableBuilder(
    column: $table.summaryModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoDeleteAudio => $composableBuilder(
    column: $table.autoDeleteAudio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get summarizeEnabled => $composableBuilder(
    column: $table.summarizeEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onboarded => $composableBuilder(
    column: $table.onboarded,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTableTable> {
  $$AppSettingsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumn<String> get accent =>
      $composableBuilder(column: $table.accent, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get transcriptionLanguage => $composableBuilder(
    column: $table.transcriptionLanguage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get asrProvider => $composableBuilder(
    column: $table.asrProvider,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summaryProvider => $composableBuilder(
    column: $table.summaryProvider,
    builder: (column) => column,
  );

  GeneratedColumn<String> get asrModel =>
      $composableBuilder(column: $table.asrModel, builder: (column) => column);

  GeneratedColumn<String> get summaryModel => $composableBuilder(
    column: $table.summaryModel,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoDeleteAudio => $composableBuilder(
    column: $table.autoDeleteAudio,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get summarizeEnabled => $composableBuilder(
    column: $table.summarizeEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get onboarded =>
      $composableBuilder(column: $table.onboarded, builder: (column) => column);
}

class $$AppSettingsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTableTable,
          AppSettingsTableData,
          $$AppSettingsTableTableFilterComposer,
          $$AppSettingsTableTableOrderingComposer,
          $$AppSettingsTableTableAnnotationComposer,
          $$AppSettingsTableTableCreateCompanionBuilder,
          $$AppSettingsTableTableUpdateCompanionBuilder,
          (
            AppSettingsTableData,
            BaseReferences<
              _$AppDatabase,
              $AppSettingsTableTable,
              AppSettingsTableData
            >,
          ),
          AppSettingsTableData,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableTableManager(
    _$AppDatabase db,
    $AppSettingsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<String> accent = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String> transcriptionLanguage = const Value.absent(),
                Value<String> asrProvider = const Value.absent(),
                Value<String> summaryProvider = const Value.absent(),
                Value<String> asrModel = const Value.absent(),
                Value<String> summaryModel = const Value.absent(),
                Value<bool> autoDeleteAudio = const Value.absent(),
                Value<bool> summarizeEnabled = const Value.absent(),
                Value<bool> onboarded = const Value.absent(),
              }) => AppSettingsTableCompanion(
                id: id,
                themeMode: themeMode,
                accent: accent,
                language: language,
                transcriptionLanguage: transcriptionLanguage,
                asrProvider: asrProvider,
                summaryProvider: summaryProvider,
                asrModel: asrModel,
                summaryModel: summaryModel,
                autoDeleteAudio: autoDeleteAudio,
                summarizeEnabled: summarizeEnabled,
                onboarded: onboarded,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String themeMode,
                required String accent,
                required String language,
                required String transcriptionLanguage,
                required String asrProvider,
                required String summaryProvider,
                required String asrModel,
                required String summaryModel,
                required bool autoDeleteAudio,
                required bool summarizeEnabled,
                required bool onboarded,
              }) => AppSettingsTableCompanion.insert(
                id: id,
                themeMode: themeMode,
                accent: accent,
                language: language,
                transcriptionLanguage: transcriptionLanguage,
                asrProvider: asrProvider,
                summaryProvider: summaryProvider,
                asrModel: asrModel,
                summaryModel: summaryModel,
                autoDeleteAudio: autoDeleteAudio,
                summarizeEnabled: summarizeEnabled,
                onboarded: onboarded,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppSettingsTableTable, AppSettingsTableData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $AppSettingsTableTable,
                    AppSettingsTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTableTable,
      AppSettingsTableData,
      $$AppSettingsTableTableFilterComposer,
      $$AppSettingsTableTableOrderingComposer,
      $$AppSettingsTableTableAnnotationComposer,
      $$AppSettingsTableTableCreateCompanionBuilder,
      $$AppSettingsTableTableUpdateCompanionBuilder,
      (
        AppSettingsTableData,
        BaseReferences<
          _$AppDatabase,
          $AppSettingsTableTable,
          AppSettingsTableData
        >,
      ),
      AppSettingsTableData,
      PrefetchHooks Function()
    >;
typedef $$NotesTableTableCreateCompanionBuilder =
    NotesTableCompanion Function({
      required String id,
      required String title,
      required String speaker,
      required String source,
      required int durationSec,
      required int createdAt,
      required bool asrIsLocal,
      required bool summaryIsLocal,
      required String asrName,
      required String asrSub,
      required String llmName,
      required String llmSub,
      required String gist,
      Value<String?> summaryError,
      Value<String?> audioPath,
      required String audioOwnership,
      Value<int> rowid,
    });
typedef $$NotesTableTableUpdateCompanionBuilder =
    NotesTableCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> speaker,
      Value<String> source,
      Value<int> durationSec,
      Value<int> createdAt,
      Value<bool> asrIsLocal,
      Value<bool> summaryIsLocal,
      Value<String> asrName,
      Value<String> asrSub,
      Value<String> llmName,
      Value<String> llmSub,
      Value<String> gist,
      Value<String?> summaryError,
      Value<String?> audioPath,
      Value<String> audioOwnership,
      Value<int> rowid,
    });

final class $$NotesTableTableReferences
    extends BaseReferences<_$AppDatabase, $NotesTableTable, NotesTableData> {
  $$NotesTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$NotePointsTableTable, List<NotePointsTableData>>
  _notePointsTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.notePointsTable,
    aliasName: 'notes__id__note_points__note_id',
  );

  $$NotePointsTableTableProcessedTableManager get notePointsTableRefs {
    final manager = $$NotePointsTableTableTableManager(
      $_db,
      $_db.notePointsTable,
    ).filter((f) => f.noteId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _notePointsTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$NoteTodosTableTable, List<NoteTodosTableData>>
  _noteTodosTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.noteTodosTable,
    aliasName: 'notes__id__note_todos__note_id',
  );

  $$NoteTodosTableTableProcessedTableManager get noteTodosTableRefs {
    final manager = $$NoteTodosTableTableTableManager(
      $_db,
      $_db.noteTodosTable,
    ).filter((f) => f.noteId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_noteTodosTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $TranscriptSegmentsTableTable,
    List<TranscriptSegmentsTableData>
  >
  _transcriptSegmentsTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.transcriptSegmentsTable,
        aliasName: 'notes__id__transcript_segments__note_id',
      );

  $$TranscriptSegmentsTableTableProcessedTableManager
  get transcriptSegmentsTableRefs {
    final manager = $$TranscriptSegmentsTableTableTableManager(
      $_db,
      $_db.transcriptSegmentsTable,
    ).filter((f) => f.noteId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _transcriptSegmentsTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$NotesTableTableFilterComposer
    extends Composer<_$AppDatabase, $NotesTableTable> {
  $$NotesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get speaker => $composableBuilder(
    column: $table.speaker,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get asrIsLocal => $composableBuilder(
    column: $table.asrIsLocal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get summaryIsLocal => $composableBuilder(
    column: $table.summaryIsLocal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get asrName => $composableBuilder(
    column: $table.asrName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get asrSub => $composableBuilder(
    column: $table.asrSub,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get llmName => $composableBuilder(
    column: $table.llmName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get llmSub => $composableBuilder(
    column: $table.llmSub,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gist => $composableBuilder(
    column: $table.gist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryError => $composableBuilder(
    column: $table.summaryError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioOwnership => $composableBuilder(
    column: $table.audioOwnership,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> notePointsTableRefs(
    Expression<bool> Function($$NotePointsTableTableFilterComposer f) f,
  ) {
    final $$NotePointsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notePointsTable,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotePointsTableTableFilterComposer(
            $db: $db,
            $table: $db.notePointsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> noteTodosTableRefs(
    Expression<bool> Function($$NoteTodosTableTableFilterComposer f) f,
  ) {
    final $$NoteTodosTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteTodosTable,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTodosTableTableFilterComposer(
            $db: $db,
            $table: $db.noteTodosTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> transcriptSegmentsTableRefs(
    Expression<bool> Function($$TranscriptSegmentsTableTableFilterComposer f) f,
  ) {
    final $$TranscriptSegmentsTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.transcriptSegmentsTable,
          getReferencedColumn: (t) => t.noteId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TranscriptSegmentsTableTableFilterComposer(
                $db: $db,
                $table: $db.transcriptSegmentsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$NotesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $NotesTableTable> {
  $$NotesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get speaker => $composableBuilder(
    column: $table.speaker,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get asrIsLocal => $composableBuilder(
    column: $table.asrIsLocal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get summaryIsLocal => $composableBuilder(
    column: $table.summaryIsLocal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get asrName => $composableBuilder(
    column: $table.asrName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get asrSub => $composableBuilder(
    column: $table.asrSub,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get llmName => $composableBuilder(
    column: $table.llmName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get llmSub => $composableBuilder(
    column: $table.llmSub,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gist => $composableBuilder(
    column: $table.gist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryError => $composableBuilder(
    column: $table.summaryError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioOwnership => $composableBuilder(
    column: $table.audioOwnership,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotesTableTable> {
  $$NotesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get speaker =>
      $composableBuilder(column: $table.speaker, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get asrIsLocal => $composableBuilder(
    column: $table.asrIsLocal,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get summaryIsLocal => $composableBuilder(
    column: $table.summaryIsLocal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get asrName =>
      $composableBuilder(column: $table.asrName, builder: (column) => column);

  GeneratedColumn<String> get asrSub =>
      $composableBuilder(column: $table.asrSub, builder: (column) => column);

  GeneratedColumn<String> get llmName =>
      $composableBuilder(column: $table.llmName, builder: (column) => column);

  GeneratedColumn<String> get llmSub =>
      $composableBuilder(column: $table.llmSub, builder: (column) => column);

  GeneratedColumn<String> get gist =>
      $composableBuilder(column: $table.gist, builder: (column) => column);

  GeneratedColumn<String> get summaryError => $composableBuilder(
    column: $table.summaryError,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioPath =>
      $composableBuilder(column: $table.audioPath, builder: (column) => column);

  GeneratedColumn<String> get audioOwnership => $composableBuilder(
    column: $table.audioOwnership,
    builder: (column) => column,
  );

  Expression<T> notePointsTableRefs<T extends Object>(
    Expression<T> Function($$NotePointsTableTableAnnotationComposer a) f,
  ) {
    final $$NotePointsTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notePointsTable,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotePointsTableTableAnnotationComposer(
            $db: $db,
            $table: $db.notePointsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> noteTodosTableRefs<T extends Object>(
    Expression<T> Function($$NoteTodosTableTableAnnotationComposer a) f,
  ) {
    final $$NoteTodosTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteTodosTable,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTodosTableTableAnnotationComposer(
            $db: $db,
            $table: $db.noteTodosTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> transcriptSegmentsTableRefs<T extends Object>(
    Expression<T> Function($$TranscriptSegmentsTableTableAnnotationComposer a)
    f,
  ) {
    final $$TranscriptSegmentsTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.transcriptSegmentsTable,
          getReferencedColumn: (t) => t.noteId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TranscriptSegmentsTableTableAnnotationComposer(
                $db: $db,
                $table: $db.transcriptSegmentsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$NotesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotesTableTable,
          NotesTableData,
          $$NotesTableTableFilterComposer,
          $$NotesTableTableOrderingComposer,
          $$NotesTableTableAnnotationComposer,
          $$NotesTableTableCreateCompanionBuilder,
          $$NotesTableTableUpdateCompanionBuilder,
          (NotesTableData, $$NotesTableTableReferences),
          NotesTableData,
          PrefetchHooks Function({
            bool notePointsTableRefs,
            bool noteTodosTableRefs,
            bool transcriptSegmentsTableRefs,
          })
        > {
  $$NotesTableTableTableManager(_$AppDatabase db, $NotesTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> speaker = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> durationSec = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<bool> asrIsLocal = const Value.absent(),
                Value<bool> summaryIsLocal = const Value.absent(),
                Value<String> asrName = const Value.absent(),
                Value<String> asrSub = const Value.absent(),
                Value<String> llmName = const Value.absent(),
                Value<String> llmSub = const Value.absent(),
                Value<String> gist = const Value.absent(),
                Value<String?> summaryError = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<String> audioOwnership = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesTableCompanion(
                id: id,
                title: title,
                speaker: speaker,
                source: source,
                durationSec: durationSec,
                createdAt: createdAt,
                asrIsLocal: asrIsLocal,
                summaryIsLocal: summaryIsLocal,
                asrName: asrName,
                asrSub: asrSub,
                llmName: llmName,
                llmSub: llmSub,
                gist: gist,
                summaryError: summaryError,
                audioPath: audioPath,
                audioOwnership: audioOwnership,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String speaker,
                required String source,
                required int durationSec,
                required int createdAt,
                required bool asrIsLocal,
                required bool summaryIsLocal,
                required String asrName,
                required String asrSub,
                required String llmName,
                required String llmSub,
                required String gist,
                Value<String?> summaryError = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                required String audioOwnership,
                Value<int> rowid = const Value.absent(),
              }) => NotesTableCompanion.insert(
                id: id,
                title: title,
                speaker: speaker,
                source: source,
                durationSec: durationSec,
                createdAt: createdAt,
                asrIsLocal: asrIsLocal,
                summaryIsLocal: summaryIsLocal,
                asrName: asrName,
                asrSub: asrSub,
                llmName: llmName,
                llmSub: llmSub,
                gist: gist,
                summaryError: summaryError,
                audioPath: audioPath,
                audioOwnership: audioOwnership,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NotesTableTable, NotesTableData>(table),
                  $$NotesTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                notePointsTableRefs = false,
                noteTodosTableRefs = false,
                transcriptSegmentsTableRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (notePointsTableRefs) db.notePointsTable,
                    if (noteTodosTableRefs) db.noteTodosTable,
                    if (transcriptSegmentsTableRefs) db.transcriptSegmentsTable,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (notePointsTableRefs)
                        await $_getPrefetchedData<
                          NotesTableData,
                          $NotesTableTable,
                          NotePointsTableData
                        >(
                          currentTable: table,
                          referencedTable: $$NotesTableTableReferences
                              ._notePointsTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NotesTableTableReferences(
                                db,
                                table,
                                p0,
                              ).notePointsTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.noteId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (noteTodosTableRefs)
                        await $_getPrefetchedData<
                          NotesTableData,
                          $NotesTableTable,
                          NoteTodosTableData
                        >(
                          currentTable: table,
                          referencedTable: $$NotesTableTableReferences
                              ._noteTodosTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NotesTableTableReferences(
                                db,
                                table,
                                p0,
                              ).noteTodosTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.noteId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (transcriptSegmentsTableRefs)
                        await $_getPrefetchedData<
                          NotesTableData,
                          $NotesTableTable,
                          TranscriptSegmentsTableData
                        >(
                          currentTable: table,
                          referencedTable: $$NotesTableTableReferences
                              ._transcriptSegmentsTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NotesTableTableReferences(
                                db,
                                table,
                                p0,
                              ).transcriptSegmentsTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.noteId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$NotesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotesTableTable,
      NotesTableData,
      $$NotesTableTableFilterComposer,
      $$NotesTableTableOrderingComposer,
      $$NotesTableTableAnnotationComposer,
      $$NotesTableTableCreateCompanionBuilder,
      $$NotesTableTableUpdateCompanionBuilder,
      (NotesTableData, $$NotesTableTableReferences),
      NotesTableData,
      PrefetchHooks Function({
        bool notePointsTableRefs,
        bool noteTodosTableRefs,
        bool transcriptSegmentsTableRefs,
      })
    >;
typedef $$NotePointsTableTableCreateCompanionBuilder =
    NotePointsTableCompanion Function({
      required String noteId,
      required int position,
      required String content,
      Value<int> rowid,
    });
typedef $$NotePointsTableTableUpdateCompanionBuilder =
    NotePointsTableCompanion Function({
      Value<String> noteId,
      Value<int> position,
      Value<String> content,
      Value<int> rowid,
    });

final class $$NotePointsTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $NotePointsTableTable,
          NotePointsTableData
        > {
  $$NotePointsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $NotesTableTable _noteIdTable(_$AppDatabase db) =>
      db.notesTable.createAlias('note_points__note_id__notes__id');

  $$NotesTableTableProcessedTableManager get noteId {
    final $_column = $_itemColumn<String>('note_id')!;

    final manager = $$NotesTableTableTableManager(
      $_db,
      $_db.notesTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_noteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NotePointsTableTableFilterComposer
    extends Composer<_$AppDatabase, $NotePointsTableTable> {
  $$NotePointsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  $$NotesTableTableFilterComposer get noteId {
    final $$NotesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableTableFilterComposer(
            $db: $db,
            $table: $db.notesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotePointsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $NotePointsTableTable> {
  $$NotePointsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  $$NotesTableTableOrderingComposer get noteId {
    final $$NotesTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableTableOrderingComposer(
            $db: $db,
            $table: $db.notesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotePointsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotePointsTableTable> {
  $$NotePointsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  $$NotesTableTableAnnotationComposer get noteId {
    final $$NotesTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableTableAnnotationComposer(
            $db: $db,
            $table: $db.notesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotePointsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotePointsTableTable,
          NotePointsTableData,
          $$NotePointsTableTableFilterComposer,
          $$NotePointsTableTableOrderingComposer,
          $$NotePointsTableTableAnnotationComposer,
          $$NotePointsTableTableCreateCompanionBuilder,
          $$NotePointsTableTableUpdateCompanionBuilder,
          (NotePointsTableData, $$NotePointsTableTableReferences),
          NotePointsTableData,
          PrefetchHooks Function({bool noteId})
        > {
  $$NotePointsTableTableTableManager(
    _$AppDatabase db,
    $NotePointsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotePointsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotePointsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotePointsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> noteId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotePointsTableCompanion(
                noteId: noteId,
                position: position,
                content: content,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String noteId,
                required int position,
                required String content,
                Value<int> rowid = const Value.absent(),
              }) => NotePointsTableCompanion.insert(
                noteId: noteId,
                position: position,
                content: content,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NotePointsTableTable, NotePointsTableData>(
                    table,
                  ),
                  $$NotePointsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({noteId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (noteId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.noteId,
                                referencedTable:
                                    $$NotePointsTableTableReferences
                                        ._noteIdTable(db),
                                referencedColumn:
                                    $$NotePointsTableTableReferences
                                        ._noteIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$NotePointsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotePointsTableTable,
      NotePointsTableData,
      $$NotePointsTableTableFilterComposer,
      $$NotePointsTableTableOrderingComposer,
      $$NotePointsTableTableAnnotationComposer,
      $$NotePointsTableTableCreateCompanionBuilder,
      $$NotePointsTableTableUpdateCompanionBuilder,
      (NotePointsTableData, $$NotePointsTableTableReferences),
      NotePointsTableData,
      PrefetchHooks Function({bool noteId})
    >;
typedef $$NoteTodosTableTableCreateCompanionBuilder =
    NoteTodosTableCompanion Function({
      required String noteId,
      required int position,
      required String content,
      required bool done,
      Value<int> rowid,
    });
typedef $$NoteTodosTableTableUpdateCompanionBuilder =
    NoteTodosTableCompanion Function({
      Value<String> noteId,
      Value<int> position,
      Value<String> content,
      Value<bool> done,
      Value<int> rowid,
    });

final class $$NoteTodosTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $NoteTodosTableTable,
          NoteTodosTableData
        > {
  $$NoteTodosTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $NotesTableTable _noteIdTable(_$AppDatabase db) =>
      db.notesTable.createAlias('note_todos__note_id__notes__id');

  $$NotesTableTableProcessedTableManager get noteId {
    final $_column = $_itemColumn<String>('note_id')!;

    final manager = $$NotesTableTableTableManager(
      $_db,
      $_db.notesTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_noteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NoteTodosTableTableFilterComposer
    extends Composer<_$AppDatabase, $NoteTodosTableTable> {
  $$NoteTodosTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnFilters(column),
  );

  $$NotesTableTableFilterComposer get noteId {
    final $$NotesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableTableFilterComposer(
            $db: $db,
            $table: $db.notesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteTodosTableTableOrderingComposer
    extends Composer<_$AppDatabase, $NoteTodosTableTable> {
  $$NoteTodosTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnOrderings(column),
  );

  $$NotesTableTableOrderingComposer get noteId {
    final $$NotesTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableTableOrderingComposer(
            $db: $db,
            $table: $db.notesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteTodosTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $NoteTodosTableTable> {
  $$NoteTodosTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<bool> get done =>
      $composableBuilder(column: $table.done, builder: (column) => column);

  $$NotesTableTableAnnotationComposer get noteId {
    final $$NotesTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableTableAnnotationComposer(
            $db: $db,
            $table: $db.notesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteTodosTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NoteTodosTableTable,
          NoteTodosTableData,
          $$NoteTodosTableTableFilterComposer,
          $$NoteTodosTableTableOrderingComposer,
          $$NoteTodosTableTableAnnotationComposer,
          $$NoteTodosTableTableCreateCompanionBuilder,
          $$NoteTodosTableTableUpdateCompanionBuilder,
          (NoteTodosTableData, $$NoteTodosTableTableReferences),
          NoteTodosTableData,
          PrefetchHooks Function({bool noteId})
        > {
  $$NoteTodosTableTableTableManager(
    _$AppDatabase db,
    $NoteTodosTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteTodosTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteTodosTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteTodosTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> noteId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteTodosTableCompanion(
                noteId: noteId,
                position: position,
                content: content,
                done: done,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String noteId,
                required int position,
                required String content,
                required bool done,
                Value<int> rowid = const Value.absent(),
              }) => NoteTodosTableCompanion.insert(
                noteId: noteId,
                position: position,
                content: content,
                done: done,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NoteTodosTableTable, NoteTodosTableData>(table),
                  $$NoteTodosTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({noteId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (noteId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.noteId,
                                referencedTable: $$NoteTodosTableTableReferences
                                    ._noteIdTable(db),
                                referencedColumn:
                                    $$NoteTodosTableTableReferences
                                        ._noteIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$NoteTodosTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NoteTodosTableTable,
      NoteTodosTableData,
      $$NoteTodosTableTableFilterComposer,
      $$NoteTodosTableTableOrderingComposer,
      $$NoteTodosTableTableAnnotationComposer,
      $$NoteTodosTableTableCreateCompanionBuilder,
      $$NoteTodosTableTableUpdateCompanionBuilder,
      (NoteTodosTableData, $$NoteTodosTableTableReferences),
      NoteTodosTableData,
      PrefetchHooks Function({bool noteId})
    >;
typedef $$TranscriptSegmentsTableTableCreateCompanionBuilder =
    TranscriptSegmentsTableCompanion Function({
      required String noteId,
      required int position,
      required String content,
      Value<int> rowid,
    });
typedef $$TranscriptSegmentsTableTableUpdateCompanionBuilder =
    TranscriptSegmentsTableCompanion Function({
      Value<String> noteId,
      Value<int> position,
      Value<String> content,
      Value<int> rowid,
    });

final class $$TranscriptSegmentsTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $TranscriptSegmentsTableTable,
          TranscriptSegmentsTableData
        > {
  $$TranscriptSegmentsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $NotesTableTable _noteIdTable(_$AppDatabase db) =>
      db.notesTable.createAlias('transcript_segments__note_id__notes__id');

  $$NotesTableTableProcessedTableManager get noteId {
    final $_column = $_itemColumn<String>('note_id')!;

    final manager = $$NotesTableTableTableManager(
      $_db,
      $_db.notesTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_noteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TranscriptSegmentsTableTableFilterComposer
    extends Composer<_$AppDatabase, $TranscriptSegmentsTableTable> {
  $$TranscriptSegmentsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  $$NotesTableTableFilterComposer get noteId {
    final $$NotesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableTableFilterComposer(
            $db: $db,
            $table: $db.notesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranscriptSegmentsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $TranscriptSegmentsTableTable> {
  $$TranscriptSegmentsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  $$NotesTableTableOrderingComposer get noteId {
    final $$NotesTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableTableOrderingComposer(
            $db: $db,
            $table: $db.notesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranscriptSegmentsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $TranscriptSegmentsTableTable> {
  $$TranscriptSegmentsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  $$NotesTableTableAnnotationComposer get noteId {
    final $$NotesTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableTableAnnotationComposer(
            $db: $db,
            $table: $db.notesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranscriptSegmentsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TranscriptSegmentsTableTable,
          TranscriptSegmentsTableData,
          $$TranscriptSegmentsTableTableFilterComposer,
          $$TranscriptSegmentsTableTableOrderingComposer,
          $$TranscriptSegmentsTableTableAnnotationComposer,
          $$TranscriptSegmentsTableTableCreateCompanionBuilder,
          $$TranscriptSegmentsTableTableUpdateCompanionBuilder,
          (
            TranscriptSegmentsTableData,
            $$TranscriptSegmentsTableTableReferences,
          ),
          TranscriptSegmentsTableData,
          PrefetchHooks Function({bool noteId})
        > {
  $$TranscriptSegmentsTableTableTableManager(
    _$AppDatabase db,
    $TranscriptSegmentsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranscriptSegmentsTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$TranscriptSegmentsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$TranscriptSegmentsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> noteId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TranscriptSegmentsTableCompanion(
                noteId: noteId,
                position: position,
                content: content,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String noteId,
                required int position,
                required String content,
                Value<int> rowid = const Value.absent(),
              }) => TranscriptSegmentsTableCompanion.insert(
                noteId: noteId,
                position: position,
                content: content,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $TranscriptSegmentsTableTable,
                    TranscriptSegmentsTableData
                  >(table),
                  $$TranscriptSegmentsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({noteId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (noteId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.noteId,
                                referencedTable:
                                    $$TranscriptSegmentsTableTableReferences
                                        ._noteIdTable(db),
                                referencedColumn:
                                    $$TranscriptSegmentsTableTableReferences
                                        ._noteIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TranscriptSegmentsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TranscriptSegmentsTableTable,
      TranscriptSegmentsTableData,
      $$TranscriptSegmentsTableTableFilterComposer,
      $$TranscriptSegmentsTableTableOrderingComposer,
      $$TranscriptSegmentsTableTableAnnotationComposer,
      $$TranscriptSegmentsTableTableCreateCompanionBuilder,
      $$TranscriptSegmentsTableTableUpdateCompanionBuilder,
      (TranscriptSegmentsTableData, $$TranscriptSegmentsTableTableReferences),
      TranscriptSegmentsTableData,
      PrefetchHooks Function({bool noteId})
    >;
typedef $$MigrationStateTableTableCreateCompanionBuilder =
    MigrationStateTableCompanion Function({
      required String key,
      required int completedAt,
      Value<int> rowid,
    });
typedef $$MigrationStateTableTableUpdateCompanionBuilder =
    MigrationStateTableCompanion Function({
      Value<String> key,
      Value<int> completedAt,
      Value<int> rowid,
    });

class $$MigrationStateTableTableFilterComposer
    extends Composer<_$AppDatabase, $MigrationStateTableTable> {
  $$MigrationStateTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MigrationStateTableTableOrderingComposer
    extends Composer<_$AppDatabase, $MigrationStateTableTable> {
  $$MigrationStateTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MigrationStateTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $MigrationStateTableTable> {
  $$MigrationStateTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$MigrationStateTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MigrationStateTableTable,
          MigrationStateTableData,
          $$MigrationStateTableTableFilterComposer,
          $$MigrationStateTableTableOrderingComposer,
          $$MigrationStateTableTableAnnotationComposer,
          $$MigrationStateTableTableCreateCompanionBuilder,
          $$MigrationStateTableTableUpdateCompanionBuilder,
          (
            MigrationStateTableData,
            BaseReferences<
              _$AppDatabase,
              $MigrationStateTableTable,
              MigrationStateTableData
            >,
          ),
          MigrationStateTableData,
          PrefetchHooks Function()
        > {
  $$MigrationStateTableTableTableManager(
    _$AppDatabase db,
    $MigrationStateTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MigrationStateTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MigrationStateTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MigrationStateTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<int> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MigrationStateTableCompanion(
                key: key,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required int completedAt,
                Value<int> rowid = const Value.absent(),
              }) => MigrationStateTableCompanion.insert(
                key: key,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $MigrationStateTableTable,
                    MigrationStateTableData
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $MigrationStateTableTable,
                    MigrationStateTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MigrationStateTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MigrationStateTableTable,
      MigrationStateTableData,
      $$MigrationStateTableTableFilterComposer,
      $$MigrationStateTableTableOrderingComposer,
      $$MigrationStateTableTableAnnotationComposer,
      $$MigrationStateTableTableCreateCompanionBuilder,
      $$MigrationStateTableTableUpdateCompanionBuilder,
      (
        MigrationStateTableData,
        BaseReferences<
          _$AppDatabase,
          $MigrationStateTableTable,
          MigrationStateTableData
        >,
      ),
      MigrationStateTableData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppSettingsTableTableTableManager get appSettingsTable =>
      $$AppSettingsTableTableTableManager(_db, _db.appSettingsTable);
  $$NotesTableTableTableManager get notesTable =>
      $$NotesTableTableTableManager(_db, _db.notesTable);
  $$NotePointsTableTableTableManager get notePointsTable =>
      $$NotePointsTableTableTableManager(_db, _db.notePointsTable);
  $$NoteTodosTableTableTableManager get noteTodosTable =>
      $$NoteTodosTableTableTableManager(_db, _db.noteTodosTable);
  $$TranscriptSegmentsTableTableTableManager get transcriptSegmentsTable =>
      $$TranscriptSegmentsTableTableTableManager(
        _db,
        _db.transcriptSegmentsTable,
      );
  $$MigrationStateTableTableTableManager get migrationStateTable =>
      $$MigrationStateTableTableTableManager(_db, _db.migrationStateTable);
}
