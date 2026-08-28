import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../data/catalog/gemma_catalog.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/transcript_note.dart';
import '../summarization/gemma_engine.dart';
import '../summarization/summarization_service.dart';
import '../transcription/transcription_service.dart';
import '../transcription/whisper_engine.dart';
import 'processing_request.dart';

typedef ForegroundProcessingRunner =
    Future<TranscriptNote> Function(
      ProcessingRequest request,
      ProcessingCallbacks callbacks,
    );

/// Runtime operations that cross platform, model, filesystem, or time boundaries.
abstract interface class ProcessingRuntime {
  Future<TranscriptNote> runForeground(
    ProcessingRequest request,
    ProcessingCallbacks callbacks,
  );

  Future<bool> isLocalTranscriptionModelAvailable(AppSettings settings);

  Future<bool> isLocalSummaryModelAvailable(AppSettings settings);

  TranscriptionService createLocalTranscriptionService(AppSettings settings);

  SummarizationService createLocalSummarizationService(
    AppSettings settings,
    String fallbackTitle,
  );

  DateTime now();

  String newId();

  Future<void> deleteAudio(String path);
}

/// Production bindings for [ProcessingRuntime].
final class DefaultProcessingRuntime implements ProcessingRuntime {
  DefaultProcessingRuntime({required this.foreground});

  final ForegroundProcessingRunner foreground;

  static const _uuid = Uuid();

  @override
  Future<TranscriptNote> runForeground(
    ProcessingRequest request,
    ProcessingCallbacks callbacks,
  ) => foreground(request, callbacks);

  @override
  Future<bool> isLocalTranscriptionModelAvailable(AppSettings settings) =>
      WhisperEngine.instance.isDownloaded(settings.whisperModelId);

  @override
  Future<bool> isLocalSummaryModelAvailable(AppSettings settings) => GemmaEngine
      .instance
      .isDownloaded(GemmaCatalog.byId(settings.gemmaModelId));

  @override
  TranscriptionService createLocalTranscriptionService(AppSettings settings) =>
      WhisperTranscriptionService(
        settings.whisperModelId,
        threads: settings.whisperThreads,
      );

  @override
  SummarizationService createLocalSummarizationService(
    AppSettings settings,
    String fallbackTitle,
  ) => GemmaSummarizationService(
    settings.gemmaModelId,
    fallbackTitle: fallbackTitle,
    hfToken: settings.hfToken,
    backendId: settings.gemmaBackend.id,
  );

  @override
  DateTime now() => DateTime.now();

  @override
  String newId() => _uuid.v4();

  @override
  Future<void> deleteAudio(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
