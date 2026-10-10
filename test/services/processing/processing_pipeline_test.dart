import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/services/processing/processing_pipeline.dart';
import 'package:transcriber/services/service_exceptions.dart';
import 'package:transcriber/services/storage/managed_audio_file.dart';

import 'processing_test_support.dart';

typedef ProviderRun = ({
  ManagedAudioFile audio,
  RecordingClientFactory clients,
  TranscriptNote note,
  List<ProcessingStep> steps,
});

void main() {
  final fixture = ProcessingFileFixture();

  setUp(fixture.setUp);
  tearDown(fixture.tearDown);

  _registerProviderTests(fixture);
  _registerValidationTests(fixture);
  _registerAudioLifecycleTests(fixture);
}

void _registerProviderTests(ProcessingFileFixture fixture) {
  group('ProcessingPipeline provider orchestration', () {
    _registerProviderCombinations(fixture);
    _registerSummaryDisabledTest(fixture);
  });
}

void _registerProviderCombinations(ProcessingFileFixture fixture) {
  for (final asr in RemoteProviderId.values) {
    _registerSummaryCombinations(fixture, asr);
  }
}

void _registerSummaryCombinations(
  ProcessingFileFixture fixture,
  RemoteProviderId asr,
) {
  for (final summary in RemoteProviderId.values) {
    _registerProviderCombinationTest(fixture, asr, summary);
  }
}

void _registerProviderCombinationTest(
  ProcessingFileFixture fixture,
  RemoteProviderId asr,
  RemoteProviderId summary,
) {
  test('runs ${asr.id} ASR with ${summary.id} summary', () async {
    final run = await _runProviderCombination(fixture, asr, summary);
    final asrClient = run.clients.clients[asr]!;
    final summaryClient = run.clients.clients[summary]!;

    expect(run.clients.builds, [
      (provider: asr, apiKey: 'asr-key'),
      (provider: summary, apiKey: 'summary-key'),
    ]);
    expect(asrClient.transcriptionCalls, 1);
    expect(asrClient.asrModelId, '${asr.id}-asr');
    expect(asrClient.audioPath, run.audio.path);
    expect(asrClient.languageCode, 'auto');
    expect(summaryClient.summaryCalls, 1);
    expect(summaryClient.summaryModelId, '${summary.id}-summary');
    expect(summaryClient.transcript, contains('Transcript text'));
    expect(run.steps, [
      ProcessingStep.transcribing,
      ProcessingStep.summarizing,
    ]);
    expect(run.note.title, 'Remote title');
    expect(run.note.asrName, '${asr.id}-asr');
    expect(run.note.llmName, '${summary.id}-summary');
    expect(run.note.asrSub, _providerName(asr));
    expect(run.note.llmSub, _providerName(summary));
    expect(run.note.asrIsLocal, isFalse);
    expect(run.note.summaryIsLocal, isFalse);
    expect(run.note.summaryError, isNull);
    expect(run.note.transcript.single.text, 'Transcript text');
    expect(run.note.audioOwnership, AudioOwnership.retained);
    expect(await File(run.note.audioPath!).exists(), isTrue);
  });
}

Future<ProviderRun> _runProviderCombination(
  ProcessingFileFixture fixture,
  RemoteProviderId asr,
  RemoteProviderId summary,
) async {
  final audio = await fixture.createAudio(AudioOwnership.external);
  final clients = RecordingClientFactory();
  final steps = <ProcessingStep>[];
  final options = ProcessingRequestOptions()
    ..asrProvider = asr
    ..summaryProvider = summary;
  final note = await _pipeline(fixture, clients).process(
    testProcessingRequest(audio: audio, options: options),
    callbacks: ProcessingCallbacks(onStep: steps.add),
  );
  return (audio: audio, clients: clients, note: note, steps: steps);
}

void _registerSummaryDisabledTest(ProcessingFileFixture fixture) {
  test(
    'skips summary credentials, client, and callback when disabled',
    () async {
      final audio = await fixture.createAudio(AudioOwnership.external);
      final clients = RecordingClientFactory();
      final steps = <ProcessingStep>[];
      final options = ProcessingRequestOptions()
        ..asrProvider = RemoteProviderId.google
        ..summaryProvider = RemoteProviderId.openai
        ..summarizeEnabled = false
        ..summaryApiKey = '';

      final note = await _pipeline(fixture, clients).process(
        testProcessingRequest(audio: audio, options: options),
        callbacks: ProcessingCallbacks(onStep: steps.add),
      );

      expect(clients.builds, [
        (provider: RemoteProviderId.google, apiKey: 'asr-key'),
      ]);
      expect(clients.clients[RemoteProviderId.openai], isNull);
      expect(steps, [ProcessingStep.transcribing]);
      expect(note.title, 'input.m4a');
      expect(note.gist, isEmpty);
      expect(note.points, isEmpty);
      expect(note.todos, isEmpty);
      expect(note.llmName, AppStrings.of(AppLanguage.en).summaryOff);
      expect(note.llmSub, isEmpty);
      expect(note.summaryIsLocal, isFalse);
      expect(note.summaryError, isNull);
    },
  );
}

