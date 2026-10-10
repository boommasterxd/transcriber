import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/data/models/transcription_result.dart';
import 'package:transcriber/services/processing/processing_pipeline.dart';
import 'package:transcriber/services/remote/remote_api_client.dart';
import 'package:transcriber/services/service_exceptions.dart';
import 'package:transcriber/services/storage/audio_cache_manager.dart';
import 'package:transcriber/services/storage/managed_audio_file.dart';
import 'package:transcriber/services/storage/storage_paths.dart';
import 'package:transcriber/state/processing_controller.dart';
import 'package:transcriber/state/providers.dart';

import 'state_test_fakes.dart';

void main() {
  _registerCredentialTests();
  _registerCommitTests();
  _registerDiscardTests();
  _registerRetryTests();
  _registerSummaryFailureTests();
}

void _registerSummaryFailureTests() {
  for (final save in [true, false]) {
    test('summary failure keeps the transcript with save=$save', () async {
      final harness = await _Harness.create();
      addTearDown(harness.dispose);
      harness.clientFactory.summaryError = const RemoteApiException(
        'Gemini error (400): Thinking is not enabled for this model.',
      );

      await harness.run(save: save);

      expect(harness.state.hasError, isFalse);
      expect(harness.state.result!.fullTranscriptText, 'Transcript');
      expect(harness.state.result!.summaryError, contains('Thinking'));
      expect(harness.state.result!.gist, isEmpty);
      expect(harness.clientFactory.calls, hasLength(2));
      expect(await harness.staging.exists(), !save);
      if (!save) await harness.controller.commit();
      final saved = harness.notesRepository.loaded.single;
      expect(saved.fullTranscriptText, 'Transcript');
      expect(saved.summaryError, harness.state.result!.summaryError);
      expect(await harness.staging.exists(), isFalse);
      expect(await File(saved.audioPath!).exists(), isTrue);
    });
  }
}

void _registerCredentialTests() {
  test('does not read a summary key when summarization is disabled', () async {
    final harness = await _Harness.create(summaryEnabled: false);
    addTearDown(harness.dispose);

    await harness.run(save: false);

    expect(harness.settingsRepository.requestedProviders, [
      RemoteProviderId.openai,
    ]);
    expect(harness.clientFactory.calls, [(RemoteProviderId.openai, 'asr-key')]);
  });

  test('loads independent keys for OpenAI and Google stages', () async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);

    await harness.run(save: false);

    expect(harness.settingsRepository.requestedProviders, [
      RemoteProviderId.openai,
      RemoteProviderId.google,
    ]);
    expect(harness.clientFactory.calls, [
      (RemoteProviderId.openai, 'asr-key'),
      (RemoteProviderId.google, 'summary-key'),
    ]);
  });
}

void _registerCommitTests() {
  test('save commits the note before deleting its staging audio', () async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);

    await harness.run(save: true);

    expect(harness.notesRepository.stagingExistedDuringSave, isTrue);
    expect(await harness.staging.exists(), isFalse);
    expect(harness.notesRepository.loaded, hasLength(1));
    expect(await harness.retainedAudio.exists(), isTrue);
  });

  test('preview keeps staging audio until commit succeeds', () async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);

    await harness.run(save: false);
    final retained = harness.retainedAudio;
    expect(await harness.staging.exists(), isTrue);
    expect(await retained.exists(), isTrue);
    expect(harness.notesRepository.loaded, isEmpty);

    await harness.controller.commit();

    expect(await harness.staging.exists(), isFalse);
    expect(await retained.exists(), isTrue);
    expect(harness.notesRepository.loaded, hasLength(1));
  });
}

void _registerDiscardTests() {
  test('discard removes preview-retained and staging audio', () async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    await harness.run(save: false);
    final retained = harness.retainedAudio;

    await harness.controller.discardCurrent();

    expect(await harness.staging.exists(), isFalse);
    expect(await retained.exists(), isFalse);
    expect(harness.notesRepository.loaded, isEmpty);
  });

  test(
    'provider failure preserves staging until explicitly discarded',
    () async {
      final harness = await _Harness.create();
      addTearDown(harness.dispose);
      harness.clientFactory.error = StateError('provider failed');

      await harness.run(save: true);
      expect(harness.state.error, isA<StateError>());
      expect(await harness.staging.exists(), isTrue);

      await harness.controller.discardCurrent();
      expect(await harness.staging.exists(), isFalse);
    },
  );
}

