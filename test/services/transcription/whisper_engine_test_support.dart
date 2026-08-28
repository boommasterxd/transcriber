part of 'whisper_engine_test.dart';

final class _TranscribeHarness {
  _TranscribeHarness(this.response, {this.error});

  final Object? response;
  final Object? error;
  WhisperModel? model;
  String? modelDir;
  TranscribeRequest? request;

  Future<Object?> call({
    required WhisperModel model,
    required String modelDir,
    required TranscribeRequest request,
  }) async {
    this.model = model;
    this.modelDir = modelDir;
    this.request = request;
    if (error != null) throw error!;
    return response;
  }
}

final class _DownloadHarness {
  _DownloadHarness(this.status);

  final bd.TaskStatus status;
  bd.DownloadTask? task;

  Future<bd.TaskStatus> call({
    required bd.DownloadTask task,
    required void Function(double progress) onProgress,
  }) async {
    this.task = task;
    onProgress(-1);
    onProgress(0.25);
    onProgress(1);
    return status;
  }
}

final class _FakeResponse {
  const _FakeResponse(this.text, this.segments);

  final String? text;
  final Object? segments;
}

final class _FakeSegment {
  const _FakeSegment(this.text, this.fromTs);

  final String? text;
  final Object? fromTs;
}

Future<void> _writeSizedFile(File file, int bytes) async {
  final handle = await file.open(mode: FileMode.write);
  try {
    await handle.truncate(bytes);
  } finally {
    await handle.close();
  }
}
