import 'package:uuid/uuid.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/remote_provider.dart';
import '../../data/models/transcript_note.dart';
import '../../data/models/transcription_result.dart';
import '../audio/audio_metadata.dart';
import '../remote/remote_api_client.dart';
import '../remote/remote_client_factory.dart';
import '../remote/remote_http.dart';
import '../service_exceptions.dart';
import '../storage/audio_cache_manager.dart';
import '../storage/managed_audio_file.dart';
import '../summarization/remote_summarization_service.dart';
import '../summarization/summary_result.dart';
import '../transcription/remote_transcription_service.dart';
import 'processing_profile.dart';
import 'processing_request.dart';

export 'processing_request.dart'
    show
        ProcessingCallbacks,
        ProcessingCredentials,
        ProcessingInput,
        ProcessingRequest,
        ProcessingStep,
        ProcessingStepCallback;

typedef ProviderClientBuilder =
    RemoteProviderClient Function(RemoteProviderId provider, String apiKey);

/// Orchestrates the independent cloud transcription and summary stages.
final class ProcessingPipeline {
  ProcessingPipeline({
    AudioMetadata? metadata,
    AudioCacheManager? cacheManager,
    ProviderClientBuilder? clientBuilder,
    DateTime Function()? now,
    Uuid? uuid,
  }) : _metadata = metadata ?? const AudioMetadata(),
       _cacheManager = cacheManager ?? AudioCacheManager(),
       _clientBuilder = clientBuilder ?? RemoteClientFactory.create,
       _now = now ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final AudioMetadata _metadata;
  final AudioCacheManager _cacheManager;
  final ProviderClientBuilder _clientBuilder;
  final DateTime Function() _now;
  final Uuid _uuid;

  Future<TranscriptNote> process(
    ProcessingRequest request, {
    ProcessingCallbacks callbacks = const ProcessingCallbacks(),
  }) async {
    _validateCredentials(request);
    await _cacheManager.validate(request.input.audio);
    _cacheManager.markActive(request.input.audio);
    late TranscriptNote note;
    try {
      final duration =
          request.input.knownDurationSec ??
          await _metadata.durationSeconds(request.input.audioPath);
      note = await _process(
        request.withKnownDuration(duration),
        callbacks: callbacks,
      );
    } finally {
      _cacheManager.markInactive(request.input.audio);
    }
    final retained = await _retainedAudio(request);
    return note.copyWith(
      audioPath: retained?.path,
      audioOwnership: retained?.ownership ?? AudioOwnership.external,
    );
  }

  void _validateCredentials(ProcessingRequest request) {
    if (request.credentials.asrApiKey.trim().isEmpty) {
      throw MissingApiKeyException(request.strings.connectFirst);
    }
    if (request.settings.summarizeEnabled &&
        request.credentials.summaryApiKey.trim().isEmpty) {
      throw MissingApiKeyException(request.strings.connectFirst);
    }
  }

  Future<TranscriptNote> _process(
    ProcessingRequest request, {
    required ProcessingCallbacks callbacks,
  }) async {
    final fallbackTitle = _fallbackTitle(request);
    callbacks.onStep?.call(ProcessingStep.transcribing);
    final transcription = await _transcribe(request);
    late SummaryResult summary;
    String? summaryError;
    try {
      summary = await _summarizeIfEnabled(
        request,
        transcription.text,
        fallbackTitle,
        callbacks,
      );
    } catch (error) {
      summary = SummaryResult(
        title: fallbackTitle,
        gist: '',
        points: const [],
        todos: const [],
      );
      summaryError = _summaryError(error, request);
    }
    final note = await _assembleNote(
      request,
      transcription,
      summary,
      fallbackTitle,
    );
    return note.copyWith(summaryError: summaryError);
  }

  String _summaryError(Object error, ProcessingRequest request) {
    final message = error is ServiceException
        ? error.message
        : 'The summary could not be generated.';
    return sanitizeRemoteErrorMessage(
      message,
      secrets: [
        request.credentials.summaryApiKey,
        request.credentials.asrApiKey,
      ],
    );
  }

  Future<TranscriptionResult> _transcribe(ProcessingRequest request) {
    final settings = request.settings;
    final client = _clientBuilder(
      settings.asrProvider,
      request.credentials.asrApiKey,
    );
    return RemoteTranscriptionService(
      client,
      settings.asrModelId(settings.asrProvider),
    ).transcribe(
      request.input.audioPath,
      languageCode: settings.transcriptionLanguage.code,
    );
  }

  Future<SummaryResult> _summarizeIfEnabled(
    ProcessingRequest request,
    String transcript,
    String fallbackTitle,
    ProcessingCallbacks callbacks,
  ) {
    if (!request.settings.summarizeEnabled) {
      return Future.value(
        SummaryResult(
          title: fallbackTitle,
          gist: '',
          points: const [],
          todos: const [],
        ),
      );
    }
    callbacks.onStep?.call(ProcessingStep.summarizing);
    final settings = request.settings;
    final client = _clientBuilder(
      settings.summaryProvider,
      request.credentials.summaryApiKey,
    );
    return RemoteSummarizationService(
      client: client,
      apiModelId: settings.summaryModelId(settings.summaryProvider),
      fallbackTitle: fallbackTitle,
    ).summarize(transcript, german: settings.language == AppLanguage.de);
  }

  Future<TranscriptNote> _assembleNote(
    ProcessingRequest request,
    TranscriptionResult transcription,
    SummaryResult summary,
    String fallbackTitle,
  ) async {
    final settings = request.settings;
    final profile = ProcessingProfile.resolve(settings);
    final noSummary = !settings.summarizeEnabled;
    return TranscriptNote(
      id: _uuid.v4(),
      title: summary.title.isEmpty ? fallbackTitle : summary.title,
      speaker: _speaker(request.input.source, request.strings),
      source: request.input.source,
      durationSec: request.input.knownDurationSec ?? 0,
      createdAt: _now(),
      asrIsLocal: false,
      summaryIsLocal: false,
      asrName: profile.asr.name,
      asrSub: profile.asr.providerName,
      llmName: noSummary ? request.strings.summaryOff : profile.summary.name,
      llmSub: noSummary ? '' : profile.summary.providerName,
      gist: summary.gist,
      points: summary.points,
      todos: summary.todos.map((text) => TodoItem(text: text)).toList(),
      transcript: transcription.segments,
      audioPath: null,
      audioOwnership: AudioOwnership.external,
    );
  }

  Future<ManagedAudioFile?> _retainedAudio(ProcessingRequest request) async {
    if (request.settings.autoDeleteAudio) return null;
    return _cacheManager.retain(
      request.input.audio,
      deleteTemporarySource: false,
    );
  }

  String _fallbackTitle(ProcessingRequest request) =>
      switch (request.input.source) {
        NoteSource.recording => request.strings.recordingLabel,
        NoteSource.file || NoteSource.shared =>
          request.input.audioPath.split('/').last.isEmpty
              ? request.strings.voiceNote
              : request.input.audioPath.split('/').last,
      };

  String _speaker(NoteSource source, AppStrings strings) => switch (source) {
    NoteSource.recording => strings.ownRecording,
    NoteSource.file => strings.tabFile,
    NoteSource.shared => strings.voiceNote,
  };
}
