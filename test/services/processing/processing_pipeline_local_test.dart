import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/data/models/processing_mode.dart';
import 'package:transcriber/services/processing/processing_pipeline.dart';
import 'package:transcriber/services/service_exceptions.dart';

import 'processing_test_support.dart';

void main() {
  group('ProcessingPipeline local boundaries', () {
    _registerTranscriptionGateTest();
    _registerSummaryGateTest();
    _registerSummaryOffGateTest();
    _registerForegroundTest();
    _registerLocalCoreTest();
    _registerForegroundErrorTest();
  });
}

void _registerTranscriptionGateTest() {
  test('rejects an unavailable local transcription model early', () async {
    final runtime = FakeProcessingRuntime()
      ..transcriptionModelAvailable = false;
    final metadata = FakeAudioMetadata();
    final pipeline = ProcessingPipeline(metadata: metadata, runtime: runtime);

    await expectLater(
      pipeline.process(
        testProcessingRequest((builder) {
          builder.asrMode = ProcessingMode.onDevice;
          builder.summarizeEnabled = false;
        }),
      ),
      throwsA(isA<ModelNotDownloadedException>()),
    );

    expect(runtime.transcriptionAvailabilityChecks, 1);
    expect(runtime.foregroundCalls, 0);
    expect(metadata.paths, isEmpty);
  });
}

void _registerSummaryGateTest() {
  test('rejects an unavailable enabled local summary model', () async {
    final runtime = FakeProcessingRuntime()..summaryModelAvailable = false;
    final pipeline = ProcessingPipeline(runtime: runtime);

    await expectLater(
      pipeline.process(
        testProcessingRequest(
          (builder) => builder.summaryMode = ProcessingMode.onDevice,
        ),
      ),
      throwsA(isA<ModelNotDownloadedException>()),
    );

    expect(runtime.summaryAvailabilityChecks, 1);
    expect(runtime.foregroundCalls, 0);
  });
}

void _registerSummaryOffGateTest() {
  test('ignores a local summary selection when summary is disabled', () async {
    final runtime = FakeProcessingRuntime()..summaryModelAvailable = false;
    final client = FakeRemoteApiClient();
    final pipeline = ProcessingPipeline(
      runtime: runtime,
      remoteClientBuilder: (_, _) => client,
    );

    final note = await pipeline.process(
      testProcessingRequest((builder) {
        builder.summaryMode = ProcessingMode.onDevice;
        builder.summarizeEnabled = false;
        builder.summaryApiKey = '';
      }),
    );

    expect(runtime.summaryAvailabilityChecks, 0);
    expect(runtime.foregroundCalls, 0);
    expect(client.transcriptionCalls, 1);
    expect(note.gist, isEmpty);
  });
}

void _registerForegroundTest() {
  test(
    'passes resolved duration and callbacks to the foreground runner',
    () async {
      final runtime = FakeProcessingRuntime();
      final metadata = FakeAudioMetadata(duration: 44);
      ProcessingRequest? forwarded;
      runtime.foreground = (request, callbacks) async {
        forwarded = request;
        callbacks.onStep?.call(ProcessingStep.transcribing);
        callbacks.onModelProgress?.call(0.25);
        return testTranscriptNote(durationSec: 44);
      };
      final pipeline = ProcessingPipeline(metadata: metadata, runtime: runtime);
      final steps = <ProcessingStep>[];
      final progress = <double>[];

      final note = await pipeline.process(
        testProcessingRequest((builder) {
          builder.asrMode = ProcessingMode.onDevice;
          builder.summarizeEnabled = false;
          builder.knownDurationSec = null;
        }),
        callbacks: ProcessingCallbacks(
          onStep: steps.add,
          onModelProgress: progress.add,
        ),
      );

      expect(forwarded?.input.knownDurationSec, 44);
      expect(metadata.paths, ['/audio/input.m4a']);
      expect(steps, [ProcessingStep.transcribing]);
      expect(progress, [0.25]);
      expect(note.durationSec, 44);
    },
  );
}

void _registerLocalCoreTest() {
  test('builds local services and uses deterministic note ports', () async {
    final runtime = FakeProcessingRuntime();
    final converter = FakeAudioConverter();
    final pipeline = ProcessingPipeline(converter: converter, runtime: runtime);
    final request = testProcessingRequest((builder) {
      builder.asrMode = ProcessingMode.onDevice;
      builder.summaryMode = ProcessingMode.onDevice;
      builder.language = AppLanguage.de;
    });

    final note = await pipeline.processCurrentIsolate(request);

    expect(converter.inputs, ['/audio/input.m4a']);
    expect(runtime.transcriptionService.paths, ['/audio/converted.wav']);
    expect(runtime.transcriptionService.languages, ['de']);
    expect(runtime.summarizationService.transcripts, ['Local transcript']);
    expect(runtime.summarizationService.germanValues, [isTrue]);
    expect(runtime.localTranscriptionBuilds, 1);
    expect(runtime.localSummaryBuilds, 1);
    expect(note.id, runtime.generatedId);
    expect(note.createdAt, runtime.clock);
    expect(note.title, 'Local title');
    expect(note.asrIsLocal, isTrue);
    expect(note.summaryIsLocal, isTrue);
  });
}

void _registerForegroundErrorTest() {
  test('propagates a foreground runner failure', () async {
    final runtime = FakeProcessingRuntime()
      ..foreground = (_, _) async =>
          throw const ProcessingException('foreground failed');
    final pipeline = ProcessingPipeline(runtime: runtime);

    await expectLater(
      pipeline.process(
        testProcessingRequest((builder) {
          builder.asrMode = ProcessingMode.onDevice;
          builder.summarizeEnabled = false;
        }),
      ),
      throwsA(
        isA<ProcessingException>().having(
          (error) => error.message,
          'message',
          'foreground failed',
        ),
      ),
    );
  });
}
