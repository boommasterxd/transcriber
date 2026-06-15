import '../../core/l10n/app_strings.dart';

/// Short qualitative label shown next to a model (speed / quality hint).
enum ModelBadge {
  veryFast('Klein & schnell', 'Small & fast'),
  fast('Schnell', 'Fast'),
  balanced('Ausgewogen', 'Balanced'),
  accurate('Beste Qualität', 'Best quality'),
  detailed('Detaillierter', 'More detailed'),
  recommended('Empfohlen', 'Recommended'),
  mostCapable('Stärkste', 'Most capable'),
  cheap('Schnell & günstig', 'Fast & cheap'),
  reasoning('Stark im Denken', 'Strong reasoning'),
  multimodal('Multimodal · Audio', 'Multimodal · Audio'),
  openSource('Open Source', 'Open Source');

  const ModelBadge(this._de, this._en);
  final String _de;
  final String _en;

  String label(AppLanguage lang) => lang == AppLanguage.de ? _de : _en;
}
