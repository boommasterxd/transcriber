import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/processing/processing_pipeline.dart';
import 'package:transcriber/services/service_exceptions.dart';
import 'package:transcriber/services/storage/managed_audio_file.dart';

import 'processing_test_support.dart';

void main() {
  final fixture = ProcessingFileFixture();
  setUp(fixture.setUp);
  tearDown(fixture.tearDown);

  for (final provider in RemoteProviderId.values) {
    test('preserves a transcript when ${provider.id} summary fails', () async {
      final audio = await fixture.createAudio(AudioOwnership.temporary);
      final clients = RecordingClientFactory();
      final client = RecordingProviderClient()
        ..summaryError = const RemoteApiException(
          'Provider error (400): Thinking is not enabled for this model.',
          statusCode: 400,
        );
      clients.clients[provider] = client;
      final options = ProcessingRequestOptions()..summaryProvider = provider;
      final steps = <ProcessingStep>[];
      final note = await _pipeline(fixture, clients).process(
        testProcessingRequest(audio: audio, options: options),
        callbacks: ProcessingCallbacks(onStep: steps.add),
      );

      expect(note.fullTranscriptText, 'Transcript text');
      expect(note.summaryError, client.summaryError.toString());
      expect(note.title, 'input.m4a');
      expect(note.gist, isEmpty);
      expect(note.points, isEmpty);
      expect(note.todos, isEmpty);
      expect(note.llmName, '${provider.id}-summary');
      expect(client.summaryCalls, 1);
      expect(clients.clients[RemoteProviderId.openai]!.transcriptionCalls, 1);
      expect(steps, [ProcessingStep.transcribing, ProcessingStep.summarizing]);
      expect(note.audioOwnership, AudioOwnership.retained);
      expect(await File(note.audioPath!).readAsBytes(), [1, 2, 3]);
      expect(await File(audio.path).exists(), isTrue);
    });
  }

  test('preserves a transcript for an unexpected summary failure', () async {
    final audio = await fixture.createAudio(AudioOwnership.temporary);
    final clients = RecordingClientFactory();
    clients.clients[RemoteProviderId.openai] = RecordingProviderClient()
      ..summaryError = StateError('private transcript and summary-key');
    final options = ProcessingRequestOptions()..autoDeleteAudio = true;
    final note = await _pipeline(
      fixture,
      clients,
    ).process(testProcessingRequest(audio: audio, options: options));

    expect(note.fullTranscriptText, 'Transcript text');
    expect(note.summaryError, 'The summary could not be generated.');
    expect(note.audioPath, isNull);
    expect(await File(audio.path).exists(), isTrue);
  });

  test('redacts both stage keys and credential fields before saving', () async {
    final audio = await fixture.createAudio(AudioOwnership.external);
    final clients = RecordingClientFactory();
    clients.clients[RemoteProviderId.openai] = RecordingProviderClient()
      ..summaryError = const RemoteApiException(
        'Failure\n summary-key asr-key token=other-secret',
      );
    final note = await _pipeline(
      fixture,
      clients,
    ).process(testProcessingRequest(audio: audio));

    expect(note.summaryError, 'Failure [REDACTED] [REDACTED] [REDACTED]');
  });

  test(
    'bounds provider diagnostics without leaking a key across the limit',
    () async {
      final audio = await fixture.createAudio(AudioOwnership.external);
      final clients = RecordingClientFactory();
      clients.clients[RemoteProviderId.openai] = RecordingProviderClient()
        ..summaryError = RemoteApiException('${'x' * 509}asr-key${'y' * 100}');
      final note = await _pipeline(
        fixture,
        clients,
      ).process(testProcessingRequest(audio: audio));

      expect(note.summaryError, '${'x' * 509}[RE...');
      expect(note.summaryError!.length, 515);
      expect(note.fullTranscriptText, 'Transcript text');
    },
  );
}

ProcessingPipeline _pipeline(
  ProcessingFileFixture fixture,
  RecordingClientFactory clients,
) => ProcessingPipeline(
  cacheManager: fixture.cacheManager,
  clientBuilder: clients.call,
);
