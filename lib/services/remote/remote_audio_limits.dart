import '../../data/models/remote_provider.dart';
import 'provider_model_capabilities.dart';

/// Application upload caps shared by recording and provider validation.
const int maxRemoteAudioBytes = 100 * 1024 * 1024;
const int maxOpenAiTranscriptionBytes = 25 * 1000 * 1000;
const int maxInlineAudioBytes = 20 * 1024 * 1024;

int remoteAudioLimit(RemoteProviderId provider, String modelId) =>
    switch (provider) {
      RemoteProviderId.openai =>
        ProviderModelCapabilities.usesOpenAiAudioChat(modelId)
            ? maxInlineAudioBytes
            : maxOpenAiTranscriptionBytes,
      RemoteProviderId.google => maxRemoteAudioBytes,
    };
