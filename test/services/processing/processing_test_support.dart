import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/processing_mode.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/services/audio/audio_converter.dart';
import 'package:transcriber/services/audio/audio_metadata.dart';
import 'package:transcriber/services/processing/processing_pipeline.dart';
import 'package:transcriber/services/processing/processing_runtime.dart';
import 'package:transcriber/services/remote/remote_api_client.dart';
import 'package:transcriber/services/summarization/summarization_service.dart';
import 'package:transcriber/services/summarization/summary_result.dart';
import 'package:transcriber/services/transcription/transcription_service.dart';

ProcessingRequest testProcessingRequest([
  void Function(TestProcessingRequestBuilder builder)? configure,
]) {
  final builder = TestProcessingRequestBuilder();
  configure?.call(builder);
  return builder.build();
}

final class TestProcessingRequestBuilder {
  ProcessingMode asrMode = ProcessingMode.cloud;
  ProcessingMode summaryMode = ProcessingMode.cloud;
  bool summarizeEnabled = true;
  bool autoDeleteAudio = false;
  int? knownDurationSec = 12;
  NoteSource source = NoteSource.file;
  String audioPath = '/audio/input.m4a';
  String asrApiKey = 'asr-key';
  String summaryApiKey = 'summary-key';
  AppLanguage language = AppLanguage.en;

  ProcessingRequest build() {
    final settings = AppSettings.initial().copyWith(
      asrMode: asrMode,
      summaryMode: summaryMode,
      asrProvider: RemoteProviderId.openai,
      summaryProvider: RemoteProviderId.openai,
      summarizeEnabled: summarizeEnabled,
      autoDeleteAudio: autoDeleteAudio,
      language: language,
    );
    return ProcessingRequest(
      input: ProcessingInput(
        audioPath: audioPath,
        source: source,
        knownDurationSec: knownDurationSec,
      ),
      settings: settings,
      credentials: ProcessingCredentials(
        asrApiKey: asrApiKey,
        summaryApiKey: summaryApiKey,
      ),
    );
  }
}

TranscriptNote testTranscriptNote({
  String id = 'note-id',
  String title = 'Test note',
  int durationSec = 12,
}) => TranscriptNote(
  id: id,
  title: title,
  speaker: 'Speaker',
  source: NoteSource.file,
  durationSec: durationSec,
  createdAt: DateTime.utc(2026, 1, 2, 3, 4),
  asrIsLocal: false,
  summaryIsLocal: false,
  asrName: 'ASR',
  asrSub: 'Cloud',
  llmName: 'LLM',
  llmSub: 'Cloud',
  gist: 'Gist',
  points: const ['Point'],
  todos: [TodoItem(text: 'Action')],
  transcript: const [TranscriptLine(time: '0:00', text: 'Transcript text')],
  audioPath: '/audio/input.m4a',
);

final class FakeAudioConverter extends AudioConverter {
  FakeAudioConverter({this.outputPath = '/audio/converted.wav'});

  final String outputPath;
  final List<String> inputs = [];

  @override
  Future<String> toWhisperWav(String input) async {
    inputs.add(input);
    return outputPath;
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

final class FakeRemoteApiClient implements RemoteApiClient {
  FakeRemoteApiClient({this.supportsAudioTranscription = true});

  @override
  final bool supportsAudioTranscription;

  int chatCalls = 0;
  int transcriptionCalls = 0;
  Object? chatError;
  Object? transcriptionError;
  String chatResponse =
      '{"title":"Remote title","gist":"Remote gist",'
      '"points":["Point"],"todos":["Action"]}';
  TranscriptionResult transcription = const TranscriptionResult(
    text: 'Transcript text',
    segments: [TranscriptLine(time: '0:00', text: 'Transcript text')],
  );

  @override
  Future<String> chat({
    required String system,
    required String user,
    required String modelId,
  }) async {
    chatCalls++;
    if (chatError case final error?) throw error;
    return chatResponse;
  }

  @override
  Future<List<RemoteModelInfo>> listModels({required bool forTranscription}) {
    throw UnsupportedError('Model listing is not used in processing tests');
  }

  @override
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    String? languageCode,
    required String model,
  }) async {
    transcriptionCalls++;
    if (transcriptionError case final error?) throw error;
    return transcription;
  }
}

final class FakeTranscriptionService implements TranscriptionService {
  final List<String> paths = [];
  final List<String?> languages = [];
  TranscriptionResult result = const TranscriptionResult(
    text: 'Local transcript',
    segments: [TranscriptLine(time: '0:00', text: 'Local transcript')],
  );

  @override
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    String? languageCode,
  }) async {
    paths.add(audioPath);
    languages.add(languageCode);
    return result;
  }
}

final class FakeSummarizationService implements SummarizationService {
  final List<String> transcripts = [];
  final List<bool> germanValues = [];
  SummaryResult result = const SummaryResult(
    title: 'Local title',
    gist: 'Local gist',
    points: ['Local point'],
    todos: ['Local action'],
  );

  @override
  Future<SummaryResult> summarize(
    String transcript, {
    required bool german,
  }) async {
    transcripts.add(transcript);
    germanValues.add(german);
    return result;
  }
}

final class FakeProcessingRuntime implements ProcessingRuntime {
  bool transcriptionModelAvailable = true;
  bool summaryModelAvailable = true;
  int transcriptionAvailabilityChecks = 0;
  int summaryAvailabilityChecks = 0;
  int foregroundCalls = 0;
  int localTranscriptionBuilds = 0;
  int localSummaryBuilds = 0;
  bool failDelete = false;
  DateTime clock = DateTime.utc(2026, 2, 3, 4, 5);
  String generatedId = 'generated-id';
  final List<String> deletedPaths = [];
  final FakeTranscriptionService transcriptionService =
      FakeTranscriptionService();
  final FakeSummarizationService summarizationService =
      FakeSummarizationService();
  ForegroundProcessingRunner? foreground;

  @override
  Future<TranscriptNote> runForeground(
    ProcessingRequest request,
    ProcessingCallbacks callbacks,
  ) async {
    foregroundCalls++;
    final handler = foreground;
    if (handler == null) throw StateError('Foreground handler not configured');
    return handler(request, callbacks);
  }

  @override
  Future<bool> isLocalTranscriptionModelAvailable(AppSettings settings) async {
    transcriptionAvailabilityChecks++;
    return transcriptionModelAvailable;
  }

  @override
  Future<bool> isLocalSummaryModelAvailable(AppSettings settings) async {
    summaryAvailabilityChecks++;
    return summaryModelAvailable;
  }

  @override
  TranscriptionService createLocalTranscriptionService(AppSettings settings) {
    localTranscriptionBuilds++;
    return transcriptionService;
  }

  @override
  SummarizationService createLocalSummarizationService(
    AppSettings settings,
    String fallbackTitle,
  ) {
    localSummaryBuilds++;
    return summarizationService;
  }

  @override
  DateTime now() => clock;

  @override
  String newId() => generatedId;

  @override
  Future<void> deleteAudio(String path) async {
    deletedPaths.add(path);
    if (failDelete) throw StateError('delete failed');
  }
}
