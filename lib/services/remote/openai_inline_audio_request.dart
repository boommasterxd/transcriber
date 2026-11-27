import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../service_exceptions.dart';

/// Streams the validated audio range as Base64 inside a JSON request body.
final class OpenAiInlineAudioRequest extends http.BaseRequest {
  OpenAiInlineAudioRequest(
    Uri uri,
    this._file,
    this._audioLength, {
    required String modelId,
    required String prompt,
    required String format,
  }) : _prefix = utf8.encode(
         '{"model":${jsonEncode(modelId)},"modalities":["text"],'
         '"messages":[{"role":"user","content":['
         '{"type":"text","text":${jsonEncode(prompt)}},'
         '{"type":"input_audio","input_audio":'
         '{"format":${jsonEncode(format)},"data":"',
       ),
       super('POST', uri) {
    headers['Content-Type'] = 'application/json';
    final encodedAudioLength = ((_audioLength + 2) ~/ 3) * 4;
    contentLength = _prefix.length + encodedAudioLength + _suffix.length;
  }

  static final _suffix = utf8.encode('"}}]}]}');

  final File _file;
  final int _audioLength;
  final List<int> _prefix;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(_body());
  }

  Stream<List<int>> _body() async* {
    yield _prefix;
    var remaining = _audioLength;
    var readFailed = false;
    final audio = _file.openRead(0, _audioLength).map((chunk) {
      remaining -= chunk.length;
      return chunk;
    });
    // Forward the transport's subscription cancellation to the file stream.
    yield* base64.encoder.bind(audio).map(ascii.encode).handleError((Object _) {
      readFailed = true;
      throw const RemoteApiException('The audio file could not be read.');
    });
    if (readFailed) return;
    if (remaining != 0) {
      throw const RemoteApiException('The audio file changed during upload.');
    }
    yield _suffix;
  }
}
