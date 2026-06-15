import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:whisper_kit/whisper_kit.dart';

import '../../core/utils/formatting.dart';
import '../../data/models/transcript_note.dart';
import '../download/file_downloader.dart';
import '../storage/storage_paths.dart';
import 'transcription_service.dart';

/// The single integration point for the `whisper_kit` package.
///
/// Model weights (whisper.cpp GGML) are fetched directly into the model
/// directory under the file name whisper.cpp expects (`ggml-<id>.bin`), so the
/// native core finds them and never needs to download. This keeps downloading
/// version-independent and gives us reliable progress + a clear "downloaded"
/// signal (file presence).
class WhisperEngine {
  WhisperEngine._();
  static final WhisperEngine instance = WhisperEngine._();

  final FileDownloader _downloader = const FileDownloader();

  static const Map<String, WhisperModel> _enumById = {
    'tiny': WhisperModel.tiny,
    'base': WhisperModel.base,
    'small': WhisperModel.small,
    'medium': WhisperModel.medium,
  };

  static const _ggmlBaseUrl = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main';

  WhisperModel _model(String id) => _enumById[id] ?? WhisperModel.base;

  Future<String> _modelDir() async => (await StoragePaths.instance()).whisperDir().then((d) => d.path);

  Future<String> _modelFile(String id) async => p.join(await _modelDir(), 'ggml-$id.bin');

  Future<bool> isDownloaded(String id) async => File(await _modelFile(id)).exists();

  /// Downloads the GGML weights for [modelId], reporting progress (0..1).
  Future<void> download(String modelId, {void Function(double progress)? onProgress}) async {
    await _downloader.download(
      '$_ggmlBaseUrl/ggml-$modelId.bin',
      await _modelFile(modelId),
      onProgress: onProgress,
    );
  }

  Future<void> deleteDownload(String modelId) async {
    final file = File(await _modelFile(modelId));
    if (await file.exists()) await file.delete();
  }

  /// Transcribes a 16 kHz mono WAV file with the given model id and thread count.
  Future<TranscriptionResult> transcribeWith(
    String modelId,
    String wavPath, {
    String? languageCode,
    int threads = 4,
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
      threads: threads,
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
  WhisperTranscriptionService(this.modelId, {this.threads = 4, this.onProgress});

  final String modelId;
  final int threads;
  final void Function(double progress)? onProgress;

  @override
  Future<TranscriptionResult> transcribe(String audioPath, {String? languageCode}) =>
      WhisperEngine.instance.transcribeWith(
        modelId,
        audioPath,
        languageCode: languageCode,
        threads: threads,
        onProgress: onProgress,
      );
}
