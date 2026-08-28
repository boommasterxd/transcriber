import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/data/models/transcription_result.dart';
import 'package:transcriber/services/audio/audio_metadata.dart';
import 'package:transcriber/services/processing/processing_pipeline.dart';
import 'package:transcriber/services/remote/remote_api_client.dart';
import 'package:transcriber/services/storage/audio_cache_manager.dart';
import 'package:transcriber/services/storage/managed_audio_file.dart';
import 'package:transcriber/services/storage/storage_paths.dart';

ProcessingRequest testProcessingRequest({
  required ManagedAudioFile audio,
  ProcessingRequestOptions? options,
}) {
  final requestOptions = options ?? ProcessingRequestOptions();
  final settings = AppSettings.initial().copyWith(
    asrProvider: requestOptions.asrProvider,
    summaryProvider: requestOptions.summaryProvider,
    asrModelByProvider: {
      RemoteProviderId.openai: 'openai-asr',
      RemoteProviderId.google: 'google-asr',
    },
    chatModelByProvider: {
      RemoteProviderId.openai: 'openai-summary',
      RemoteProviderId.google: 'google-summary',
    },
    summarizeEnabled: requestOptions.summarizeEnabled,
    autoDeleteAudio: requestOptions.autoDeleteAudio,
    language: AppLanguage.en,
  );
  return ProcessingRequest(
    input: ProcessingInput(
      audio: audio,
      source: requestOptions.source,
      knownDurationSec: requestOptions.knownDurationSec,
    ),
    settings: settings,
    credentials: ProcessingCredentials(
      asrApiKey: requestOptions.asrApiKey,
      summaryApiKey: requestOptions.summaryApiKey,
    ),
  );
}

final class ProcessingRequestOptions {
  RemoteProviderId asrProvider = RemoteProviderId.openai;
  RemoteProviderId summaryProvider = RemoteProviderId.openai;
  bool summarizeEnabled = true;
  bool autoDeleteAudio = false;
  int? knownDurationSec = 12;
  NoteSource source = NoteSource.file;
  String asrApiKey = 'asr-key';
  String summaryApiKey = 'summary-key';
}

final class ProcessingFileFixture {
  late Directory root;
  late StoragePaths paths;
  late AudioCacheManager cacheManager;

  Future<void> setUp() async {
    root = await Directory.systemTemp.createTemp('processing-pipeline-test-');
    paths = StoragePaths(
      supportRoot: Directory(p.join(root.path, 'support')),
      cacheRoot: Directory(p.join(root.path, 'cache')),
    );
    cacheManager = AudioCacheManager(paths: Future.value(paths));
  }

  Future<void> tearDown() async {
    if (await root.exists()) await root.delete(recursive: true);
  }

  Future<ManagedAudioFile> createAudio(
    AudioOwnership ownership, {
    String filename = 'input.m4a',
  }) async {
    final directory = switch (ownership) {
      AudioOwnership.external => Directory(p.join(root.path, 'external')),
      AudioOwnership.temporary => await paths.importCacheDir(),
      AudioOwnership.retained => await paths.retainedAudioDir(),
    };
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, filename));
    await file.writeAsBytes([1, 2, 3]);
    return ManagedAudioFile(path: file.path, ownership: ownership);
  }
}

final class FakeAudioMetadata extends AudioMetadata {
  FakeAudioMetadata({this.duration = 21});

  final int duration;
  final List<String> paths = [];

  @override
  Future<int> durationSeconds(String path) async {
    paths.add(path);
    return duration;
  }
}

typedef ClientBuild = ({RemoteProviderId provider, String apiKey});

final class RecordingClientFactory {
  final List<ClientBuild> builds = [];
  final Map<RemoteProviderId, RecordingProviderClient> clients = {};

  RemoteProviderClient call(RemoteProviderId provider, String apiKey) {
    builds.add((provider: provider, apiKey: apiKey));
    return clients.putIfAbsent(provider, RecordingProviderClient.new);
  }
}

final class RecordingProviderClient implements RemoteProviderClient {
  int summaryCalls = 0;
  int transcriptionCalls = 0;
  Object? summaryError;
  Object? transcriptionError;
  String? audioPath;
  String? languageCode;
  String? asrModelId;
  String? summaryModelId;
  String? transcript;
  String summaryResponse =
      '{"title":"Remote title","gist":"Remote gist",'
      '"points":["Point"],"todos":["Action"]}';

  @override
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    required String modelId,
    String? languageCode,
  }) async {
    transcriptionCalls++;
    this.audioPath = audioPath;
    this.languageCode = languageCode;
    asrModelId = modelId;
    if (transcriptionError case final error?) throw error;
    return const TranscriptionResult(
      text: 'Transcript text',
      segments: [TranscriptLine(time: '0:00', text: 'Transcript text')],
    );
  }

  @override
  Future<String> summarize({
    required String systemPrompt,
    required String userPrompt,
    required String modelId,
  }) async {
    summaryCalls++;
    transcript = userPrompt;
    summaryModelId = modelId;
    if (summaryError case final error?) throw error;
    return summaryResponse;
  }

  @override
  Future<List<RemoteModelInfo>> listModels({required bool forTranscription}) =>
      throw UnsupportedError('Model listing is outside processing tests');

  @override
  Future<void> testConnection() async {}
}
