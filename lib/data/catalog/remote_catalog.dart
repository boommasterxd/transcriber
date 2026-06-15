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
      subDe: 'Claude Opus, Sonnet, Haiku',
      subEn: 'Claude Opus, Sonnet, Haiku',
    ),
    RemoteProvider(
      id: RemoteProviderId.openai,
      name: 'OpenAI',
      color: Color(0xFF10A37F),
      glyph: 'O',
      subDe: 'GPT-4o, o3, GPT-4o mini',
      subEn: 'GPT-4o, o3, GPT-4o mini',
    ),
    RemoteProvider(
      id: RemoteProviderId.google,
      name: 'Google',
      color: Color(0xFF4285F4),
      glyph: 'G',
      subDe: 'Gemini 2.5 Pro & Flash',
      subEn: 'Gemini 2.5 Pro & Flash',
    ),
    RemoteProvider(
      id: RemoteProviderId.openrouter,
      name: 'OpenRouter',
      color: Color(0xFF6566F1),
      glyph: 'OR',
      subDe: '300+ Modelle, ein Schlüssel',
      subEn: '300+ models, one key',
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
    RemoteProviderId.anthropic: 'claude-sonnet-4-5',
    RemoteProviderId.openai: 'gpt-4o',
    RemoteProviderId.google: 'gemini-2.5-flash',
    RemoteProviderId.openrouter: 'openrouter/auto',
  };

  /// Default transcription model id per ASR-capable provider.
  static const Map<RemoteProviderId, String> defaultAsrModelId = {
    RemoteProviderId.openai: 'gpt-4o-transcribe',
    RemoteProviderId.google: 'gemini-2.5-flash',
  };

  static String chatDefault(RemoteProviderId id) => defaultChatModelId[id] ?? 'gpt-4o';
  static String asrDefault(RemoteProviderId id) => defaultAsrModelId[id] ?? 'gpt-4o-transcribe';

  /// Page where the user creates an API key for each provider.
  static const Map<RemoteProviderId, String> keyUrl = {
    RemoteProviderId.anthropic: 'https://console.anthropic.com/settings/keys',
    RemoteProviderId.openai: 'https://platform.openai.com/api-keys',
    RemoteProviderId.google: 'https://aistudio.google.com/app/apikey',
    RemoteProviderId.openrouter: 'https://openrouter.ai/keys',
  };

  static String keyUrlFor(RemoteProviderId id) => keyUrl[id] ?? 'https://huggingface.co';
}
