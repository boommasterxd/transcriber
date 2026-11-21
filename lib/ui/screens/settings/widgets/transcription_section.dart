import 'remote_stage.dart';
import 'remote_stage_settings.dart';

/// Required speech-to-text task, with its provider and model in one card.
class TranscriptionSection extends RemoteStageSettings {
  const TranscriptionSection({super.key, super.allowedProviders})
    : super(stage: RemoteStage.transcription);
}
