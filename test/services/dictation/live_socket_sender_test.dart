import 'dart:async';

import 'package:test/test.dart';
import 'package:transcriber/services/dictation/live_socket_sender.dart';

void main() {
  _registerOrderingTest();
  _registerBufferLimitTests();
  _registerFailureTests();
  _registerShutdownTest();
}

void _registerOrderingTest() {
  test(
    'serializes audio and finalization while the transport is paused',
    () async {
      final firstWrite = Completer<void>();
      final sent = <String>[];
      final sender = LiveSocketSender(
        write: (message) async {
          sent.add(message);
          if (sent.length == 1) await firstWrite.future;
        },
        onFailure: () => fail('Writable transport must not fail'),
      );
      addTearDown(sender.close);
      sender
        ..add('audio one')
        ..add('audio two')
        ..add('finish');
      expect(sent, ['audio one']);

      firstWrite.complete();
      await pumpEventQueue();

      expect(sent, ['audio one', 'audio two', 'finish']);
    },
  );
}

void _registerBufferLimitTests() {
  test('counts in-flight UTF-8 bytes and fails once when full', () async {
    final firstWrite = Completer<void>();
    final sent = <String>[];
    var failures = 0;
    final sender = LiveSocketSender(
      maximumPendingBytes: 6,
      write: (message) async {
        sent.add(message);
        await firstWrite.future;
      },
      onFailure: () => failures++,
    );
    sender
      ..add('éé')
      ..add('ab');
    expect(failures, 0);
    sender
      ..add('c')
      ..add('ignored');

    expect(failures, 1);
    firstWrite.complete();
    await pumpEventQueue();
    expect(sent, ['éé']);
  });

  test('rejects one oversized message before sending it', () async {
    final sent = <String>[];
    var failures = 0;
    final sender = LiveSocketSender(
      maximumPendingBytes: 3,
      write: (message) async => sent.add(message),
      onFailure: () => failures++,
    );
    sender.add('four');

    expect(failures, 1);
    expect(sent, isEmpty);
  });
}

void _registerFailureTests() {
  test('a stalled write expires and never replays queued audio', () async {
    final writeGate = Completer<void>();
    final failed = Completer<void>();
    final sent = <String>[];
    final sender = LiveSocketSender(
      writeTimeout: const Duration(milliseconds: 20),
      write: (message) async {
        sent.add(message);
        await writeGate.future;
      },
      onFailure: failed.complete,
    );
    sender
      ..add('audio')
      ..add('queued');

    await failed.future;
    writeGate.complete();
    await pumpEventQueue();
    sender.add('late');
    expect(sent, ['audio']);
  });

  test('transport failures stop subsequent sends', () async {
    final failed = Completer<void>();
    final sent = <String>[];
    final sender = LiveSocketSender(
      write: (message) async {
        sent.add(message);
        throw StateError('Synthetic transport failure');
      },
      onFailure: failed.complete,
    );
    sender
      ..add('audio')
      ..add('queued');

    await failed.future;
    sender.add('late');
    expect(sent, ['audio']);
  });
}

void _registerShutdownTest() {
  test('closing drops pending audio without reporting a failure', () async {
    final writeGate = Completer<void>();
    final sent = <String>[];
    final sender = LiveSocketSender(
      write: (message) async {
        sent.add(message);
        await writeGate.future;
      },
      onFailure: () => fail('Explicit shutdown must not report a failure'),
    );
    sender
      ..add('audio')
      ..add('queued')
      ..close()
      ..add('late');
    writeGate.complete();
    await pumpEventQueue();

    expect(sent, ['audio']);
  });
}