void _registerValidationTests(ProcessingFileFixture fixture) {
  group('ProcessingPipeline validation and failures', () {
    test('rejects a blank ASR key before validating audio', () async {
      await _expectMissingKey(fixture, _missingAsrKeyOptions());
    });

    test(
      'rejects a blank enabled summary key before validating audio',
      () async {
        await _expectMissingKey(fixture, _missingSummaryKeyOptions());
      },
    );

    test('propagates transcription failure without summarizing', () async {
      final audio = await fixture.createAudio(AudioOwnership.temporary);
      final clients = RecordingClientFactory();
      final failure = StateError('transcription failed');
      clients.clients[RemoteProviderId.openai] = RecordingProviderClient()
        ..transcriptionError = failure;

      await expectLater(
        _pipeline(
          fixture,
          clients,
        ).process(testProcessingRequest(audio: audio)),
        throwsA(same(failure)),
      );

      expect(clients.clients[RemoteProviderId.openai]!.summaryCalls, 0);
      await fixture.cacheManager.discard(audio);
      expect(await File(audio.path).exists(), isFalse);
    });
  });
}

void _registerAudioLifecycleTests(ProcessingFileFixture fixture) {
  group('ProcessingPipeline audio lifecycle', () {
    test('reads an unknown duration once and stores it', () async {
      final audio = await fixture.createAudio(AudioOwnership.external);
      final metadata = FakeAudioMetadata(duration: 37);
      final options = ProcessingRequestOptions()..knownDurationSec = null;
      final note = await _processAudio(fixture, audio, options, metadata);

      expect(metadata.paths, [audio.path]);
      expect(note.durationSec, 37);
    });

    test('retains external audio without deleting the source', () async {
      final audio = await fixture.createAudio(AudioOwnership.external);
      final note = await _processAudio(fixture, audio);

      expect(note.audioOwnership, AudioOwnership.retained);
      expect(note.audioPath, isNot(audio.path));
      expect(await File(note.audioPath!).readAsBytes(), [1, 2, 3]);
      expect(await File(audio.path).exists(), isTrue);
    });

    test(
      'retains audio while staging the temporary source for commit',
      () async {
        final audio = await fixture.createAudio(AudioOwnership.temporary);
        final note = await _processAudio(fixture, audio);

        expect(note.audioOwnership, AudioOwnership.retained);
        expect(note.audioPath, isNot(audio.path));
        expect(await File(note.audioPath!).exists(), isTrue);
        expect(await File(audio.path).exists(), isTrue);
      },
    );

    test('reuses already retained audio', () async {
      final audio = await fixture.createAudio(AudioOwnership.retained);
      final note = await _processAudio(fixture, audio);

      expect(note.audioPath, audio.path);
      expect(note.audioOwnership, AudioOwnership.retained);
      expect(await File(audio.path).exists(), isTrue);
    });

    test('stages auto-delete until the note transaction commits', () async {
      final audio = await fixture.createAudio(AudioOwnership.temporary);
      final options = ProcessingRequestOptions()..autoDeleteAudio = true;
      final note = await _processAudio(fixture, audio, options);

      expect(note.audioPath, isNull);
      expect(note.audioOwnership, AudioOwnership.external);
      expect(await File(audio.path).exists(), isTrue);
    });

    test('uses the localized recording title without a summary', () async {
      final audio = await fixture.createAudio(AudioOwnership.external);
      final options = ProcessingRequestOptions()
        ..source = NoteSource.recording
        ..summarizeEnabled = false
        ..summaryApiKey = '';
      final note = await _processAudio(fixture, audio, options);

      expect(note.title, AppStrings.of(AppLanguage.en).recordingLabel);
      expect(note.speaker, AppStrings.of(AppLanguage.en).ownRecording);
    });
  });
}

Future<TranscriptNote> _processAudio(
  ProcessingFileFixture fixture,
  ManagedAudioFile audio, [
  ProcessingRequestOptions? options,
  FakeAudioMetadata? metadata,
]) => _pipeline(
  fixture,
  RecordingClientFactory(),
  metadata: metadata,
).process(testProcessingRequest(audio: audio, options: options));

ProcessingPipeline _pipeline(
  ProcessingFileFixture fixture,
  RecordingClientFactory clients, {
  FakeAudioMetadata? metadata,
}) => ProcessingPipeline(
  metadata: metadata,
  cacheManager: fixture.cacheManager,
  clientBuilder: clients.call,
  now: () => DateTime.utc(2026, 2, 3, 4, 5),
);

Future<void> _expectMissingKey(
  ProcessingFileFixture fixture,
  ProcessingRequestOptions options,
) async {
  const missing = ManagedAudioFile(
    path: '/missing/input.m4a',
    ownership: AudioOwnership.external,
  );
  final clients = RecordingClientFactory();

  await expectLater(
    _pipeline(
      fixture,
      clients,
    ).process(testProcessingRequest(audio: missing, options: options)),
    throwsA(isA<MissingApiKeyException>()),
  );
  expect(clients.builds, isEmpty);
}

ProcessingRequestOptions _missingAsrKeyOptions() =>
    ProcessingRequestOptions()..asrApiKey = '  ';

ProcessingRequestOptions _missingSummaryKeyOptions() =>
    ProcessingRequestOptions()..summaryApiKey = '\n';

String _providerName(RemoteProviderId provider) => switch (provider) {
  RemoteProviderId.openai => 'OpenAI',
  RemoteProviderId.google => 'Google Gemini',
};
