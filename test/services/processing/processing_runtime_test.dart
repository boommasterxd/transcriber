import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/services/processing/processing_pipeline.dart';
import 'package:transcriber/services/processing/processing_runtime.dart';
import 'package:transcriber/services/summarization/gemma_engine.dart';
import 'package:transcriber/services/transcription/whisper_engine.dart';

import 'processing_test_support.dart';

void main() {
  group('DefaultProcessingRuntime', () {
    test(
      'delegates foreground processing with the original arguments',
      () async {
        final request = testProcessingRequest();
        const callbacks = ProcessingCallbacks();
        late ProcessingRequest receivedRequest;
        late ProcessingCallbacks receivedCallbacks;
        final runtime = DefaultProcessingRuntime(
          foreground: (actualRequest, actualCallbacks) async {
            receivedRequest = actualRequest;
            receivedCallbacks = actualCallbacks;
            return testTranscriptNote();
          },
        );

        final note = await runtime.runForeground(request, callbacks);

        expect(note.id, 'note-id');
        expect(receivedRequest, same(request));
        expect(receivedCallbacks, same(callbacks));
      },
    );

    test('creates local services from the supplied settings', () {
      final settings = AppSettings.initial().copyWith(
        whisperThreads: 3,
        hfToken: 'test-token',
      );
      final runtime = _runtime();

      final transcription = runtime.createLocalTranscriptionService(settings);
      final summary = runtime.createLocalSummarizationService(
        settings,
        'Fallback',
      );

      expect(transcription, isA<WhisperTranscriptionService>());
      expect(
        (transcription as WhisperTranscriptionService).modelId,
        settings.whisperModelId,
      );
      expect(transcription.threads, 3);
      expect(summary, isA<GemmaSummarizationService>());
      expect(
        (summary as GemmaSummarizationService).modelId,
        settings.gemmaModelId,
      );
      expect(summary.fallbackTitle, 'Fallback');
      expect(summary.hfToken, 'test-token');
      expect(summary.backendId, settings.gemmaBackend.id);
    });

    test('provides a current timestamp and unique UUID values', () {
      final before = DateTime.now();
      final runtime = _runtime();

      final timestamp = runtime.now();
      final first = runtime.newId();
      final second = runtime.newId();

      expect(timestamp.isBefore(before), isFalse);
      expect(first, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(second, isNot(first));
    });

    test('deletes existing audio and tolerates a missing path', () async {
      final directory = await Directory.systemTemp.createTemp(
        'processing-runtime-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/audio.wav');
      await file.writeAsBytes([1, 2, 3]);
      final runtime = _runtime();

      await runtime.deleteAudio(file.path);
      await runtime.deleteAudio('${directory.path}/missing.wav');

      expect(await file.exists(), isFalse);
    });
  });
}

DefaultProcessingRuntime _runtime() =>
    DefaultProcessingRuntime(foreground: (_, _) async => testTranscriptNote());
