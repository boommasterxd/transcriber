import 'dart:io';

import 'package:background_downloader/background_downloader.dart' as bd;
import 'package:path/path.dart' as p;
import 'package:whisper_kit/whisper_kit.dart';

import '../../core/utils/formatting.dart';
import '../../data/models/transcript_note.dart';
import '../storage/storage_paths.dart';
import 'transcription_service.dart';

typedef WhisperTranscribeRunner =
    Future<Object?> Function({
      required WhisperModel model,
      required String modelDir,
      required TranscribeRequest request,
    });

typedef WhisperDownloadRunner =
    Future<bd.TaskStatus> Function({
      required bd.DownloadTask task,
      required void Function(double progress) onProgress,
    });

/// The single integration point for the `whisper_kit` package.
///
/// Model weights (whisper.cpp GGML) are fetched via `background_downloader`
/// (resumable, runs in an Android foreground service so it survives the app
/// going to the background) into the directory whisper.cpp expects
/// (`<appSupport>/models/whisper/ggml-<id>.bin`). File presence is the
/// "downloaded" signal.
class WhisperEngine {
  factory WhisperEngine({
    WhisperTranscribeRunner transcribeRunner = _runWhisper,
    WhisperDownloadRunner downloadRunner = _runDownload,
  }) => WhisperEngine._(transcribeRunner, downloadRunner);

  WhisperEngine._(this._transcribeRunner, this._downloadRunner);

  static final WhisperEngine instance = WhisperEngine();

  final WhisperTranscribeRunner _transcribeRunner;
  final WhisperDownloadRunner _downloadRunner;

  static const _whisperSubdir = 'models/whisper';

  static const Map<String, _WhisperModelSpec> _models = {
    'tiny': _WhisperModelSpec('tiny', WhisperModel.tiny),
    'base': _WhisperModelSpec('base', WhisperModel.base),
    'small': _WhisperModelSpec('small', WhisperModel.small),
    'medium': _WhisperModelSpec('medium', WhisperModel.medium),
  };

  static const _ggmlBaseUrl =
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main';

  _WhisperModelSpec _model(String id) => _models[id] ?? _models['base']!;

  Future<String> _modelDir() async =>
      (await StoragePaths.instance()).whisperDir().then((d) => d.path);

  Future<String> _modelFile(_WhisperModelSpec model) async =>
      p.join(await _modelDir(), model.fileName);

  Future<bool> isDownloaded(String id) async =>
      File(await _modelFile(_model(id))).exists();

  /// Downloads the GGML weights for [modelId] in the background, reporting
  /// progress (0..1).
  Future<void> download(
    String modelId, {
    void Function(double progress)? onProgress,
  }) async {
    final model = _model(modelId);
    final task = bd.DownloadTask(
      url: '$_ggmlBaseUrl/${model.fileName}',
      filename: model.fileName,
      directory: _whisperSubdir,
      baseDirectory: bd.BaseDirectory.applicationSupport,
      updates: bd.Updates.statusAndProgress,
      retries: 3,
      allowPause: true,
    );
    final status = await _downloadRunner(
      task: task,
      onProgress: (progress) {
        if (progress >= 0) onProgress?.call(progress);
      },
    );
    if (status != bd.TaskStatus.complete) {
      throw Exception('Download failed (${status.name})');
    }
  }

  Future<void> deleteDownload(String modelId) async {
    final file = File(await _modelFile(_model(modelId)));
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
    final model = _model(modelId);
    final dir = await _modelDir();
    // whisper_kit uses 'auto' to auto-detect the language AND transcribe; a
    // specific ISO code (e.g. 'de') forces that language. (Per the package docs.)
    final lang = (languageCode == null || languageCode.isEmpty)
        ? 'auto'
        : languageCode;
    final request = TranscribeRequest(
      audio: wavPath,
      language: lang,
      threads: threads,
      isTranslate: false,
    );
    final dynamic response = await _transcribeRunner(
      model: model.value,
      modelDir: dir,
      request: request,
    );
    final text = (response.text as String?)?.trim() ?? '';
    if (text.isEmpty) {
      // Surface a precise, on-screen diagnostic (no adb needed): the WAV size
      // shows whether conversion produced real audio, and the model size shows
      // whether the (large) weights downloaded completely.
      final wavKb = (await File(wavPath).length()) ~/ 1024;
      var modelMb = -1;
      try {
        modelMb =
            (await File(await _modelFile(model)).length()) ~/ (1024 * 1024);
      } catch (_) {}
      throw Exception(
        'Whisper returned 0 characters: model "${model.id}" (${modelMb}MB), '
        'language "$lang", WAV $wavKb KB, $threads threads.',
      );
    }
    return TranscriptionResult(text: text, segments: _segments(response, text));
  }

  /// Maps native timestamped segments to [TranscriptLine]s, tolerant to small
  /// API differences between package versions.
  List<TranscriptLine> _segments(dynamic response, String fullText) {
    final lines = _nativeSegments(response);
    if (lines.isEmpty && fullText.isNotEmpty) {
      lines.add(TranscriptLine(time: '0:00', text: fullText));
    }
    return lines;
  }

  List<TranscriptLine> _nativeSegments(dynamic response) {
    final lines = <TranscriptLine>[];
    try {
      final dynamic raw = response.segments;
      if (raw is! List) {
        return lines;
      }
      for (final dynamic segment in raw) {
        final line = _segmentLine(segment);
        if (line != null) {
          lines.add(line);
        }
      }
    } catch (_) {}
    return lines;
  }

  TranscriptLine? _segmentLine(dynamic segment) {
    final text = (segment.text as String?)?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    return TranscriptLine(
      time: formatDuration(_startSeconds(segment)),
      text: text,
    );
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

class _WhisperModelSpec {
  const _WhisperModelSpec(this.id, this.value);

  final String id;
  final WhisperModel value;

  String get fileName => 'ggml-$id.bin';
}

Future<Object?> _runWhisper({
  required WhisperModel model,
  required String modelDir,
  required TranscribeRequest request,
}) {
  return Whisper(
    model: model,
    modelDir: modelDir,
  ).transcribe(transcribeRequest: request);
}

Future<bd.TaskStatus> _runDownload({
  required bd.DownloadTask task,
  required void Function(double progress) onProgress,
}) async {
  final result = await bd.FileDownloader().download(
    task,
    onProgress: onProgress,
  );
  return result.status;
}

/// [TranscriptionService] backed by an on-device Whisper model.
class WhisperTranscriptionService implements TranscriptionService {
  WhisperTranscriptionService(this.modelId, {this.threads = 4});

  final String modelId;
  final int threads;

  @override
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    String? languageCode,
  }) => WhisperEngine.instance.transcribeWith(
    modelId,
    audioPath,
    languageCode: languageCode,
    threads: threads,
  );
}
