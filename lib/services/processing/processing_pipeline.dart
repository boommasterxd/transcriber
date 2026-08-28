import '../../core/l10n/app_strings.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/remote_provider.dart';
import '../../data/models/transcript_note.dart';
import '../../data/models/transcription_result.dart';
import '../audio/audio_converter.dart';
import '../audio/audio_metadata.dart';
import '../remote/remote_api_client.dart';
import '../remote/remote_client_factory.dart';
import '../service_exceptions.dart';
import '../summarization/remote_summarization_service.dart';
import '../summarization/summarization_service.dart';
import '../summarization/summary_result.dart';
import '../transcription/remote_transcription_service.dart';
import '../transcription/transcription_service.dart';
import 'processing_foreground.dart';
import 'processing_profile.dart';
import 'processing_request.dart';
import 'processing_runtime.dart';

export 'processing_request.dart'
    show
        ModelProgressCallback,
        ProcessingCallbacks,
        ProcessingCredentials,
        ProcessingInput,
        ProcessingRequest,
        ProcessingStep,
        ProcessingStepCallback;

typedef RemoteClientBuilder =
    RemoteApiClient Function(RemoteProviderId provider, String apiKey);

/// Orchestrates transcription, optional summarization, and note assembly.
class ProcessingPipeline {
  ProcessingPipeline({
    AudioConverter? converter,
    AudioMetadata? metadata,
    RemoteClientBuilder? remoteClientBuilder,
    ProcessingRuntime? runtime,
  }) : _converter = converter ?? const AudioConverter(),
       _metadata = metadata ?? const AudioMetadata(),
       _remoteClientBuilder = remoteClientBuilder ?? RemoteClientFactory.create,
       _runtime =
           runtime ??
           DefaultProcessingRuntime(
             foreground: (request, callbacks) =>
                 ProcessingForegroundService.fromStrings(
                   request.strings,
                 ).run(request, callbacks: callbacks),
           );

  final AudioConverter _converter;
  final AudioMetadata _metadata;
  final RemoteClientBuilder _remoteClientBuilder;
  final ProcessingRuntime _runtime;

  Future<TranscriptNote> process(
    ProcessingRequest request, {
    ProcessingCallbacks callbacks = const ProcessingCallbacks(),
  }) async {
    await _validate(request);
    final durationSec =
        request.input.knownDurationSec ??
        await _metadata.durationSeconds(request.input.audioPath);
    final resolvedRequest = request.withKnownDuration(durationSec);

    if (_requiresForeground(request.settings)) {
      return _runtime.runForeground(resolvedRequest, callbacks);
    }
    return processCurrentIsolate(resolvedRequest, callbacks: callbacks);
  }

  Future<void> _validate(ProcessingRequest request) async {
    final settings = request.settings;
    final strings = request.strings;
    if (settings.asrMode.isLocal &&
        !await _runtime.isLocalTranscriptionModelAvailable(settings)) {
      throw ModelNotDownloadedException(strings.modelMissingBody);
    }

    final summaryLocal = _usesLocalSummary(settings);
    if (summaryLocal &&
        !await _runtime.isLocalSummaryModelAvailable(settings)) {
      throw ModelNotDownloadedException(strings.modelMissingBody);
    }
    if (settings.asrMode.isCloud && request.credentials.asrApiKey.isEmpty) {
      throw MissingApiKeyException(strings.connectFirst);
    }
    if (_usesCloudSummary(settings) &&
        request.credentials.summaryApiKey.isEmpty) {
      throw MissingApiKeyException(strings.connectFirst);
    }
  }

  bool _requiresForeground(AppSettings settings) =>
      settings.asrMode.isLocal || _usesLocalSummary(settings);

  bool _usesLocalSummary(AppSettings settings) =>
      settings.summarizeEnabled && settings.summaryMode.isLocal;

  bool _usesCloudSummary(AppSettings settings) =>
      settings.summarizeEnabled && settings.summaryMode.isCloud;

  /// Runs the validated processing body in the current isolate.
  Future<TranscriptNote> processCurrentIsolate(
    ProcessingRequest request, {
    ProcessingCallbacks callbacks = const ProcessingCallbacks(),
  }) async {
    final fallbackTitle = _fallbackTitle(request);
    callbacks.onStep?.call(ProcessingStep.transcribing);
    final transcription = await _transcribe(request);
    final summary = await _summarizeIfEnabled(
      request,
      transcription.text,
      fallbackTitle,
      callbacks,
    );
    return _assembleNote(request, transcription, summary, fallbackTitle);
  }

