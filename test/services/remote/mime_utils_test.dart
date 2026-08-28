import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/remote/mime_utils.dart';

void main() {
  test('maps supported audio extensions case-insensitively', () {
    const expected = {
      'clip.wav': 'audio/wav',
      'clip.MP3': 'audio/mpeg',
      'clip.mpeg': 'audio/mpeg',
      'clip.mpga': 'audio/mpeg',
      'clip.m4a': 'audio/mp4',
      'clip.mp4': 'audio/mp4',
      'clip.aac': 'audio/aac',
      'clip.ogg': 'audio/ogg',
      'clip.opus': 'audio/opus',
      'clip.flac': 'audio/flac',
      'clip.webm': 'audio/webm',
    };

    for (final entry in expected.entries) {
      expect(audioMimeType(entry.key), entry.value, reason: entry.key);
    }
  });

  test('uses an opaque fallback for missing and unknown extensions', () {
    expect(audioMimeType('/tmp/audio'), 'application/octet-stream');
    expect(audioMimeType('/tmp/audio.bin'), 'application/octet-stream');
  });
}
