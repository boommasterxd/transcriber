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
}