  Future<TranscriptionResult> _transcribe(ProcessingRequest request) {
    final settings = request.settings;
    final languageCode = settings.transcriptionLanguage.code;
    if (settings.asrMode.isLocal) {
      return _transcribeLocally(request, languageCode);
    }
    final client = _remoteClientBuilder(
      settings.asrProvider,
      request.credentials.asrApiKey,
    );
    return RemoteTranscriptionService(
      client,
      settings.asrModelId(settings.asrProvider),
    ).transcribe(request.input.audioPath, languageCode: languageCode);
  }

  Future<TranscriptionResult> _transcribeLocally(
    ProcessingRequest request,
    String languageCode,
  ) async {
    final settings = request.settings;
    final language = languageCode == 'auto'
        ? settings.language.code
        : languageCode;
    final wav = await _converter.toWhisperWav(request.input.audioPath);
    return _runtime
        .createLocalTranscriptionService(settings)
        .transcribe(wav, languageCode: language);
  }

  Future<SummaryResult> _summarizeIfEnabled(
    ProcessingRequest request,
    String transcript,
    String fallbackTitle,
    ProcessingCallbacks callbacks,
  ) async {
    if (!request.settings.summarizeEnabled) {
      return SummaryResult(
        title: fallbackTitle,
        gist: '',
        points: const [],
        todos: const [],
      );
    }
    callbacks.onStep?.call(ProcessingStep.summarizing);
    return _summarize(request, transcript, fallbackTitle);
  }

  Future<SummaryResult> _summarize(
    ProcessingRequest request,
    String transcript,
    String fallbackTitle,
  ) {
    final settings = request.settings;
    final service = settings.summaryMode.isLocal
        ? _localSummarizationService(settings, fallbackTitle)
        : _remoteSummarizationService(request, fallbackTitle);
    return service.summarize(
      transcript,
      german: settings.language == AppLanguage.de,
    );
  }

  SummarizationService _localSummarizationService(
    AppSettings settings,
    String fallbackTitle,
  ) => _runtime.createLocalSummarizationService(settings, fallbackTitle);

  SummarizationService _remoteSummarizationService(
    ProcessingRequest request,
    String fallbackTitle,
  ) {
    final settings = request.settings;
    final client = _remoteClientBuilder(
      settings.summaryProvider,
      request.credentials.summaryApiKey,
    );
    return RemoteSummarizationService(
      client: client,
      apiModelId: settings.summaryModelId(settings.summaryProvider),
      fallbackTitle: fallbackTitle,
    );
  }

  Future<TranscriptNote> _assembleNote(
    ProcessingRequest request,
    TranscriptionResult transcription,
    SummaryResult summary,
    String fallbackTitle,
  ) async {
    final settings = request.settings;
    final strings = request.strings;
    final profile = ProcessingProfile.resolve(settings);
    final noSummary = !settings.summarizeEnabled;
    final durationSec =
        request.input.knownDurationSec ??
        await _metadata.durationSeconds(request.input.audioPath);
    final retainedPath = settings.autoDeleteAudio
        ? null
        : request.input.audioPath;
    if (settings.autoDeleteAudio) {
      await _deleteQuietly(request.input.audioPath);
    }
    return TranscriptNote(
      id: _runtime.newId(),
      title: summary.title.isEmpty ? fallbackTitle : summary.title,
      speaker: _speaker(request.input.source, strings),
      source: request.input.source,
      durationSec: durationSec,
      createdAt: _runtime.now(),
      asrIsLocal: profile.asr.isLocal,
      summaryIsLocal: noSummary || profile.summary.isLocal,
      asrName: profile.asr.name,
      asrSub: profile.asr.sub,
      llmName: noSummary ? strings.summaryOff : profile.summary.name,
      llmSub: noSummary ? '' : profile.summary.sub,
      gist: summary.gist,
      points: summary.points,
      todos: summary.todos.map((text) => TodoItem(text: text)).toList(),
      transcript: transcription.segments,
      audioPath: retainedPath,
    );
  }

  String _fallbackTitle(ProcessingRequest request) {
    switch (request.input.source) {
      case NoteSource.recording:
        return request.strings.recordingLabel;
      case NoteSource.file:
      case NoteSource.shared:
        final name = request.input.audioPath.split('/').last;
        return name.isEmpty ? request.strings.voiceNote : name;
    }
  }

  String _speaker(NoteSource source, AppStrings strings) {
    switch (source) {
      case NoteSource.recording:
        return strings.ownRecording;
      case NoteSource.file:
        return strings.tabFile;
      case NoteSource.shared:
        return strings.voiceNote;
    }
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      await _runtime.deleteAudio(path);
    } catch (_) {}
  }
}

/// Runs the pipeline core inside the foreground-service isolate.
Future<TranscriptNote> runProcessingCore(
  ProcessingRequest request, {
  ProcessingCallbacks callbacks = const ProcessingCallbacks(),
}) => ProcessingPipeline().processCurrentIsolate(request, callbacks: callbacks);
