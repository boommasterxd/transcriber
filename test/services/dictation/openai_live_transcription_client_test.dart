import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/dictation/live_transcription.dart';
import 'package:transcriber/services/dictation/openai_live_transcription_client.dart';

import 'live_test_support.dart';

late LiveClientTestHarness<OpenAiLiveTranscriptionClient> harness;
FakeLiveSocket get socket => harness.socket;
CapturingConnector get connector => harness.connector;
OpenAiLiveTranscriptionClient get client => harness.client;
List<LiveTranscriptionEvent> get events => harness.events;

void main() {
  setUp(() async {
    harness = LiveClientTestHarness.create(
      (connector) => OpenAiLiveTranscriptionClient(
        const LiveTranscriptionConfig(
          provider: RemoteProviderId.openai,
          apiKey: 'secret-openai-key',
          languageCode: 'de',
        ),
        connector: connector.call,
      ),
    );
  });

  tearDown(() => harness.close());

  _registerConnectionTests();
  _registerTranscriptionTests();
}

void _registerConnectionTests() {
  test(
    'connects with header auth and configures realtime transcription',
    () async {
      await client.connect();
      await pumpEventQueue();

      expect(connector.uri!.queryParameters['model'], 'gpt-live-transcribe');
      expect(connector.uri.toString(), isNot(contains('secret-openai-key')));
      expect(connector.headers, {'Authorization': 'Bearer secret-openai-key'});
      final setup = jsonDecode(socket.sent.single) as Map<String, dynamic>;
      final input = setup['session']['audio']['input'] as Map<String, dynamic>;
      expect(input['format'], {'type': 'audio/pcm', 'rate': 24000});
      expect(input['transcription']['languages'], ['de']);
      expect(input['turn_detection']['type'], 'server_vad');
      expect(events, contains(isA<LiveTranscriptionReady>()));
    },
  );

  test(
    'reports protocol errors, disconnects, and malformed messages safely',
    () async {
      await client.connect();
      socket.controller.add('not json');
      socket.controller.add([1, 2]);
      socket.controller.add(
        jsonEncode({
          'type': 'error',
          'error': {'code': 'rate_limit'},
        }),
      );
      await socket.controller.close();
      await pumpEventQueue();

      expect(
        events.whereType<LiveTranscriptionFailure>().single.code,
        'rate_limit',
      );
      expect(events.whereType<LiveTranscriptionDisconnected>(), hasLength(1));
    },
  );
}

void _registerTranscriptionTests() {
  test('streams PCM and reconciles deltas with the final transcript', () async {
    await client.connect();
    client.addAudio(Uint8List.fromList([1, 2, 3]));
    socket.controller.add(
      jsonEncode({
        'type': 'conversation.item.input_audio_transcription.delta',
        'item_id': 'one',
        'delta': 'Hal',
      }),
    );
    socket.controller.add(
      jsonEncode({
        'type': 'conversation.item.input_audio_transcription.delta',
        'item_id': 'one',
        'delta': 'lo',
      }),
    );
    socket.controller.add(
      jsonEncode({
        'type': 'conversation.item.input_audio_transcription.completed',
        'item_id': 'one',
        'transcript': 'Hallo',
      }),
    );
    await pumpEventQueue();

    final audio = jsonDecode(socket.sent[1]) as Map<String, dynamic>;
    expect(audio['type'], 'input_audio_buffer.append');
    expect(base64Decode(audio['audio'] as String), [1, 2, 3]);
    expect(
      events.whereType<LiveTranscriptionPartial>().map((event) => event.text),
      ['Hal', 'Hallo'],
    );
    expect(events.whereType<LiveTranscriptionFinal>().single.text, 'Hallo');
  });

  test(
    'commits pending audio on finish and ignores an empty-commit error',
    () async {
      await client.connect();
      client.addAudio(Uint8List.fromList([1, 2]));
      final finishing = client.finish();
      await pumpEventQueue();
      expect(jsonDecode(socket.sent.last)['type'], 'input_audio_buffer.commit');

      socket.controller.add(
        jsonEncode({
          'type': 'error',
          'error': {'code': 'input_audio_buffer_commit_empty'},
        }),
      );
      await finishing;
      expect(events.whereType<LiveTranscriptionFailure>(), isEmpty);
    },
  );
}
