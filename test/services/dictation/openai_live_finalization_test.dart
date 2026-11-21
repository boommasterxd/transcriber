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
  _registerEmptyAudioTests();
  _registerFailureTests();
  _registerFinalizationCleanupTests();
  _registerCommitBoundaryTests();
}

void _registerLateTurnTests() {
  for (final timing in ['before', 'during']) {
    test(
      'a duplicate older final $timing finish preserves newer audio',
      () async {
        await _finishTurn('older', 'First.');
        _appendAudio();
        if (timing == 'before') await _completed('older', 'First.');
        var finished = false;
        final finishing = harness.client.finish().then((_) => finished = true);
        if (timing == 'during') {
          await _committed('newer');
          await _completed('older', 'First.');
        }
        await pumpEventQueue();

        expect(harness.socket.sent.last, contains('input_audio_buffer.commit'));
        expect(finished, isFalse);
        expect(_finals(), ['First.']);
        if (timing == 'before') await _committed('newer');
        expect(finished, isFalse);
        await _completed('newer', 'Second.');
        await finishing;

        expect(_finals(), ['First.', 'Second.']);
      },
    );
  }
}

void _registerEmptyAudioTests() {
  test(
    'empty audio does not send a commit or wait for transcription',
    () async {
      harness.client.addAudio(Uint8List(0));
      await harness.client.finish();

      expect(harness.socket.sent, hasLength(1));
      expect(_finals(), isEmpty);
    },
  );

  test('an empty final transcript finishes without inserting text', () async {
    await _finishTurn('silence', '   ');

    expect(_finals(), isEmpty);
    expect(harness.events.whereType<LiveTranscriptionFailure>(), isEmpty);
  });
}

void _registerFailureTests() {
  test('a provider error fails an outstanding finish', () async {
    _appendAudio();
    final finishing = harness.client.finish();
    final assertion = expectLater(
      finishing,
      throwsA(isA<LiveConnectionException>()),
    );
    _providerError('rate_limit');
    await assertion;

    expect(
      harness.events.whereType<LiveTranscriptionFailure>().single.code,
      'quota_exceeded',
    );
  });

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

void _registerFinalizationCleanupTests() {
  test('closing releases an outstanding finish with a failure', () async {
    _appendAudio();
    final assertion = expectLater(
      harness.client.finish(),
      throwsA(isA<LiveConnectionException>()),
    );
    await harness.client.close();
    await assertion;
  });

  test('a disconnected transport fails an outstanding finish', () async {
    _appendAudio();
    final assertion = expectLater(
      harness.client.finish(),
      throwsA(isA<LiveConnectionException>()),
    );
    await harness.socket.disconnect();
    await assertion;
    await harness.client.close();
  });
}

void _registerCommitBoundaryTests() {
  test('concurrent finish requests share one acknowledged commit', () async {
    _appendAudio();
    final finishing = harness.client.finish();

    expect(harness.client.finish(), same(finishing));
    await _committed('one');
    await _completed('one', 'Complete.');
    await finishing;

    expect(
      harness.socket.sent.where(
        (frame) => frame.contains('input_audio_buffer.commit'),
      ),
      hasLength(1),
    );
  });

  test('rejects malformed commit acknowledgements', () async {
    _appendAudio();
    final assertion = expectLater(
      harness.client.finish(),
      throwsA(isA<LiveConnectionException>()),
    );
    harness.socket.controller.add(
      jsonEncode({'type': 'input_audio_buffer.committed', 'item_id': 7}),
    );
    await pumpEventQueue();
    await assertion;

    expectProviderRejectedAndClosed(
      harness.client,
      harness.socket,
      harness.events,
    );
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

void _providerError(String code) => harness.socket.controller.add(
  jsonEncode({
    'type': 'error',
    'error': {'code': code},
  }),
);

List<String> _finals() => harness.events
    .whereType<LiveTranscriptionFinal>()
    .map((event) => event.text)
    .toList();
