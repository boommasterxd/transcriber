import 'model_badge.dart';

/// A locally runnable Whisper ASR model exposed by the `whisper_kit` package.
///
/// [id] matches the `WhisperModel` enum name and is mapped to the native enum
/// inside [WhisperTranscriptionService], keeping the package dependency isolated.
class WhisperModelSpec {
  const WhisperModelSpec({
    required this.id,
    required this.displayName,
    required this.sizeBytes,
    required this.badge,
  });

  final String id;
  final String displayName;
  final int sizeBytes;
  final ModelBadge badge;
}
