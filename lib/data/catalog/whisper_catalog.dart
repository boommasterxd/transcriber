import '../models/model_badge.dart';
import '../models/whisper_model_spec.dart';

/// On-device Whisper ASR models available through the `whisper_kit` package.
/// IDs correspond 1:1 to the package's `WhisperModel` enum values.
const int _mb = 1024 * 1024;

class WhisperCatalog {
  const WhisperCatalog._();

  static const List<WhisperModelSpec> models = [
    WhisperModelSpec(
      id: 'tiny',
      displayName: 'Whisper Tiny',
      sizeBytes: 75 * _mb,
      badge: ModelBadge.veryFast,
    ),
    WhisperModelSpec(
      id: 'base',
      displayName: 'Whisper Base',
      sizeBytes: 142 * _mb,
      badge: ModelBadge.fast,
    ),
    WhisperModelSpec(
      id: 'small',
      displayName: 'Whisper Small',
      sizeBytes: 466 * _mb,
      badge: ModelBadge.balanced,
    ),
    WhisperModelSpec(
      id: 'medium',
      displayName: 'Whisper Medium',
      sizeBytes: 1500 * _mb,
      badge: ModelBadge.accurate,
    ),
  ];

  static const String defaultId = 'base';

  static WhisperModelSpec byId(String id) =>
      models.firstWhere((m) => m.id == id, orElse: () => models[1]);
}
