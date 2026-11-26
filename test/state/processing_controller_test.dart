import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/data/models/transcription_result.dart';
import 'package:transcriber/data/repositories/notes_repository.dart';
import 'package:transcriber/services/processing/processing_pipeline.dart';
import 'package:transcriber/services/remote/remote_api_client.dart';
import 'package:transcriber/services/service_exceptions.dart';
import 'package:transcriber/services/storage/audio_cache_manager.dart';
import 'package:transcriber/services/storage/managed_audio_file.dart';
import 'package:transcriber/services/storage/storage_paths.dart';
import 'package:transcriber/state/processing_controller.dart';
import 'package:transcriber/state/providers.dart';

import 'state_test_fakes.dart';

part 'processing_controller_commit_cases.dart';
part 'processing_controller_discard_cases.dart';
part 'processing_controller_reentry_cases.dart';

void main() {
  _registerCredentialTests();
  _registerCommitTests();
  _registerDiscardTests();
  _registerRetryTests();
  _registerSummaryFailureTests();
  _registerRunningDiscardTests();
  _registerReplacementTests();
}

void _registerSummaryFailureTests() {
  test('a failed summary saves the transcript without provider keys', () async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    harness.clientFactory.summaryError = const RemoteApiException(
      'Gemini error (400): Thinking is unavailable for summary-key.',
    );

    await harness.run(save: true);

    expect(harness.state.hasError, isFalse);
    expect(harness.clientFactory.calls, [
      (RemoteProviderId.openai, 'asr-key'),
      (RemoteProviderId.google, 'summary-key'),
    ]);
    final saved = (await harness.notesRepository.load()).single;
    expect(saved.fullTranscriptText, 'Transcript');
    expect(saved.summaryError, contains('Thinking'));
    expect(saved.summaryError, isNot(contains('summary-key')));
    expect(saved.gist, isEmpty);
    expect(await harness.staging.exists(), isFalse);
    expect(await File(saved.audioPath!).exists(), isTrue);
  });
}

void _registerCredentialTests() {
  test('uses the settings confirmed for the shared input', () async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    final confirmed = AppSettings.initial().copyWith(
      transcription: const TranscriptionSettings(
        provider: RemoteProviderId.google,
      ),
      summary: const SummarySettings(enabled: false),
      autoDeleteAudio: true,
    );

    await harness.run(save: false, settings: confirmed);
    expect(harness.settingsRepository.requestedProviders, [
      RemoteProviderId.google,
    ]);
    expect(harness.clientFactory.calls, [
      (RemoteProviderId.google, 'summary-key'),
    ]);
    expect(harness.state.result!.audioPath, isNull);
    await harness.controller.commit();
    expect((await harness.notesRepository.load()).single.audioPath, isNull);
    expect(await harness.staging.exists(), isFalse);
  });
}

void _registerDiscardTests() {
  test('discard removes preview audio from temporary storage', () async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    await harness.run(save: false);

    await harness.controller.discardCurrent();

    expect(await harness.staging.exists(), isFalse);
    expect(await harness.retainedFiles(), isEmpty);
    expect(await harness.notesRepository.load(), isEmpty);
  });
}

final class _Harness {
  const _Harness({
    required this.database,
    required this.root,
    required this.staging,
    required this.notesRepository,
    required this.clientFactory,
    required this.container,
  });

  final AppDatabase database;
  final Directory root;
  final File staging;
  FakeSettingsRepository get settingsRepository =>
      container.read(settingsRepositoryProvider) as FakeSettingsRepository;
  final _ObservingNotesRepository notesRepository;
  final _ClientFactory clientFactory;
  final ProviderContainer container;

