import 'dart:io';

import 'package:background_downloader/background_downloader.dart' as bd;
import 'package:path/path.dart' as p;
import 'package:whisper_kit/whisper_kit.dart';

import '../../core/utils/formatting.dart';
import '../../data/models/transcript_note.dart';
import '../storage/storage_paths.dart';
import 'transcription_service.dart';

/// The single integration point for the `whisper_kit` package.
///
/// Model weights (whisper.cpp GGML) are fetched via `background_downloader`
/// (resumable, runs in an Android foreground service so it survives the app
/// going to the background) into the directory whisper.cpp expects
/// (`<appSupport>/models/whisper/ggml-<id>.bin`). File presence is the
/// "downloaded" signal.
class WhisperEngine {
  WhisperEngine._();
  static final WhisperEngine instance = WhisperEngine._();

  static const _whisperSubdir = 'models/whisper';

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

  /// Downloads the GGML weights for [modelId] in the background, reporting
  /// progress (0..1).
  Future<void> download(String modelId, {void Function(double progress)? onProgress}) async {
    final task = bd.DownloadTask(
      url: '$_ggmlBaseUrl/ggml-$modelId.bin',
      filename: 'ggml-$modelId.bin',
      directory: _whisperSubdir,
      baseDirectory: bd.BaseDirectory.applicationSupport,
      updates: bd.Updates.statusAndProgress,
      retries: 3,
      allowPause: true,
    );
    final result = await bd.FileDownloader().download(
      task,
      onProgress: (progress) {
        if (progress >= 0) onProgress?.call(progress);
      },
    );
    if (result.status != bd.TaskStatus.complete) {
      throw Exception('Download fehlgeschlagen (${result.status.name})');
    }
  }

  Future<void> deleteDownload(String modelId) async {
    final file = File(await _modelFile(modelId));
    if (await file.exists()) await file.delete();
  }

  /// Transcribes a 16 kHz mono WAV file with the given model id and thread count.
  ///
  /// No `onDownloadProgress` callback is passed: whisper_kit ships the [Whisper]
  /// instance to a background isolate, and a closure capturing app state would
  /// be unsendable. Weights are pre-fetched via [download] instead.
  Future<TranscriptionResult> transcribeWith(
    String modelId,
    String wavPath, {
    String? languageCode,
    int threads = 4,
  }) async {
    final dir = await _modelDir();
    final whisper = Whisper(model: _model(modelId), modelDir: dir);
    // IMPORTANT: never pass the literal 'auto'. whisper_kit maps language=="auto"
    // to whisper.cpp's `detect_language` flag, which only *detects* the language
    // and returns before transcribing (empty text, no error). An empty string
    // makes the runtime auto-detect AND transcribe.
    final isAuto = languageCode == null || languageCode.isEmpty || languageCode == 'auto';
    final request = TranscribeRequest(
      audio: wavPath,
      language: isAuto ? '' : languageCode,
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
  WhisperTranscriptionService(this.modelId, {this.threads = 4});

  final String modelId;
  final int threads;

  @override
  Future<TranscriptionResult> transcribe(String audioPath, {String? languageCode}) =>
      WhisperEngine.instance.transcribeWith(
        modelId,
        audioPath,
        languageCode: languageCode,
        threads: threads,
      );
}
