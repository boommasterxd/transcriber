import 'dart:ui';

import 'model_badge.dart';

/// Cloud LLM/ASR providers supported in "Cloud API" mode.
enum RemoteProviderId {
  anthropic('anthropic'),
  openai('openai'),
  google('google'),
  openrouter('openrouter');

  const RemoteProviderId(this.id);
  final String id;

  static RemoteProviderId fromId(String? id) =>
      RemoteProviderId.values.firstWhere((p) => p.id == id, orElse: () => RemoteProviderId.anthropic);
}

/// Display metadata for a provider.
class RemoteProvider {
  const RemoteProvider({
    required this.id,
    required this.name,
    required this.color,
    required this.glyph,
    required this.sub,
  });

  final RemoteProviderId id;
  final String name;
  final Color color;
  final String glyph;
  final String sub;
}

/// A selectable cloud model for a provider. [apiModelId] is the exact string
/// sent to the provider's REST API.
class RemoteModelSpec {
  const RemoteModelSpec({
    required this.id,
    required this.providerId,
    required this.displayName,
    required this.apiModelId,
    required this.badge,
  });

  final String id;
  final RemoteProviderId providerId;
  final String displayName;
  final String apiModelId;
  final ModelBadge badge;
}
