import 'dart:typed_data';

import '../../data/models/remote_provider.dart';
import '../../data/models/transcription_language.dart';

/// Live models are intentionally separate from the file-transcription catalog.
class LiveDictationModelCatalog {
  const LiveDictationModelCatalog._();

  static const Map<RemoteProviderId, String> modelByProvider = {
    RemoteProviderId.openai: 'gpt-live-transcribe',
    RemoteProviderId.google: 'gemini-3.5-transcribe-live',
  };

  static String modelFor(RemoteProviderId provider) =>
      modelByProvider[provider]!;

  static int sampleRateFor(RemoteProviderId provider) =>
      provider == RemoteProviderId.openai ? 24000 : 16000;

  static String? languageCodeFor(
    RemoteProviderId provider,
    TranscriptionLanguage language,
  ) {
    if (language == TranscriptionLanguage.auto) return null;
    if (provider == RemoteProviderId.openai) return language.code;
    return switch (language) {
      TranscriptionLanguage.de => 'de-DE',
      TranscriptionLanguage.en => 'en-US',
      TranscriptionLanguage.auto => null,
    };
  }
}

final class LiveConnectionException implements Exception {
  const LiveConnectionException(this.code);

  final String code;
}

class LiveTranscriptionConfig {
  const LiveTranscriptionConfig({
    required this.provider,
    required this.apiKey,
    required this.languageCode,
  });

  final RemoteProviderId provider;
  final String apiKey;
  final String? languageCode;

  String get modelId => LiveDictationModelCatalog.modelFor(provider);
  int get sampleRate => LiveDictationModelCatalog.sampleRateFor(provider);
}

sealed class LiveTranscriptionEvent {
  const LiveTranscriptionEvent();
}

final class LiveTranscriptionReady extends LiveTranscriptionEvent {
  const LiveTranscriptionReady();
}

final class LiveTranscriptionPartial extends LiveTranscriptionEvent {
  const LiveTranscriptionPartial(this.text);
  final String text;
}

final class LiveTranscriptionFinal extends LiveTranscriptionEvent {
  const LiveTranscriptionFinal(this.text);
  final String text;
}

final class LiveTranscriptionDisconnected extends LiveTranscriptionEvent {
  const LiveTranscriptionDisconnected();
}

final class LiveTranscriptionFailure extends LiveTranscriptionEvent {
  const LiveTranscriptionFailure(this.code);
  final String code;
}

abstract interface class LiveTranscriptionClient {
  Stream<LiveTranscriptionEvent> get events;

  Future<void> connect();
  void addAudio(Uint8List pcm);
  Future<void> finish();
  Future<void> close();
}

typedef LiveTranscriptionClientFactory =
    LiveTranscriptionClient Function(LiveTranscriptionConfig config);
