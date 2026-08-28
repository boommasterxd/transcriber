import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/processing/processing_foreground_event.dart';
import 'package:transcriber/services/processing/processing_request.dart';
import 'package:transcriber/services/service_exceptions.dart';

import 'processing_test_support.dart';

void main() {
  group('decodeProcessingForegroundEvent', () {
    _registerStepDecoderTests();
    _registerProgressDecoderTests();
    _registerTerminalDecoderTests();
  });
  group('ProcessingForegroundSession', () {
    _registerSessionCallbackTest();
    _registerMalformedTerminalTest();
    _registerDuplicateEventTest();
    _registerCallbackFailureTest();
  });
}

void _registerStepDecoderTests() {
  test('decodes known steps and ignores unknown shapes', () {
    final event = decodeProcessingForegroundEvent({
      'type': 'step',
      'step': 'summarizing',
    });

    expect(event, isA<ProcessingForegroundStepEvent>());
    expect(
      (event as ProcessingForegroundStepEvent).step,
      ProcessingStep.summarizing,
    );
    expect(
      decodeProcessingForegroundEvent({'type': 'step', 'step': 'unknown'}),
      isNull,
    );
    expect(decodeProcessingForegroundEvent('not-a-map'), isNull);
    expect(decodeProcessingForegroundEvent({'type': 'unknown'}), isNull);
  });
}

void _registerProgressDecoderTests() {
  test('accepts bounded finite progress and ignores malformed values', () {
    final event = decodeProcessingForegroundEvent({
      'type': 'modelProgress',
      'value': 0.5,
    });

    expect(event, isA<ProcessingForegroundProgressEvent>());
    expect((event as ProcessingForegroundProgressEvent).progress, 0.5);
    expect(
      decodeProcessingForegroundEvent({'type': 'modelProgress', 'value': 0}),
      isA<ProcessingForegroundProgressEvent>(),
    );
    expect(
      decodeProcessingForegroundEvent({'type': 'modelProgress', 'value': 1}),
      isA<ProcessingForegroundProgressEvent>(),
    );
    for (final value in [-0.1, 1.1, double.nan, double.infinity, '0.5']) {
      expect(
        decodeProcessingForegroundEvent({
          'type': 'modelProgress',
          'value': value,
        }),
        isNull,
      );
    }
  });
}

void _registerTerminalDecoderTests() {
  test('decodes a valid note and explicit error', () {
    final note = testTranscriptNote();
    final done = decodeProcessingForegroundEvent({
      'type': 'done',
      'note': jsonEncode(note.toJson()),
    });
    final error = decodeProcessingForegroundEvent({
      'type': 'error',
      'error': 'model failed',
    });

    expect((done as ProcessingForegroundDoneEvent).note.id, note.id);
    expect(
      (error as ProcessingForegroundErrorEvent).error.message,
      'model failed',
    );
  });

  test('turns malformed terminal messages into defined errors', () {
    for (final value in [null, 7, 'not-json', '[]', '{}', '{"id":""}']) {
      final event = decodeProcessingForegroundEvent({
        'type': 'done',
        'note': value,
      });
      expect(event, isA<ProcessingForegroundErrorEvent>());
      expect(
        (event as ProcessingForegroundErrorEvent).error.message,
        'Invalid processing result received',
      );
    }
    final error = decodeProcessingForegroundEvent({
      'type': 'error',
      'error': null,
    });
    expect(
      (error as ProcessingForegroundErrorEvent).error.message,
      'Processing failed',
    );
  });
}

void _registerSessionCallbackTest() {
  test('delivers callbacks and completes with the first valid note', () async {
    final steps = <ProcessingStep>[];
    final progress = <double>[];
    var summaryNotifications = 0;
    final session = ProcessingForegroundSession(
      callbacks: ProcessingCallbacks(
        onStep: steps.add,
        onModelProgress: progress.add,
      ),
      onSummaryStep: () => summaryNotifications++,
    );

    session.onData({'type': 'step', 'step': 'summarizing'});
    session.onData({'type': 'modelProgress', 'value': 0.75});
    session.onData(_doneData(testTranscriptNote()));
    final note = await session.result;

    expect(steps, [ProcessingStep.summarizing]);
    expect(progress, [0.75]);
    expect(summaryNotifications, 1);
    expect(note.id, 'note-id');
  });
}

void _registerMalformedTerminalTest() {
  test('completes with an error for malformed done and error events', () async {
    final malformedDone = ProcessingForegroundSession();
    final doneExpectation = expectLater(
      malformedDone.result,
      throwsA(
        isA<ProcessingException>().having(
          (error) => error.message,
          'message',
          'Invalid processing result received',
        ),
      ),
    );
    malformedDone.onData({'type': 'done', 'note': '{'});
    await doneExpectation;

    final malformedError = ProcessingForegroundSession();
    final errorExpectation = expectLater(
      malformedError.result,
      throwsA(isA<ProcessingException>()),
    );
    malformedError.onData({'type': 'error'});
    await errorExpectation;
  });
}

void _registerDuplicateEventTest() {
  test('ignores duplicate and late events after completion', () async {
    final steps = <ProcessingStep>[];
    final progress = <double>[];
    final session = ProcessingForegroundSession(
      callbacks: ProcessingCallbacks(
        onStep: steps.add,
        onModelProgress: progress.add,
      ),
    );

    session.onData({'type': 'step', 'step': 'unknown'});
    session.onData({'type': 'modelProgress', 'value': double.nan});
    session.onData(_doneData(testTranscriptNote(id: 'first')));
    session.onData({'type': 'error', 'error': 'late error'});
    session.onData({'type': 'step', 'step': 'transcribing'});
    session.onData({'type': 'modelProgress', 'value': 0.5});
    session.onData(_doneData(testTranscriptNote(id: 'second')));

    expect((await session.result).id, 'first');
    expect(steps, isEmpty);
    expect(progress, isEmpty);
  });
}

void _registerCallbackFailureTest() {
  test('observer failures do not break terminal delivery', () async {
    final session = ProcessingForegroundSession(
      callbacks: ProcessingCallbacks(
        onStep: (_) => throw StateError('step callback failed'),
        onModelProgress: (_) => throw StateError('progress callback failed'),
      ),
      onSummaryStep: () => throw StateError('notification failed'),
    );

    expect(
      () => session.onData({'type': 'step', 'step': 'summarizing'}),
      returnsNormally,
    );
    expect(
      () => session.onData({'type': 'modelProgress', 'value': 0.5}),
      returnsNormally,
    );
    session.onData(_doneData(testTranscriptNote()));

    expect((await session.result).id, 'note-id');
  });
}

Map<String, Object> _doneData(dynamic note) => {
  'type': 'done',
  'note': jsonEncode(note.toJson()),
};
