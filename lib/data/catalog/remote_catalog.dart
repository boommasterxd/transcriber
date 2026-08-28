import 'dart:ui';

import '../models/remote_provider.dart';

/// Supported BYOK providers, defaults, and official key-management pages.
class RemoteCatalog {
  const RemoteCatalog._();

  static const List<RemoteProvider> providers = [
    RemoteProvider(
      id: RemoteProviderId.openai,
      name: 'OpenAI',
      color: Color(0xFF10A37F),
      glyph: 'O',
      sub: 'GPT-Transcribe and GPT models',
    ),
    RemoteProvider(
      id: RemoteProviderId.google,
      name: 'Google Gemini',
      color: Color(0xFF4285F4),
      glyph: 'G',
      sub: 'Gemini 3.5 Transcribe and Gemini models',
    ),
  ];

  /// Providers that offer native audio transcription (ASR).
  static const List<RemoteProviderId> asrProviders = RemoteProviderId.values;

  static RemoteProvider provider(RemoteProviderId id) =>
      providers.firstWhere((p) => p.id == id);

  /// Default chat/summary model id per provider (used until the user picks one).
  static const Map<RemoteProviderId, String> defaultChatModelId = {
    RemoteProviderId.openai: 'gpt-5.6-luna',
    RemoteProviderId.google: 'gemini-3.7-flash',
  };

  /// Default transcription model id per ASR-capable provider.
  static const Map<RemoteProviderId, String> defaultAsrModelId = {
    RemoteProviderId.openai: 'gpt-transcribe',
    RemoteProviderId.google: 'gemini-3.5-transcribe',
  };

  static String chatDefault(RemoteProviderId id) =>
      defaultChatModelId[id] ?? defaultChatModelId[RemoteProviderId.google]!;
  static String asrDefault(RemoteProviderId id) =>
      defaultAsrModelId[id] ?? defaultAsrModelId[RemoteProviderId.google]!;

  /// Page where the user creates an API key for each provider.
  static const Map<RemoteProviderId, String> keyUrl = {
    RemoteProviderId.openai: 'https://platform.openai.com/api-keys',
    RemoteProviderId.google: 'https://aistudio.google.com/app/apikey',
  };

  static String keyUrlFor(RemoteProviderId id) =>
      keyUrl[id] ?? keyUrl[RemoteProviderId.google]!;
}
