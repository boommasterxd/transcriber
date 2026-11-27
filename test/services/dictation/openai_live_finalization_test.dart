import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transcriber/services/dictation/live_transcription.dart';
import 'package:transcriber/services/dictation/openai_live_transcription_client.dart';

import 'live_test_support.dart';
import 'openai_live_test_support.dart';

late LiveClientTestHarness<OpenAiLiveTranscriptionClient> harness;

void main() {
  setUp(() async {
    harness = createOpenAiHarness();
    await connectLiveClient(harness.client, harness.socket, {
      'type': 'session.updated',
    });
  });
  tearDown(() => harness.close());

  _registerLateTurnTests();
  test(
    'a missing final response fails within the configured timeout',
    () async {
      await harness.close();
      harness = createOpenAiHarness(finalizationTimeout: Duration.zero);
      await connectLiveClient(harness.client, harness.socket, {
        'type': 'session.updated',
      });
      _appendAudio();

      await expectLater(
        harness.client.finish(),
        throwsA(isA<TimeoutException>()),
      );
    },
  );
}

void _registerLateTurnTests() {
  test('a duplicate older final cannot finish a newer audio turn', () async {
    expect(
      harness.connector.uri,
      Uri.parse('wss://api.openai.com/v1/realtime?intent=transcription'),
    );
    expect(jsonDecode(harness.socket.sent.first), {
      'type': 'session.update',
      'session': {
        'type': 'transcription',
        'audio': {
          'input': {
            'format': {'type': 'audio/pcm', 'rate': 24000},
            'transcription': {
              'model': 'gpt-live-transcribe',
              'delay': 'low',
              'languages': ['de'],
            },
            'turn_detection': null,
          },
        },
      },
    });
    await _finishTurn('older', 'First.');
    _appendAudio();
    var finished = false;
    final finishing = harness.client.finish().then((_) => finished = true);
    await _committed('newer');
    await _completed('older', 'First.');

    expect(harness.socket.sent.last, contains('input_audio_buffer.commit'));
    expect(finished, isFalse);
    expect(_finals(), ['First.']);
    await _completed('newer', 'Second.');
    await finishing;

    expect(_finals(), ['First.', 'Second.']);
  });
}

Future<void> _finishTurn(String itemId, String transcript) async {
  _appendAudio();
  final finishing = harness.client.finish();
  await _committed(itemId);
  await _completed(itemId, transcript);
  await finishing;
}

void _appendAudio() => harness.client.addAudio(Uint8List.fromList([1, 2]));

Future<void> _committed(String itemId) async {
  harness.socket.controller.add(
    jsonEncode({'type': 'input_audio_buffer.committed', 'item_id': itemId}),
  );
  await pumpEventQueue();
}

Future<void> _completed(String itemId, String transcript) async {
  harness.socket.controller.add(
    jsonEncode({
      'type': 'conversation.item.input_audio_transcription.completed',
      'item_id': itemId,
      'transcript': transcript,
    }),
  );
  await pumpEventQueue();
}

List<String> _finals() => harness.events
    .whereType<LiveTranscriptionFinal>()
    .map((event) => event.text)
    .toList();
