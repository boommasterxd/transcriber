import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/services/processing/processing_pipeline.dart';
import 'package:transcriber/services/service_exceptions.dart';

import 'processing_test_support.dart';

void main() {
  group('ProcessingPipeline cloud orchestration', () {
    _registerCloudStagesTest();
    _registerSummaryOffTest();
    _registerCredentialTests();
    _registerDurationTest();
    _registerFallbackTest();
    _registerDeleteTests();
    _registerErrorTest();
  });
}

void _registerFallbackTest() {
  test('uses source-specific titles when summary is disabled', () async {
    final pipeline = ProcessingPipeline(
      runtime: FakeProcessingRuntime(),
      remoteClientBuilder: (_, _) => FakeRemoteApiClient(),
    );

    final recording = await pipeline.process(
      testProcessingRequest((builder) {
        builder.source = NoteSource.recording;
        builder.summarizeEnabled = false;
        builder.summaryApiKey = '';
      }),
    );
    final unnamedFile = await pipeline.process(
      testProcessingRequest((builder) {
        builder.audioPath = '/audio/';
        builder.summarizeEnabled = false;
        builder.summaryApiKey = '';
      }),
    );

    final strings = AppStrings.of(AppLanguage.en);
    expect(recording.title, strings.recordingLabel);
    expect(unnamedFile.title, strings.voiceNote);
  });
}

void _registerCloudStagesTest() {
  test('uses stage credentials and deterministic note metadata', () async {
    final client = FakeRemoteApiClient();
    final runtime = FakeProcessingRuntime();
    final metadata = FakeAudioMetadata();
    final builds = <({RemoteProviderId provider, String apiKey})>[];
    final pipeline = ProcessingPipeline(
      metadata: metadata,
      runtime: runtime,
      remoteClientBuilder: (provider, apiKey) {
        builds.add((provider: provider, apiKey: apiKey));
        return client;
      },
    );
    final steps = <ProcessingStep>[];

    final note = await pipeline.process(
      testProcessingRequest(),
      callbacks: ProcessingCallbacks(onStep: steps.add),
    );

    expect(steps, [ProcessingStep.transcribing, ProcessingStep.summarizing]);
    expect(builds, [
      (provider: RemoteProviderId.openai, apiKey: 'asr-key'),
      (provider: RemoteProviderId.openai, apiKey: 'summary-key'),
    ]);
    expect(client.transcriptionCalls, 1);
    expect(client.chatCalls, 1);
    expect(metadata.paths, isEmpty);
    expect(note.id, 'generated-id');
    expect(note.createdAt, runtime.clock);
    expect(note.title, 'Remote title');
    expect(note.durationSec, 12);
    expect(note.transcript.single.text, 'Transcript text');
  });
}

void _registerSummaryOffTest() {
  test('skips summary credentials, execution, and callback', () async {
    final client = FakeRemoteApiClient();
    final runtime = FakeProcessingRuntime();
    final apiKeys = <String>[];
    final pipeline = ProcessingPipeline(
      runtime: runtime,
      remoteClientBuilder: (_, apiKey) {
        apiKeys.add(apiKey);
        return client;
      },
    );
    final steps = <ProcessingStep>[];

    final note = await pipeline.process(
      testProcessingRequest((builder) {
        builder.summarizeEnabled = false;
        builder.summaryApiKey = '';
      }),
      callbacks: ProcessingCallbacks(onStep: steps.add),
    );

    expect(apiKeys, ['asr-key']);
    expect(steps, [ProcessingStep.transcribing]);
    expect(client.chatCalls, 0);
    expect(runtime.summaryAvailabilityChecks, 0);
    expect(note.title, 'input.m4a');
    expect(note.gist, isEmpty);
    expect(note.summaryIsLocal, isTrue);
  });
}

void _registerCredentialTests() {
  test('rejects a missing ASR credential before remote work', () async {
    await _expectMissingCredential((builder) => builder.asrApiKey = '');
  });

  test('rejects a missing enabled summary credential', () async {
    await _expectMissingCredential((builder) => builder.summaryApiKey = '');
  });
}

Future<void> _expectMissingCredential(
  void Function(TestProcessingRequestBuilder builder) configure,
) async {
  final client = FakeRemoteApiClient();
  final pipeline = ProcessingPipeline(
    runtime: FakeProcessingRuntime(),
    remoteClientBuilder: (_, _) => client,
  );

  await expectLater(
    pipeline.process(testProcessingRequest(configure)),
    throwsA(isA<MissingApiKeyException>()),
  );
  expect(client.transcriptionCalls, 0);
}

void _registerDurationTest() {
  test('reads a missing duration once before processing', () async {
    final metadata = FakeAudioMetadata(duration: 37);
    final pipeline = ProcessingPipeline(
      metadata: metadata,
      runtime: FakeProcessingRuntime(),
      remoteClientBuilder: (_, _) => FakeRemoteApiClient(),
    );

    final note = await pipeline.process(
      testProcessingRequest((builder) => builder.knownDurationSec = null),
    );

    expect(metadata.paths, ['/audio/input.m4a']);
    expect(note.durationSec, 37);
  });
}

void _registerDeleteTests() {
  test('deletes auto-delete audio and removes its note reference', () async {
    final (:runtime, :note) = await _processAutoDelete(failDelete: false);

    expect(runtime.deletedPaths, ['/audio/input.m4a']);
    expect(note.audioPath, isNull);
  });

  test('keeps a completed note when best-effort deletion fails', () async {
    final (:runtime, :note) = await _processAutoDelete(failDelete: true);

    expect(runtime.deletedPaths, ['/audio/input.m4a']);
    expect(note.id, 'generated-id');
    expect(note.audioPath, isNull);
  });
}

Future<({FakeProcessingRuntime runtime, TranscriptNote note})>
_processAutoDelete({required bool failDelete}) async {
  final runtime = FakeProcessingRuntime()..failDelete = failDelete;
  final pipeline = ProcessingPipeline(
    runtime: runtime,
    remoteClientBuilder: (_, _) => FakeRemoteApiClient(),
  );
  final note = await pipeline.process(
    testProcessingRequest((builder) => builder.autoDeleteAudio = true),
  );
  return (runtime: runtime, note: note);
}

void _registerErrorTest() {
  test('propagates a transcription failure without summarizing', () async {
    final client = FakeRemoteApiClient()
      ..transcriptionError = StateError('transcription failed');
    final pipeline = ProcessingPipeline(
      runtime: FakeProcessingRuntime(),
      remoteClientBuilder: (_, _) => client,
    );

    await expectLater(
      pipeline.process(testProcessingRequest()),
      throwsA(isA<StateError>()),
    );
    expect(client.chatCalls, 0);
  });
}
