import 'package:whisper_kit/whisper_kit.dart';

import '../../core/utils/formatting.dart';
import '../../data/models/transcript_note.dart';
import '../storage/storage_paths.dart';
import 'transcription_service.dart';

/// The single integration point for the `whisper_kit` package. All package
/// types are confined to this file so a version bump only touches one place.
class WhisperEngine {
  WhisperEngine._();
  static final WhisperEngine instance = WhisperEngine._();

  static const Map<String, WhisperModel> _enumById = {
    'tiny': WhisperModel.tiny,
    'base': WhisperModel.base,
    'small': WhisperModel.small,
    'medium': WhisperModel.medium,
  };

  WhisperModel _model(String id) => _enumById[id] ?? WhisperModel.base;

  Future<String> _modelDir() async => (await StoragePaths.instance()).whisperDir().then((d) => d.path);

  /// Downloads the model weights, reporting progress as a 0..1 fraction.
  Future<void> download(String modelId, {void Function(double progress)? onProgress}) async {
    final dir = await _modelDir();
    await downloadModel(
      model: _model(modelId),
      destinationPath: dir,
      onDownloadProgress: (received, total) {
        if (total > 0) onProgress?.call(received / total);
      },
    );
  }

  /// Transcribes a 16 kHz mono WAV file.
  Future<TranscriptionResult> transcribe(
    String wavPath, {
    String? languageCode,
    void Function(double progress)? onProgress,
  }) async {
    final dir = await _modelDir();
    final whisper = Whisper(
      model: WhisperModel.base,
      modelDir: dir,
      onDownloadProgress: (received, total) {
        if (total > 0) onProgress?.call(received / total);
      },
    );

    final request = TranscribeRequest(
      audio: wavPath,
      language: (languageCode == null || languageCode.isEmpty) ? 'auto' : languageCode,
      isTranslate: false,
    );

    final dynamic response = await whisper.transcribe(transcribeRequest: request);
    final text = (response.text as String?)?.trim() ?? '';
    return TranscriptionResult(text: text, segments: _segments(response, text));
  }

  /// Builds a Whisper instance bound to a specific model id (used internally).
  Future<TranscriptionResult> transcribeWith(
    String modelId,
    String wavPath, {
    String? languageCode,
    void Function(double progress)? onProgress,
  }) async {
    final dir = await _modelDir();
    final whisper = Whisper(
      model: _model(modelId),
      modelDir: dir,
      onDownloadProgress: (received, total) {
        if (total > 0) onProgress?.call(received / total);
      },
    );
    final request = TranscribeRequest(
      audio: wavPath,
      language: (languageCode == null || languageCode.isEmpty) ? 'auto' : languageCode,
      isTranslate: false,
    );
    final dynamic response = await whisper.transcribe(transcribeRequest: request);
    final text = (response.text as String?)?.trim() ?? '';
    return TranscriptionResult(text: text, segments: _segments(response, text));
  }

  /// Maps native timestamped segments to [TranscriptLine]s, tolerant to small
  /// API differences between package versions.
  List<TranscriptLine> _segments(dynamic response, String fullText) {
    final lines = <TranscriptLine>[];
    try {
      final dynamic raw = response.segments;
      if (raw is List) {
        for (final dynamic seg in raw) {
          final t = (seg.text as String?)?.trim() ?? '';
          if (t.isEmpty) continue;
          lines.add(TranscriptLine(time: formatDuration(_startSeconds(seg)), text: t));
        }
      }
    } catch (_) {
      // Segments unavailable in this version — fall back below.
    }
    if (lines.isEmpty && fullText.isNotEmpty) {
      lines.add(TranscriptLine(time: '0:00', text: fullText));
    }
    return lines;
  }

  int _startSeconds(dynamic seg) {
    try {
      final dynamic from = seg.fromTs;
      if (from is Duration) return from.inSeconds;
      if (from is int) return from ~/ 1000; // milliseconds
      if (from is num) return (from / 1000).round();
    } catch (_) {}
    return 0;
  }
}

/// [TranscriptionService] backed by an on-device Whisper model.
class WhisperTranscriptionService implements TranscriptionService {
  WhisperTranscriptionService(this.modelId, {this.onProgress});

  final String modelId;
  final void Function(double progress)? onProgress;

  @override
  Future<TranscriptionResult> transcribe(String audioPath, {String? languageCode}) =>
      WhisperEngine.instance.transcribeWith(
        modelId,
        audioPath,
        languageCode: languageCode,
        onProgress: onProgress,
      );
}