  static Future<_Harness> create({bool summaryEnabled = true}) async {
    final database = createTestDatabase();
    final settingsRepository = FakeSettingsRepository(database)
      ..keys.addAll({
        RemoteProviderId.openai: 'asr-key',
        RemoteProviderId.google: 'summary-key',
      });
    final root = await Directory.systemTemp.createTemp(
      'processing_state_test_',
    );
    final paths = StoragePaths(
      supportRoot: Directory('${root.path}/support'),
      cacheRoot: Directory('${root.path}/cache'),
    );
    final staging = File('${(await paths.importCacheDir()).path}/input.m4a');
    await staging.writeAsBytes([1, 2, 3]);
    final notesRepository = _ObservingNotesRepository(database);
    final cacheManager = AudioCacheManager(paths: Future.value(paths));
    final clientFactory = _ClientFactory();
    final pipeline = ProcessingPipeline(
      cacheManager: cacheManager,
      clientBuilder: clientFactory.create,
    );
    final settings = AppSettings.initial().copyWith(
      transcription: const TranscriptionSettings(
        provider: RemoteProviderId.openai,
      ),
      summary: SummarySettings(
        provider: RemoteProviderId.google,
        enabled: summaryEnabled,
      ),
      autoDeleteAudio: false,
    );
    final container = ProviderContainer(
      overrides: [
        initialSettingsProvider.overrideWithValue(settings),
        initialConnectionsProvider.overrideWithValue(const {}),
        initialNotesProvider.overrideWithValue(const []),
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        notesRepositoryProvider.overrideWithValue(notesRepository),
        processingPipelineProvider.overrideWithValue(pipeline),
        audioCacheManagerProvider.overrideWithValue(cacheManager),
      ],
    );
    return _Harness(
      database: database,
      root: root,
      staging: staging,
      notesRepository: notesRepository,
      clientFactory: clientFactory,
      container: container,
    );
  }

  ProcessingController get controller =>
      container.read(processingControllerProvider.notifier);
  ProcessingState get state => container.read(processingControllerProvider);
  Future<List<FileSystemEntity>> retainedFiles() async {
    final folder = Directory('${root.path}/support/audio/retained');
    return await folder.exists() ? folder.list().toList() : const [];
  }

  Future<void> run({
    required bool save,
    AudioOwnership ownership = AudioOwnership.temporary,
    AppSettings? settings,
  }) => controller.run(
    ProcessingInput(
      audio: ManagedAudioFile(path: staging.path, ownership: ownership),
      source: NoteSource.file,
      knownDurationSec: 1,
      settings: settings,
    ),
    save: save,
  );

  Future<void> dispose() async {
    container.dispose();
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  }
}

final class _ObservingNotesRepository extends NotesRepository {
  _ObservingNotesRepository(super.database);

  int attempts = 0;
  bool failOnSave = false;
  Future<void>? gate;
  Completer<void>? started;
  TranscriptNote? attempted;

  @override
  Future<TranscriptNote> add(TranscriptNote note) async {
    await _beforeStore(note);
    return super.add(note);
  }

  @override
  Future<TranscriptNote> addWithStagedAudio(
    TranscriptNote note,
    Future<void> Function() promoteAudio,
  ) => super.addWithStagedAudio(note, () async {
    await promoteAudio();
    await _beforeStore(note);
  });

  Future<void> _beforeStore(TranscriptNote note) async {
    attempts++;
    attempted = note;
    started?.complete();
    await gate;
    if (failOnSave) throw StateError('synthetic persistence failure');
  }
}

final class _ClientFactory {
  final List<(RemoteProviderId, String)> calls = [];
  Object? summaryError;
  Future<void> Function(ProcessingStep, RemoteCancellation?)? beforeStage;

  RemoteProviderClient create(RemoteProviderId provider, String apiKey) {
    calls.add((provider, apiKey));
    return _RemoteClient(this);
  }
}

final class _RemoteClient implements RemoteProviderClient {
  const _RemoteClient(this.factory);

  final _ClientFactory factory;

  @override
  void close() {}

  @override
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    required String modelId,
    String? languageCode,
    RemoteCancellation? cancellation,
  }) async {
    await factory.beforeStage?.call(ProcessingStep.transcribing, cancellation);
    return const TranscriptionResult(
      text: 'Transcript',
      segments: [TranscriptLine(text: 'Transcript')],
    );
  }

  @override
  Future<String> summarize({
    required String systemPrompt,
    required String userPrompt,
    required String modelId,
    RemoteCancellation? cancellation,
  }) async {
    await factory.beforeStage?.call(ProcessingStep.summarizing, cancellation);
    final failure = factory.summaryError;
    if (failure != null) throw failure;
    return '{"title":"Summary","gist":"Gist","points":[],"todos":[]}';
  }

  @override
  Future<List<RemoteModelInfo>> listModels({
    required bool forTranscription,
  }) async => const [];

  @override
  Future<ProviderModelCatalog> loadModelCatalog() async =>
      ProviderModelCatalog.openAi(const []);

  @override
  Future<void> testConnection() async {}
}
