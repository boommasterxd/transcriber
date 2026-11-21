import 'remote_provider.dart';
import 'transcription_language.dart';

/// Independent configuration of the audio-to-text stage.
class TranscriptionSettings {
  const TranscriptionSettings({
    this.language = TranscriptionLanguage.auto,
    this.provider = RemoteProviderId.google,
    this.models = const {},
  });

  final TranscriptionLanguage language;
  final RemoteProviderId provider;
  final Map<RemoteProviderId, String> models;

  TranscriptionSettings copyWith({
    TranscriptionLanguage? language,
    RemoteProviderId? provider,
    Map<RemoteProviderId, String>? models,
  }) => TranscriptionSettings(
    language: language ?? this.language,
    provider: provider ?? this.provider,
    models: models ?? this.models,
  );
}

/// Independent configuration of the optional transcript-to-summary stage.
class SummarySettings {
  const SummarySettings({
    this.provider = RemoteProviderId.google,
    this.models = const {},
    this.enabled = true,
  });

  final RemoteProviderId provider;
  final Map<RemoteProviderId, String> models;
  final bool enabled;

  SummarySettings copyWith({
    RemoteProviderId? provider,
    Map<RemoteProviderId, String>? models,
    bool? enabled,
  }) => SummarySettings(
    provider: provider ?? this.provider,
    models: models ?? this.models,
    enabled: enabled ?? this.enabled,
  );
}
