import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/processing_mode.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/data/repositories/settings_repository.dart';
import 'package:transcriber/services/processing/processing_pipeline.dart';
import 'package:transcriber/state/processing_controller.dart';
import 'package:transcriber/state/providers.dart';

void main() {
  _registerSummaryOffCredentialsTest();
  _registerCloudCredentialsTest();
  _registerLocalCredentialsTest();
}

void _registerSummaryOffCredentialsTest() {
  test('does not read a summary key when summarization is disabled', () async {
    final harness = await _controllerHarness(_cloudSettings(summary: false));

    await harness.run();

    expect(harness.repository.requestedProviders, [RemoteProviderId.openai]);
    expect(harness.pipeline.capturedRequest?.credentials.asrApiKey, 'asr-key');
    expect(
      harness.pipeline.capturedRequest?.credentials.summaryApiKey,
      isEmpty,
    );
  });
}

void _registerCloudCredentialsTest() {
  test('loads independent credentials for enabled cloud stages', () async {
    final harness = await _controllerHarness(_cloudSettings(summary: true));

    await harness.run();

    expect(harness.repository.requestedProviders, [
      RemoteProviderId.openai,
      RemoteProviderId.anthropic,
    ]);
    expect(harness.pipeline.capturedRequest?.credentials.asrApiKey, 'asr-key');
    expect(
      harness.pipeline.capturedRequest?.credentials.summaryApiKey,
      'summary-key',
    );
  });
}

void _registerLocalCredentialsTest() {
  test('does not read credentials for local stages', () async {
    final settings = AppSettings.initial().copyWith(
      asrMode: ProcessingMode.onDevice,
      summaryMode: ProcessingMode.onDevice,
      summarizeEnabled: true,
    );
    final harness = await _controllerHarness(settings);

    await harness.run();

    expect(harness.repository.requestedProviders, isEmpty);
    expect(harness.pipeline.capturedRequest?.credentials.asrApiKey, isEmpty);
    expect(
      harness.pipeline.capturedRequest?.credentials.summaryApiKey,
      isEmpty,
    );
  });
}

AppSettings _cloudSettings({required bool summary}) =>
    AppSettings.initial().copyWith(
      asrMode: ProcessingMode.cloud,
      summaryMode: ProcessingMode.cloud,
      asrProvider: RemoteProviderId.openai,
      summaryProvider: RemoteProviderId.anthropic,
      summarizeEnabled: summary,
    );

Future<_ControllerHarness> _controllerHarness(AppSettings settings) async {
  SharedPreferences.setMockInitialValues({});
  final repository = _TrackingSettingsRepository(
    await SharedPreferences.getInstance(),
    keys: const {
      RemoteProviderId.openai: 'asr-key',
      RemoteProviderId.anthropic: 'summary-key',
    },
  );
  final pipeline = _CapturingPipeline();
  final container = ProviderContainer(
    overrides: [
      initialSettingsProvider.overrideWithValue(settings),
      initialConnectionsProvider.overrideWithValue(const {}),
      settingsRepositoryProvider.overrideWithValue(repository),
      processingPipelineProvider.overrideWithValue(pipeline),
    ],
  );
  addTearDown(container.dispose);
  return _ControllerHarness(container, repository, pipeline);
}

final class _ControllerHarness {
  const _ControllerHarness(this.container, this.repository, this.pipeline);

  final ProviderContainer container;
  final _TrackingSettingsRepository repository;
  final _CapturingPipeline pipeline;

  Future<void> run() => container
      .read(processingControllerProvider.notifier)
      .run(
        const ProcessingInput(
          audioPath: '/audio/input.m4a',
          source: NoteSource.file,
        ),
        save: false,
      );
}

final class _TrackingSettingsRepository extends SettingsRepository {
  _TrackingSettingsRepository(super.preferences, {required this.keys});

  final Map<RemoteProviderId, String> keys;
  final List<RemoteProviderId> requestedProviders = [];

  @override
  Future<String?> apiKey(RemoteProviderId provider) async {
    requestedProviders.add(provider);
    return keys[provider];
  }
}

final class _CapturingPipeline extends ProcessingPipeline {
  ProcessingRequest? capturedRequest;

  @override
  Future<TranscriptNote> process(
    ProcessingRequest request, {
    ProcessingCallbacks callbacks = const ProcessingCallbacks(),
  }) async {
    capturedRequest = request;
    return TranscriptNote(
      id: 'note-id',
      title: 'Transcript',
      speaker: 'Speaker',
      source: request.input.source,
      durationSec: 0,
      createdAt: DateTime.utc(2026),
      asrIsLocal: false,
      summaryIsLocal: true,
      asrName: 'ASR',
      asrSub: 'Cloud',
      llmName: 'Off',
      llmSub: '',
      gist: '',
      points: const [],
      todos: const [],
      transcript: const [],
      audioPath: request.input.audioPath,
    );
  }
}
