import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transcriber/services/dictation/live_transcription.dart';
import 'package:transcriber/services/dictation/openai_live_transcription_client.dart';

import 'live_test_support.dart';
import 'openai_live_test_support.dart';

late LiveClientTestHarness<OpenAiLiveTranscriptionClient> harness;
FakeLiveSocket get socket => harness.socket;
CapturingConnector get connector => harness.connector;
OpenAiLiveTranscriptionClient get client => harness.client;
List<LiveTranscriptionEvent> get events => harness.events;

void main() {
  setUp(() => harness = createOpenAiHarness());

  tearDown(() => harness.close());

  _registerConnectionHandshakeTests();
  _registerProviderErrorTests();
  _registerMalformedResponseTests();
  _registerFrameLimitTests();
  _registerPartialLimitTests();
  _registerTranscriptionTests();
}

void _registerConnectionHandshakeTests() {
  test(
    'connects with header auth and configures realtime transcription',
    () async {
      final connecting = client.connect();
      await pumpEventQueue();

      expect(connector.uri!.queryParameters['model'], 'gpt-live-transcribe');
      expect(connector.uri.toString(), isNot(contains('secret-openai-key')));
      expect(connector.headers, {'Authorization': 'Bearer secret-openai-key'});
      final setup = jsonDecode(socket.sent.single) as Map<String, dynamic>;
      final input = setup['session']['audio']['input'] as Map<String, dynamic>;
      expect(input['format'], {'type': 'audio/pcm', 'rate': 24000});
      expect(input['transcription']['languages'], ['de']);
      expect(input['turn_detection'], isNull);
      expect(events.whereType<LiveTranscriptionReady>(), isEmpty);

      socket.controller.add(jsonEncode({'type': 'session.updated'}));
      await connecting;
      await pumpEventQueue();
      expect(events, contains(isA<LiveTranscriptionReady>()));
    },
  );
}

void _registerProviderErrorTests() {
  test('reports provider errors and unexpected disconnects', () async {
    await _connectOpenAiClient();
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
      'quota_exceeded',
    );
    expect(events.whereType<LiveTranscriptionDisconnected>(), hasLength(1));
  });

  test('reports a rejected setup before recording starts', () async {
    final connecting = client.connect();
    await pumpEventQueue();
    socket.controller.add(
      jsonEncode({
        'type': 'error',
        'error': {'code': 'invalid_api_key'},
      }),
    );

    await expectLater(
      connecting,
      throwsA(
        isA<LiveConnectionException>().having(
          (error) => error.code,
          'code',
          'authentication_failed',
        ),
      ),
    );
  });
}

void _registerMalformedResponseTests() {
  test('fails and closes on malformed JSON', () async {
    await _connectOpenAiClient();
    socket.controller.add('not json');
    await pumpEventQueue();

    expectProviderRejectedAndClosed(client, socket, events);
  });

  test('fails and closes on a malformed transcription delta', () async {
    await _connectOpenAiClient();

    socket.controller.add(
      jsonEncode({
        'type': 'conversation.item.input_audio_transcription.delta',
        'item_id': 'one',
        'delta': 5,
      }),
    );
    await pumpEventQueue();

    expectProviderRejectedAndClosed(client, socket, events);
  });
}

void _registerFrameLimitTests() {
  test('rejects and closes on a JSON frame above the byte limit', () async {
    await _connectOpenAiClient();

    socket.controller.add(oversizedLiveJsonFrame());
    await pumpEventQueue();

    expectProviderRejectedAndClosed(client, socket, events);
  });
}

void _registerPartialLimitTests() {
  test('bounds accumulated partial transcription text', () async {
    await _connectOpenAiClient();
    final firstDelta = List.filled(
      LiveTranscriptionLimits.maximumTranscriptCharacters,
      'x',
    ).join();
    socket.controller.add(
      jsonEncode({
        'type': 'conversation.item.input_audio_transcription.delta',
        'item_id': 'one',
        'delta': firstDelta,
      }),
    );
    await pumpEventQueue();
    socket.controller.add(
      jsonEncode({
        'type': 'conversation.item.input_audio_transcription.delta',
        'item_id': 'one',
        'delta': 'x',
      }),
    );
    await pumpEventQueue();

    expect(
      events.whereType<LiveTranscriptionPartial>().single.text,
      firstDelta,
    );
    expectProviderRejectedAndClosed(client, socket, events);
  });

  test('bounds the number of unfinished transcription items', () async {
    await _connectOpenAiClient();
    for (
      var index = 0;
      index < LiveTranscriptionLimits.maximumPartialItems + 1;
      index++
    ) {
      socket.controller.add(
        jsonEncode({
          'type': 'conversation.item.input_audio_transcription.delta',
          'item_id': 'item-$index',
          'delta': 'x',
        }),
      );
    }
    await pumpEventQueue();

    expect(
      events.whereType<LiveTranscriptionPartial>(),
      hasLength(LiveTranscriptionLimits.maximumPartialItems),
    );
    expectProviderRejectedAndClosed(client, socket, events);
  });
}

void _registerTranscriptionTests() {
  test('streams PCM and reconciles deltas with the final transcript', () async {
    await _connectOpenAiClient();
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
    final finishing = client.finish();
    socket.controller.add(
      jsonEncode({'type': 'input_audio_buffer.committed', 'item_id': 'one'}),
    );
    socket.controller.add(
      jsonEncode({
        'type': 'conversation.item.input_audio_transcription.completed',
        'item_id': 'one',
        'transcript': 'Hallo',
      }),
    );
    await finishing;

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
      await _connectOpenAiClient();
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

Future<void> _connectOpenAiClient() =>
    connectLiveClient(client, socket, {'type': 'session.updated'});
