import 'dart:async';
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
  test(
    'dismissal waits for pending commit without deleting saved audio',
    () async {
      final harness = await _Harness.create();
      addTearDown(harness.dispose);
      await harness.run(save: false);
      final retained = harness.retainedAudio;
      final gate = Completer<void>();
      final started = Completer<void>();
      harness.notesRepository.gate = gate.future;
      harness.notesRepository.started = started;

      final commit = harness.controller.commit();
      await started.future;
      final duplicateCommit = harness.controller.commit();
      final discard = harness.controller.discardCurrent();
      expect(await retained.exists(), isTrue);
      expect(await harness.staging.exists(), isTrue);
      gate.complete();
      await Future.wait([commit, duplicateCommit, discard]);

      expect(harness.notesRepository.saved, hasLength(1));
      expect(harness.notesRepository.loaded.single.audioPath, retained.path);
      expect(await retained.exists(), isTrue);
      expect(await harness.staging.exists(), isFalse);
    },
  );

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
  for (final saveFails in [true, false]) {
    test(
      'discard during save preserves only committed audio: $saveFails',
      () async {
        final harness = await _Harness.create();
        addTearDown(harness.dispose);
        final gate = Completer<void>();
        final started = Completer<void>();
        harness.notesRepository
          ..failOnSave = saveFails
          ..gate = gate.future
          ..started = started;

        final run = harness.run(save: true);
        await started.future;
        final retained = File(harness.notesRepository.attempted!.audioPath!);
        expect(await retained.exists(), isTrue);
        await harness.controller.discardCurrent();
        gate.complete();
        await run;

        expect(await harness.staging.exists(), isFalse);
        expect(await retained.exists(), !saveFails);
        expect(harness.notesRepository.loaded, hasLength(saveFails ? 0 : 1));
        if (saveFails) {
          expect(
            harness.state,
            isA<ProcessingState>()
                .having((state) => state.running, 'running', false)
                .having((state) => state.result, 'result', isNull)
                .having((state) => state.error, 'error', isNull),
          );
          await harness.controller.commit();
          expect(harness.notesRepository.loaded, isEmpty);
        }
      },
    );
  }

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

    await _expectCommitted(harness);
  });

  test('persistence failure preserves staging and allows retry', () async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    harness.notesRepository.failOnSave = true;

    await harness.run(save: true);
    expect(harness.state.error, isA<StateError>());
    expect(await harness.staging.exists(), isTrue);
    expect(harness.notesRepository.loaded, isEmpty);
    final attempts = harness.clientFactory.calls.length;
    final pending = harness.notesRepository.saved.single.single;
    expect(await File(pending.audioPath!).exists(), isTrue);

    harness.notesRepository.failOnSave = false;
    await harness.run(save: true);

    await _expectCommitted(harness);
    expect(harness.notesRepository.loaded.single.id, pending.id);
    expect(harness.notesRepository.loaded.single.audioPath, pending.audioPath);
    expect(await File(pending.audioPath!).exists(), isTrue);
    expect(harness.clientFactory.calls, hasLength(attempts));
  });
}

Future<void> _expectCommitted(_Harness harness) async {
  expect(harness.state.error, isNull);
  expect(await harness.staging.exists(), isFalse);
  expect(harness.notesRepository.loaded, hasLength(1));
  expect(
    harness.notesRepository.loaded.single.fullTranscriptText,
    'Transcript',
  );
  expect(await harness.retainedAudio.exists(), isTrue);
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
    final notesRepository = _ObservingNotesRepository(database, staging);
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
  Future<void>? gate;
  Completer<void>? started;
  TranscriptNote? attempted;

  @override
  Future<TranscriptNote> add(TranscriptNote note) async {
    stagingExistedDuringSave = await staging.exists();
    attempted = note;
    started?.complete();
    await gate;
    return super.add(note);
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
  void close() {}

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
  Future<ProviderModelCatalog> loadModelCatalog() async =>
      ProviderModelCatalog.openAi(const []);

  @override
  Future<void> testConnection() async {}
}
