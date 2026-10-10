import '../../../../data/models/remote_provider.dart';

/// The two independently configured audio processing tasks.
enum RemoteStage {
  transcription,
  summary;

  bool get forTranscription => this == transcription;
}

/// A confirmed model belongs to one provider and one processing task.
typedef RemoteModelSelection = ({RemoteProviderId provider, String modelId});
