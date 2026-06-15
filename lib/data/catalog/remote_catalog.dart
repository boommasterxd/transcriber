import 'dart:ui';

import '../models/model_badge.dart';
import '../models/remote_provider.dart';

/// Cloud providers and their selectable models. [apiModelId] values are the
/// exact identifiers sent to each provider's REST API.
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

  static const Map<RemoteProviderId, List<RemoteModelSpec>> _models = {
    RemoteProviderId.anthropic: [
      RemoteModelSpec(
        id: 'opus',
        providerId: RemoteProviderId.anthropic,
        displayName: 'Claude Opus 4.1',
        apiModelId: 'claude-opus-4-1',
        badge: ModelBadge.mostCapable,
      ),
      RemoteModelSpec(
        id: 'sonnet',
        providerId: RemoteProviderId.anthropic,
        displayName: 'Claude Sonnet 4.5',
        apiModelId: 'claude-sonnet-4-5',
        badge: ModelBadge.recommended,
      ),
      RemoteModelSpec(
        id: 'haiku',
        providerId: RemoteProviderId.anthropic,
        displayName: 'Claude Haiku 3.5',
        apiModelId: 'claude-3-5-haiku-latest',
        badge: ModelBadge.cheap,
      ),
    ],
    RemoteProviderId.openai: [
      RemoteModelSpec(
        id: 'gpt4o',
        providerId: RemoteProviderId.openai,
        displayName: 'GPT-4o',
        apiModelId: 'gpt-4o',
        badge: ModelBadge.recommended,
      ),
      RemoteModelSpec(
        id: 'gpt4omini',
        providerId: RemoteProviderId.openai,
        displayName: 'GPT-4o mini',
        apiModelId: 'gpt-4o-mini',
        badge: ModelBadge.cheap,
      ),
      RemoteModelSpec(
        id: 'o3',
        providerId: RemoteProviderId.openai,
        displayName: 'o3',
        apiModelId: 'o3',
        badge: ModelBadge.reasoning,
      ),
    ],
    RemoteProviderId.google: [
      RemoteModelSpec(
        id: 'gpro',
        providerId: RemoteProviderId.google,
        displayName: 'Gemini 2.5 Pro',
        apiModelId: 'gemini-2.5-pro',
        badge: ModelBadge.mostCapable,
      ),
      RemoteModelSpec(
        id: 'gflash',
        providerId: RemoteProviderId.google,
        displayName: 'Gemini 2.5 Flash',
        apiModelId: 'gemini-2.5-flash',
        badge: ModelBadge.recommended,
      ),
      RemoteModelSpec(
        id: 'g2flash',
        providerId: RemoteProviderId.google,
        displayName: 'Gemini 2.0 Flash',
        apiModelId: 'gemini-2.0-flash',
        badge: ModelBadge.fast,
      ),
    ],
    RemoteProviderId.openrouter: [
      RemoteModelSpec(
        id: 'auto',
        providerId: RemoteProviderId.openrouter,
        displayName: 'Auto (beste Wahl)',
        apiModelId: 'openrouter/auto',
        badge: ModelBadge.recommended,
      ),
      RemoteModelSpec(
        id: 'llama',
        providerId: RemoteProviderId.openrouter,
        displayName: 'Llama 3.3 70B',
        apiModelId: 'meta-llama/llama-3.3-70b-instruct',
        badge: ModelBadge.openSource,
      ),
      RemoteModelSpec(
        id: 'deepseek',
        providerId: RemoteProviderId.openrouter,
        displayName: 'DeepSeek V3',
        apiModelId: 'deepseek/deepseek-chat',
        badge: ModelBadge.cheap,
      ),
    ],
  };

  static List<RemoteModelSpec> modelsFor(RemoteProviderId id) => _models[id] ?? const [];

  static RemoteProvider provider(RemoteProviderId id) =>
      providers.firstWhere((p) => p.id == id);

  static RemoteModelSpec model(RemoteProviderId provider, String modelId) {
    final list = modelsFor(provider);
    return list.firstWhere((m) => m.id == modelId, orElse: () => list.first);
  }

  static const Map<RemoteProviderId, String> defaultModelId = {
    RemoteProviderId.anthropic: 'sonnet',
    RemoteProviderId.openai: 'gpt4o',
    RemoteProviderId.google: 'gflash',
    RemoteProviderId.openrouter: 'auto',
  };
}
