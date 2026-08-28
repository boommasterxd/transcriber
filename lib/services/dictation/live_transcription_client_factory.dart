import '../../data/models/remote_provider.dart';
import 'google_live_transcription_client.dart';
import 'live_transcription.dart';
import 'openai_live_transcription_client.dart';

LiveTranscriptionClient createLiveTranscriptionClient(
  LiveTranscriptionConfig config,
) => switch (config.provider) {
  RemoteProviderId.openai => OpenAiLiveTranscriptionClient(config),
  RemoteProviderId.google => GoogleLiveTranscriptionClient(config),
};
