import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/formatting.dart';
import '../../data/catalog/gemma_catalog.dart';
import '../../data/catalog/remote_catalog.dart';
import '../../data/catalog/whisper_catalog.dart';
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

/// The two visible steps of the processing flow (drives the stepper UI).
enum ProcessingStep { transcribing, summarizing }

/// Orchestrates the full audio → note flow: optional WAV conversion, then
/// transcription, then summarization — using either on-device or cloud
/// services depending on the active [AppSettings].
class ProcessingPipeline {
  ProcessingPipeline({
    AudioConverter? converter,
    AudioMetadata? metadata,
  })  : _converter = converter ?? const AudioConverter(),
        _metadata = metadata ?? const AudioMetadata();

  final AudioConverter _converter;
  final AudioMetadata _metadata;
  static const _uuid = Uuid();

  Future<TranscriptNote> process({
    required String audioPath,
    required NoteSource source,
    required AppSettings settings,
    required AppStrings strings,
    required String apiKey,
    int? knownDurationSec,
    void Function(ProcessingStep step)? onStep,
    void Function(double progress)? onModelProgress,
  }) async {
    final german = settings.language == AppLanguage.de;

    // Pre-flight checks for on-device mode.
    if (settings.mode.isLocal) {
      final gemmaSpec = GemmaCatalog.byId(settings.gemmaModelId);
      if (!await GemmaEngine.instance.isDownloaded(gemmaSpec)) {
        throw ModelNotDownloadedException(strings.modelMissingBody);
      }
    } else if (apiKey.isEmpty) {
      throw MissingApiKeyException(strings.connectFirst);
    }

    final fallbackTitle = _fallbackTitle(audioPath, source, strings);

    // ---- Step 1: transcription ----
    onStep?.call(ProcessingStep.transcribing);
    final transcription = await _transcribe(
      audioPath: audioPath,
      settings: settings,
      apiKey: apiKey,
      onModelProgress: onModelProgress,
    );

    // ---- Step 2: summarization ----
    onStep?.call(ProcessingStep.summarizing);
    final summary = await _summarize(
      transcript: transcription.text,
      settings: settings,
      apiKey: apiKey,
      german: german,
      fallbackTitle: fallbackTitle,
    );

    final durationSec = knownDurationSec ?? await _metadata.durationSeconds(audioPath);
    final meta = _modelMetadata(settings, apiKey);

    final retainedPath = settings.autoDeleteAudio ? null : audioPath;
    if (settings.autoDeleteAudio) {
      _deleteQuietly(audioPath);
    }

    return TranscriptNote(
      id: _uuid.v4(),
      title: summary.title.isEmpty ? fallbackTitle : summary.title,
      speaker: _speaker(source, strings),
      source: source,
      durationSec: durationSec,
      createdAt: DateTime.now(),
      mode: settings.mode,
      providerId: settings.mode.isCloud ? settings.provider.id : null,
      asrName: meta.asrName,
      asrSub: meta.asrSub,
      llmName: meta.llmName,
      llmSub: meta.llmSub,
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
    final TranscriptionService service;
    String input = audioPath;

    if (settings.mode.isLocal) {
      input = await _converter.toWhisperWav(audioPath);
      service = WhisperTranscriptionService(settings.whisperModelId, onProgress: onModelProgress);
    } else {
      service = RemoteTranscriptionService(_client(settings, apiKey));
    }
    return service.transcribe(input, languageCode: 'auto');
  }

  Future<SummaryResult> _summarize({
    required String transcript,
    required AppSettings settings,
    required String apiKey,
    required bool german,
    required String fallbackTitle,
  }) async {
    final SummarizationService service;
    if (settings.mode.isLocal) {
      service = GemmaSummarizationService(settings.gemmaModelId, fallbackTitle: fallbackTitle);
    } else {
      service = RemoteSummarizationService(
        client: _client(settings, apiKey),
        apiModelId: settings.currentRemoteModel.apiModelId,
        fallbackTitle: fallbackTitle,
      );
    }
    return service.summarize(transcript, german: german);
  }

  RemoteApiClient _client(AppSettings settings, String apiKey) =>
      RemoteClientFactory.create(settings.provider, apiKey);

  _ModelMeta _modelMetadata(AppSettings settings, String apiKey) {
    final german = settings.language == AppLanguage.de;
    if (settings.mode.isLocal) {
      final whisper = WhisperCatalog.byId(settings.whisperModelId);
      final gemma = GemmaCatalog.byId(settings.gemmaModelId);
      return _ModelMeta(
        asrName: whisper.displayName,
        asrSub: formatBytes(whisper.sizeBytes, german: german),
        llmName: gemma.displayName,
        llmSub: formatBytes(gemma.sizeBytes, german: german),
      );
    }
    final provider = RemoteCatalog.provider(settings.provider);
    final model = settings.currentRemoteModel;
    final client = _client(settings, apiKey);
    return _ModelMeta(
      asrName: client.supportsAudioTranscription ? client.asrLabel : '—',
      asrSub: 'Cloud',
      llmName: model.displayName,
      llmSub: provider.name,
    );
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

class _ModelMeta {
  const _ModelMeta({
    required this.asrName,
    required this.asrSub,
    required this.llmName,
    required this.llmSub,
  });
  final String asrName;
  final String asrSub;
  final String llmName;
  final String llmSub;
}