void _registerRetryTests() {
  test('provider failure can retry with the preserved staging audio', () async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    harness.clientFactory.error = StateError('provider failed');
    await harness.run(save: true);
    expect(await harness.staging.exists(), isTrue);

    harness.clientFactory.error = null;
    await harness.run(save: true);

    expect(harness.state.hasError, isFalse);
    expect(await harness.staging.exists(), isFalse);
    expect(harness.notesRepository.loaded, hasLength(1));
  });

  test('persistence failure preserves staging and allows retry', () async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    harness.notesRepository.failOnSave = true;

    await harness.run(save: true);
    expect(harness.state.error, isA<StateError>());
    expect(await harness.staging.exists(), isTrue);

    harness.notesRepository.failOnSave = false;
    await harness.run(save: true);

    expect(harness.state.hasError, isFalse);
    expect(await harness.staging.exists(), isFalse);
    expect(harness.notesRepository.loaded, isNotEmpty);
  });
}

final class _Harness {
  const _Harness({
    required this.database,
    required this.root,
    required this.staging,
    required this.settingsRepository,
    required this.notesRepository,
    required this.clientFactory,
    required this.container,
  });

  final AppDatabase database;
  final Directory root;
  final File staging;
  final FakeSettingsRepository settingsRepository;
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
    final notesRepository = _ObservingNotesRepository(database, staging);
    final cacheManager = AudioCacheManager(paths: Future.value(paths));
    final clientFactory = _ClientFactory();
    final pipeline = ProcessingPipeline(
      cacheManager: cacheManager,
      clientBuilder: clientFactory.create,
    );
    final settings = AppSettings.initial().copyWith(
      asrProvider: RemoteProviderId.openai,
      summaryProvider: RemoteProviderId.google,
      summarizeEnabled: summaryEnabled,
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
      settingsRepository: settingsRepository,
      notesRepository: notesRepository,
      clientFactory: clientFactory,
      container: container,
    );
  }

  ProcessingController get controller =>
      container.read(processingControllerProvider.notifier);
  ProcessingState get state => container.read(processingControllerProvider);
  File get retainedAudio => File(state.result!.audioPath!);

  Future<void> run({required bool save}) => controller.run(
    ProcessingInput(
      audio: ManagedAudioFile(
        path: staging.path,
        ownership: AudioOwnership.temporary,
      ),
      source: NoteSource.file,
      knownDurationSec: 1,
    ),
    save: save,
  );

  Future<void> dispose() async {
    container.dispose();
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  }
}

final class _ObservingNotesRepository extends FakeNotesRepository {
  _ObservingNotesRepository(super.database, this.staging);

  final File staging;
  bool? stagingExistedDuringSave;

  @override
  Future<void> saveAll(List<TranscriptNote> notes) async {
    stagingExistedDuringSave = await staging.exists();
    await super.saveAll(notes);
  }
}

final class _ClientFactory {
  final List<(RemoteProviderId, String)> calls = [];
  Object? error;
  Object? summaryError;

  RemoteProviderClient create(RemoteProviderId provider, String apiKey) {
    calls.add((provider, apiKey));
    return _RemoteClient(() => error, () => summaryError);
  }
}

final class _RemoteClient implements RemoteProviderClient {
  const _RemoteClient(this.error, this.summaryError);

  final Object? Function() error;
  final Object? Function() summaryError;

  @override
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    required String modelId,
    String? languageCode,
  }) async {
    final failure = error();
    if (failure != null) throw failure;
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
  }) async {
    final failure = summaryError();
    if (failure != null) throw failure;
    return '{"title":"Summary","gist":"Gist","points":[],"todos":[]}';
  }

  @override
  Future<List<RemoteModelInfo>> listModels({
    required bool forTranscription,
  }) async => const [];

  @override
  Future<void> testConnection() async {}
}
