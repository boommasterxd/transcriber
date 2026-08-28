import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Listens for audio files shared into the app from other apps (WhatsApp, voice
/// recorders, file managers, …) via the Android share sheet.
class ShareIntentService {
  ShareIntentService();

  static const _audioExtensions = {
    '.wav',
    '.mp3',
    '.m4a',
    '.mp4',
    '.ogg',
    '.flac',
    '.webm',
    '.mpeg',
    '.mpga',
  };

  StreamSubscription<List<SharedMediaFile>>? _sub;

  bool _isAudio(SharedMediaFile f) {
    if (f.type == SharedMediaType.text || f.type == SharedMediaType.url) {
      return false;
    }
    return _audioExtensions.contains(p.extension(f.path).toLowerCase());
  }

  List<String> _audioPaths(List<SharedMediaFile> files) =>
      files.where(_isAudio).map((f) => f.path).toList();

  /// Returns the audio file shared while the app was closed (cold start), if any.
  Future<String?> initialSharedAudio() async {
    final files = await ReceiveSharingIntent.instance.getInitialMedia();
    final paths = _audioPaths(files);
    ReceiveSharingIntent.instance.reset();
    return paths.isEmpty ? null : paths.first;
  }

  /// Emits audio file paths shared while the app is running (warm start).
  void listen(void Function(String path) onAudio) {
    _sub = ReceiveSharingIntent.instance.getMediaStream().listen((files) {
      for (final path in _audioPaths(files)) {
        onAudio(path);
      }
      ReceiveSharingIntent.instance.reset();
    });
  }

  void dispose() => _sub?.cancel();
}
