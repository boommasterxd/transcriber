import 'dart:ui';

import '../models/remote_provider.dart';

/// Cloud provider metadata + sensible default model ids. The actual selectable
/// model lists are fetched live from each provider's API (see
/// `remoteModelsProvider`).
class RemoteCatalog {
  const RemoteCatalog._();

  static const List<RemoteProvider> providers = [
    RemoteProvider(
      id: RemoteProviderId.anthropic,
      name: 'Anthropic',
      color: Color(0xFFCC785C),
      glyph: 'A',
      sub: 'Claude Opus 4.8, Sonnet 4.6, Haiku 4.5',
    ),
    RemoteProvider(
      id: RemoteProviderId.openai,
      name: 'OpenAI',
      color: Color(0xFF10A37F),
      glyph: 'O',
      sub: 'GPT-5.5, GPT-5.5 Pro, o-series',
    ),
    RemoteProvider(
      id: RemoteProviderId.google,
      name: 'Google',
      color: Color(0xFF4285F4),
      glyph: 'G',
      sub: 'Gemini 3.5 Pro & Flash',
    ),
    RemoteProvider(
      id: RemoteProviderId.openrouter,
      name: 'OpenRouter',
      color: Color(0xFF6566F1),
      glyph: 'OR',
      sub: '300+ models, one key',
    ),
  ];

  /// Providers that offer native audio transcription (ASR).
  static const List<RemoteProviderId> asrProviders = [
    RemoteProviderId.openai,
    RemoteProviderId.google,
  ];

  static RemoteProvider provider(RemoteProviderId id) =>
      providers.firstWhere((p) => p.id == id);

  /// Default chat/summary model id per provider (used until the user picks one).
  static const Map<RemoteProviderId, String> defaultChatModelId = {
    RemoteProviderId.anthropic: 'claude-sonnet-4-6',
    RemoteProviderId.openai: 'gpt-5.5',
    RemoteProviderId.google: 'gemini-3.5-flash',
    RemoteProviderId.openrouter: 'openrouter/auto',
  };

  /// Default transcription model id per ASR-capable provider.
  static const Map<RemoteProviderId, String> defaultAsrModelId = {
    RemoteProviderId.openai: 'gpt-4o-transcribe',
    RemoteProviderId.google: 'gemini-3.5-flash',
  };

  static String chatDefault(RemoteProviderId id) =>
      defaultChatModelId[id] ?? 'gpt-5.5';
  static String asrDefault(RemoteProviderId id) =>
      defaultAsrModelId[id] ?? 'gpt-4o-transcribe';

  /// Page where the user creates an API key for each provider.
  static const Map<RemoteProviderId, String> keyUrl = {
    RemoteProviderId.anthropic: 'https://console.anthropic.com/settings/keys',
    RemoteProviderId.openai: 'https://platform.openai.com/api-keys',
    RemoteProviderId.google: 'https://aistudio.google.com/app/apikey',
    RemoteProviderId.openrouter: 'https://openrouter.ai/keys',
  };

  static String keyUrlFor(RemoteProviderId id) =>
      keyUrl[id] ?? 'https://huggingface.co';
}
