import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/dictation/google_live_transcription_client.dart';
import 'package:transcriber/services/dictation/live_transcription.dart';

import 'live_test_support.dart';

late LiveClientTestHarness<GoogleLiveTranscriptionClient> harness;
FakeLiveSocket get socket => harness.socket;
CapturingConnector get connector => harness.connector;
GoogleLiveTranscriptionClient get client => harness.client;
List<LiveTranscriptionEvent> get events => harness.events;

void main() {
  setUp(() async {
    harness = LiveClientTestHarness.create(
      (connector) => GoogleLiveTranscriptionClient(
        const LiveTranscriptionConfig(
          provider: RemoteProviderId.google,
          apiKey: 'secret-google-key',
          languageCode: null,
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
  test('authenticates in a header and waits for setup completion', () async {
    final connecting = client.connect();
    await pumpEventQueue();

    expect(connector.uri.toString(), isNot(contains('secret-google-key')));
    expect(connector.headers, {'x-goog-api-key': 'secret-google-key'});
    final setup = jsonDecode(socket.sent.single) as Map<String, dynamic>;
    expect(setup['setup']['model'], 'models/gemini-3.5-transcribe-live');
    expect(setup['setup']['inputAudioTranscription']['languageCodes'], isEmpty);

    socket.controller.add(jsonEncode({'setupComplete': {}}));
    await connecting;
    await pumpEventQueue();
    expect(events, contains(isA<LiveTranscriptionReady>()));
  });

  test('ignores malformed and unrelated server messages', () async {
    final connecting = client.connect();
    await pumpEventQueue();
    socket.controller.add(jsonEncode({'setupComplete': {}}));
    await connecting;
    socket.controller.add('invalid');
    socket.controller.add(jsonEncode({'serverContent': 'wrong'}));
    socket.controller.add(jsonEncode({'other': true}));
    await pumpEventQueue();

    expect(events.whereType<LiveTranscriptionPartial>(), isEmpty);
    expect(events.whereType<LiveTranscriptionFinal>(), isEmpty);
  });

  test('classifies a rejected setup without waiting for timeout', () async {
    final connecting = client.connect();
    await pumpEventQueue();
    await socket.disconnect(
      code: 1007,
      reason: 'API key not valid. Please pass a valid API key.',
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

void _registerTranscriptionTests() {
  test('streams 16 kHz PCM and emits interim and final text', () async {
    final connecting = client.connect();
    await pumpEventQueue();
    socket.controller.add(jsonEncode({'setupComplete': {}}));
    await connecting;

    client.addAudio(Uint8List.fromList([4, 5, 6]));
    socket.controller.add(
      jsonEncode({
        'serverContent': {
          'interimInputTranscription': {'text': 'Guten'},
        },
      }),
    );
    socket.controller.add(
      jsonEncode({
        'serverContent': {
          'inputTranscription': {'text': 'Guten Tag'},
        },
      }),
    );
    await pumpEventQueue();

    final audio = jsonDecode(socket.sent[1]) as Map<String, dynamic>;
    expect(audio['realtimeInput']['audio']['mimeType'], 'audio/pcm;rate=16000');
    expect(base64Decode(audio['realtimeInput']['audio']['data'] as String), [
      4,
      5,
      6,
    ]);
    expect(events.whereType<LiveTranscriptionPartial>().single.text, 'Guten');
    expect(events.whereType<LiveTranscriptionFinal>().single.text, 'Guten Tag');
  });

  test('signals stream end and completes when the server finalizes', () async {
    final connecting = client.connect();
    await pumpEventQueue();
    socket.controller.add(jsonEncode({'setupComplete': {}}));
    await connecting;

    final finishing = client.finish();
    await pumpEventQueue();
    expect(jsonDecode(socket.sent.last), {
      'realtimeInput': {'audioStreamEnd': true},
    });
    socket.controller.add(
      jsonEncode({
        'serverContent': {'turnComplete': true},
      }),
    );
    await finishing;
  });
}
