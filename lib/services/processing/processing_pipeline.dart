import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/catalog/gemma_catalog.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/transcript_note.dart';
import '../audio/audio_converter.dart';
import '../audio/audio_metadata.dart';
import '../remote/remote_api_client.dart';
import '../remote/remote_client_factory.dart';
import '../service_exceptions.dart';
import '../summarization/gemma_engine.dart';
import '../summarization/remote_summarization_service.dart';
import '../summarization/summarization_service.dart';
import '../summarization/summary_result.dart';
import '../transcription/remote_transcription_service.dart';
import '../transcription/transcription_service.dart';
import '../transcription/whisper_engine.dart';
import 'processing_profile.dart';

/// The two visible steps of the processing flow (drives the stepper UI).
enum ProcessingStep { transcribing, summarizing }

/// Orchestrates the full audio → note flow. Transcription and summarization are
/// resolved independently from [AppSettings]: each may run on-device or via a
/// (possibly different) cloud provider.
class ProcessingPipeline {
  ProcessingPipeline({AudioConverter? converter, AudioMetadata? metadata})
      : _converter = converter ?? const AudioConverter(),
        _metadata = metadata ?? const AudioMetadata();

  final AudioConverter _converter;
  final AudioMetadata _metadata;
  static const _uuid = Uuid();

  Future<TranscriptNote> process({
    required String audioPath,
    required NoteSource source,
    required AppSettings settings,
    required AppStrings strings,
    required String asrApiKey,
    required String summaryApiKey,
    int? knownDurationSec,
    void Function(ProcessingStep step)? onStep,
    void Function(double progress)? onModelProgress,
  }) async {
    final german = settings.language == AppLanguage.de;

    // Pre-flight checks.
    if (settings.summaryMode.isLocal &&
        !await GemmaEngine.instance.isDownloaded(GemmaCatalog.byId(settings.gemmaModelId))) {
      throw ModelNotDownloadedException(strings.modelMissingBody);
    }
    if (settings.asrMode.isCloud && asrApiKey.isEmpty) {
      throw MissingApiKeyException(strings.connectFirst);
    }
    if (settings.summaryMode.isCloud && summaryApiKey.isEmpty) {
      throw MissingApiKeyException(strings.connectFirst);
    }

    final fallbackTitle = _fallbackTitle(audioPath, source, strings);

    onStep?.call(ProcessingStep.transcribing);
    final transcription = await _transcribe(
      audioPath: audioPath,
      settings: settings,
      apiKey: asrApiKey,
      onModelProgress: onModelProgress,
    );

    onStep?.call(ProcessingStep.summarizing);
    final summary = await _summarize(
      transcript: transcription.text,
      settings: settings,
      apiKey: summaryApiKey,
      german: german,
      fallbackTitle: fallbackTitle,
    );

    final durationSec = knownDurationSec ?? await _metadata.durationSeconds(audioPath);
    final profile = ProcessingProfile.resolve(settings);

    final retainedPath = settings.autoDeleteAudio ? null : audioPath;
    if (settings.autoDeleteAudio) _deleteQuietly(audioPath);

    return TranscriptNote(
      id: _uuid.v4(),
      title: summary.title.isEmpty ? fallbackTitle : summary.title,
      speaker: _speaker(source, strings),
      source: source,
      durationSec: durationSec,
      createdAt: DateTime.now(),
      asrIsLocal: profile.asr.isLocal,
      summaryIsLocal: profile.summary.isLocal,
      asrName: profile.asr.name,
      asrSub: profile.asr.sub,
      llmName: profile.summary.name,
      llmSub: profile.summary.sub,
      gist: summary.gist,
      points: summary.points,
      todos: summary.todos.map((t) => TodoItem(text: t)).toList(),
      transcript: transcription.segments,
      audioPath: retainedPath,
    );
  }

  Future<TranscriptionResult> _transcribe({
    required String audioPath,
    required AppSettings settings,
    required String apiKey,
    void Function(double progress)? onModelProgress,
  }) async {
    if (settings.asrMode.isLocal) {
      final wav = await _converter.toWhisperWav(audioPath);
      return WhisperTranscriptionService(settings.whisperModelId, onProgress: onModelProgress)
          .transcribe(wav, languageCode: 'auto');
    }
    final client = RemoteClientFactory.create(settings.asrProvider, apiKey);
    return RemoteTranscriptionService(client).transcribe(audioPath, languageCode: 'auto');
  }

  Future<SummaryResult> _summarize({
    required String transcript,
    required AppSettings settings,
    required String apiKey,
    required bool german,
    required String fallbackTitle,
  }) async {
    final SummarizationService service;
    if (settings.summaryMode.isLocal) {
      service = GemmaSummarizationService(
        settings.gemmaModelId,
        fallbackTitle: fallbackTitle,
        hfToken: settings.hfToken,
      );
    } else {
      final RemoteApiClient client = RemoteClientFactory.create(settings.summaryProvider, apiKey);
      service = RemoteSummarizationService(
        client: client,
        apiModelId: settings.summaryRemoteModel.apiModelId,
        fallbackTitle: fallbackTitle,
      );
    }
    return service.summarize(transcript, german: german);
  }

  String _fallbackTitle(String audioPath, NoteSource source, AppStrings strings) {
    switch (source) {
      case NoteSource.recording:
        return strings.recordingLabel;
      case NoteSource.file:
      case NoteSource.shared:
        final name = audioPath.split('/').last;
        return name.isEmpty ? strings.voiceNote : name;
    }
  }

  String _speaker(NoteSource source, AppStrings strings) {
    switch (source) {
      case NoteSource.recording:
        return strings.isDe ? 'Eigene Aufnahme' : 'Your recording';
      case NoteSource.file:
        return strings.isDe ? 'Datei' : 'File';
      case NoteSource.shared:
        return strings.voiceNote;
    }
  }

  void _deleteQuietly(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }
}
