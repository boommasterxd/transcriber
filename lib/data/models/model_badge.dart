import '../../core/l10n/app_strings.dart';

/// Short qualitative label shown next to a model (speed / quality hint).
enum ModelBadge {
  veryFast,
  fast,
  balanced,
  accurate,
  detailed,
  recommended,
  mostCapable,
  cheap,
  reasoning,
  multimodal,
  openSource;

  String label(AppStrings t) {
    switch (this) {
      case ModelBadge.veryFast:
        return t.badgeVeryFast;
      case ModelBadge.fast:
        return t.badgeFast;
      case ModelBadge.balanced:
        return t.badgeBalanced;
      case ModelBadge.accurate:
        return t.badgeAccurate;
      case ModelBadge.detailed:
        return t.badgeDetailed;
      case ModelBadge.recommended:
        return t.recommended;
      case ModelBadge.mostCapable:
        return t.badgeMostCapable;
      case ModelBadge.cheap:
        return t.badgeCheap;
      case ModelBadge.reasoning:
        return t.badgeReasoning;
      case ModelBadge.multimodal:
        return 'Multimodal · Audio';
      case ModelBadge.openSource:
        return 'Open Source';
    }
  }
}
