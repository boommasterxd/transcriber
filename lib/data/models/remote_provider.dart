import 'dart:ui';

/// Cloud providers supported for transcription and summarization.
enum RemoteProviderId {
  openai('openai'),
  google('google');

  const RemoteProviderId(this.id);
  final String id;

  static RemoteProviderId fromId(String? id) => RemoteProviderId.values
      .firstWhere((provider) => provider.id == id, orElse: () => google);
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
