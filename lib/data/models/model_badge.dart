import '../../core/l10n/app_strings.dart';

/// Short qualitative label shown next to a model (speed / quality hint).
enum ModelBadge {
  veryFast('Sehr schnell', 'Very fast'),
  fast('Schnell', 'Fast'),
  balanced('Ausgewogen', 'Balanced'),
  accurate('Sehr genau', 'Most accurate'),
  detailed('Detailliert', 'Detailed'),
  recommended('Empfohlen', 'Recommended'),
  mostCapable('Stärkste', 'Most capable'),
  cheap('Schnell & günstig', 'Fast & cheap'),
  reasoning('Reasoning', 'Reasoning'),
  multimodal('Multimodal · Audio', 'Multimodal · Audio'),
  openSource('Open Source', 'Open Source');

  const ModelBadge(this._de, this._en);
  final String _de;
  final String _en;

  String label(AppLanguage lang) => lang == AppLanguage.de ? _de : _en;
}
