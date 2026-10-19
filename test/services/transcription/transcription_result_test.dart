import 'package:test/test.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/services/transcription/transcription_service.dart';

void main() {
  group('TranscriptionResult', () {
    test('reports that an empty segment list has no segments', () {
      const result = TranscriptionResult(text: 'Transcript', segments: []);

      expect(result.text, 'Transcript');
      expect(result.segments, isEmpty);
      expect(result.hasSegments, isFalse);
    });

    test('preserves transcript lines and reports their presence', () {
      const segments = [
        TranscriptLine(text: 'First'),
        TranscriptLine(text: 'Second'),
      ];
      const result = TranscriptionResult(
        text: 'First Second',
        segments: segments,
      );

      expect(result.hasSegments, isTrue);
      expect(result.segments, same(segments));
      expect(result.segments.first.text, 'First');
      expect(result.segments.last.text, 'Second');
    });
  });

  test(
    'TranscriptionService accepts automatic and explicit languages',
    () async {
      final service = _RecordingTranscriptionService();

      await service.transcribe('/audio/automatic.wav');
      await service.transcribe('/audio/german.wav', languageCode: 'de');

      expect(service.calls, [
        const _TranscriptionCall('/audio/automatic.wav', null),
        const _TranscriptionCall('/audio/german.wav', 'de'),
      ]);
    },
  );
}

final class _RecordingTranscriptionService implements TranscriptionService {
  final calls = <_TranscriptionCall>[];

  @override
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    String? languageCode,
  }) async {
    calls.add(_TranscriptionCall(audioPath, languageCode));
    return const TranscriptionResult(text: '', segments: []);
  }
}

final class _TranscriptionCall {
  const _TranscriptionCall(this.audioPath, this.languageCode);

  final String audioPath;
  final String? languageCode;

  @override
  bool operator ==(Object other) =>
      other is _TranscriptionCall &&
      other.audioPath == audioPath &&
      other.languageCode == languageCode;

  @override
  int get hashCode => Object.hash(audioPath, languageCode);
}
