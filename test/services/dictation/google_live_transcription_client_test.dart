import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/dictation/google_live_transcription_client.dart';
import 'package:transcriber/services/dictation/live_transcription.dart';

import 'live_test_support.dart';

late LiveClientTestHarness<GoogleLiveTranscriptionClient> harness;
FakeLiveSocket get socket => harness.socket;
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

  _registerTranscriptionTests();
}

void _registerTranscriptionTests() {
  test('streams 16 kHz PCM and emits interim and final text', () async {
    await _connectGoogleClient();

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
    await _connectGoogleClient();

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

Future<void> _connectGoogleClient() =>
    connectLiveClient(client, socket, {'setupComplete': {}});
