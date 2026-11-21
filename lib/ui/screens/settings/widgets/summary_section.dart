import 'remote_stage.dart';
import 'remote_stage_settings.dart';

/// Optional summary task, with its switch and model in the same card.
class SummarySection extends RemoteStageSettings {
  const SummarySection({super.key, super.allowedProviders})
    : super(stage: RemoteStage.summary);
}
