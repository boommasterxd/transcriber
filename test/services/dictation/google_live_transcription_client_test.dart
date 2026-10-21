import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/dictation/google_live_transcription_client.dart';
import 'package:transcriber/services/dictation/live_socket.dart';
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
  _registerConnectionLifecycleTests();
  _registerTranscriptionTests();
}

void _registerConnectionTests() {
  _registerSetupTests();
  _registerMessageValidationTests();
  _registerRejectedSetupTests();
}

void _registerSetupTests() {
  test('authenticates in a header and waits for setup completion', () async {
    final connecting = client.connect();
    await pumpEventQueue();

    expect(connector.uri.toString(), isNot(contains('secret-google-key')));
    expect(connector.headers, {'x-goog-api-key': 'secret-google-key'});
    final setup = jsonDecode(socket.sent.single) as Map<String, dynamic>;
    expect(setup['setup']['model'], 'models/gemini-3.5-transcribe-live');
    expect(setup['setup']['inputAudioTranscription']['languageCodes'], isEmpty);
    expect(setup['setup']['inputAudioTranscription']['mode'], 'SMART');

    socket.controller.add(jsonEncode({'setupComplete': {}}));
    await connecting;
    await pumpEventQueue();
    expect(events, contains(isA<LiveTranscriptionReady>()));
  });

  test('accepts setup completion delivered as a binary frame', () async {
    final connecting = client.connect();
    await pumpEventQueue();

    socket.controller.add(encodeLiveJsonFrame({'setupComplete': {}}));

    await connecting;
    expect(events, contains(isA<LiveTranscriptionReady>()));
  });
}

void _registerMessageValidationTests() {
  test('ignores unrelated server messages', () async {
    await _connectGoogleClient();
    socket.controller.add(jsonEncode({'other': true}));
    await pumpEventQueue();

    expect(events.whereType<LiveTranscriptionPartial>(), isEmpty);
    expect(events.whereType<LiveTranscriptionFinal>(), isEmpty);
    expect(events.whereType<LiveTranscriptionFailure>(), isEmpty);
    expect(client.isClosed, isFalse);
  });

  test('fails and closes on malformed JSON', () async {
    await _connectGoogleClient();
    socket.controller.add('invalid');
    await pumpEventQueue();

    expectProviderRejectedAndClosed(client, socket, events);
  });

  test('fails and closes on a malformed transcription text field', () async {
    await _connectGoogleClient();

    socket.controller.add(
      jsonEncode({
        'serverContent': {
          'interimInputTranscription': {'text': 5},
        },
      }),
    );
    await pumpEventQueue();

    expectProviderRejectedAndClosed(client, socket, events);
  });

  test('rejects and closes on an oversized binary frame', () async {
    await _connectGoogleClient();

    socket.controller.add(encodeLiveTextFrame(oversizedLiveJsonFrame()));
    await pumpEventQueue();

    expectProviderRejectedAndClosed(client, socket, events);
  });
}

void _registerRejectedSetupTests() {
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

void _registerConnectionLifecycleTests() {
  test(
    'bounds the socket handshake as part of the connection timeout',
    () async {
      final pendingSocket = Completer<LiveSocket>();
      final stalledClient = _googleClient(
        (_, _) => pendingSocket.future,
        connectionTimeout: const Duration(milliseconds: 20),
      );

      await _expectConnectionTimeout(stalledClient);
      await stalledClient.close();
    },
  );

  test('closes a socket that arrives after its attempt timed out', () async {
    final pendingSocket = Completer<LiveSocket>();
    final lateSocket = FakeLiveSocket();
    final stalledClient = _googleClient(
      (_, _) => pendingSocket.future,
      connectionTimeout: const Duration(milliseconds: 20),
    );

    await _expectConnectionTimeout(stalledClient);
    pendingSocket.complete(lateSocket);
    await pumpEventQueue();

    expect(lateSocket.closed, isTrue);
    expect(lateSocket.sent, isEmpty);
    await stalledClient.close();
  });

  test('closing cancels an outstanding setup immediately', () async {
    final openSocket = FakeLiveSocket();
    final pendingClient = _googleClient((_, _) async => openSocket);
    final connecting = pendingClient.connect();
    await pumpEventQueue();
    final cancelled = expectLater(
      connecting,
      throwsA(_connectionError('connection_cancelled')),
    );

    await pendingClient.close();

    await cancelled;
    expect(openSocket.closeCount, 1);
  });

  test('bounds a stalled socket shutdown', () async {
    final openSocket = FakeLiveSocket();
    final closeGate = Completer<void>();
    openSocket.closeGate = closeGate;
    final pendingClient = _googleClient((_, _) async => openSocket);
    final connecting = pendingClient.connect();
    await pumpEventQueue();
    openSocket.controller.add(jsonEncode({'setupComplete': {}}));
    await connecting;

    await pendingClient.close();

    expect(openSocket.closeCount, 1);
    closeGate.complete();
  });
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

  test('decodes transcription delivered as a binary frame', () async {
    await _connectGoogleClient();

    socket.controller.add(
      encodeLiveJsonFrame({
        'serverContent': {
          'inputTranscription': {'text': 'Binary text'},
        },
      }),
    );
    await pumpEventQueue();

    expect(
      events.whereType<LiveTranscriptionFinal>().single.text,
      'Binary text',
    );
  });
}

Future<void> _connectGoogleClient() =>
    connectLiveClient(client, socket, {'setupComplete': {}});

GoogleLiveTranscriptionClient _googleClient(
  LiveSocketConnector connector, {
  Duration connectionTimeout = const Duration(seconds: 10),
}) => GoogleLiveTranscriptionClient(
  const LiveTranscriptionConfig(
    provider: RemoteProviderId.google,
    apiKey: 'test-key',
    languageCode: null,
  ),
  connector: connector,
  connectionTimeout: connectionTimeout,
  closeTimeout: const Duration(milliseconds: 20),
);

Matcher _connectionError(String code) =>
    isA<LiveConnectionException>().having((error) => error.code, 'code', code);

Future<void> _expectConnectionTimeout(
  GoogleLiveTranscriptionClient stalledClient,
) => expectLater(
  stalledClient.connect(),
  throwsA(_connectionError('connection_timeout')),
);
