import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/dictation/live_transcription.dart';
import 'package:transcriber/services/dictation/openai_live_transcription_client.dart';

import 'live_test_support.dart';

LiveClientTestHarness<OpenAiLiveTranscriptionClient> createOpenAiHarness({
  Duration finalizationTimeout = const Duration(seconds: 4),
}) => LiveClientTestHarness.create(
  (connector) => OpenAiLiveTranscriptionClient(
    const LiveTranscriptionConfig(
      provider: RemoteProviderId.openai,
      apiKey: 'secret-openai-key',
      languageCode: 'de',
    ),
    connector: connector.call,
    finalizationTimeout: finalizationTimeout,
  ),
);
