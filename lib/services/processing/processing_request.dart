import '../../core/l10n/app_strings.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/transcript_note.dart';

/// The two visible steps of the processing flow.
enum ProcessingStep { transcribing, summarizing }

typedef ProcessingStepCallback = void Function(ProcessingStep step);
typedef ModelProgressCallback = void Function(double progress);

/// Identifies the audio being processed and any metadata already known by the UI.
final class ProcessingInput {
  const ProcessingInput({
    required this.audioPath,
    required this.source,
    this.knownDurationSec,
  });

  final String audioPath;
  final NoteSource source;
  final int? knownDurationSec;

  ProcessingInput withKnownDuration(int durationSec) => ProcessingInput(
    audioPath: audioPath,
    source: source,
    knownDurationSec: durationSec,
  );
}

/// Credentials required by the independently configured cloud stages.
final class ProcessingCredentials {
  const ProcessingCredentials({
    required this.asrApiKey,
    required this.summaryApiKey,
  });

  final String asrApiKey;
  final String summaryApiKey;
}

/// Immutable input shared by direct processing and the foreground isolate.
final class ProcessingRequest {
  const ProcessingRequest({
    required this.input,
    required this.settings,
    required this.credentials,
  });

  final ProcessingInput input;
  final AppSettings settings;
  final ProcessingCredentials credentials;

  AppStrings get strings => AppStrings.of(settings.language);

  ProcessingRequest withKnownDuration(int durationSec) => ProcessingRequest(
    input: input.withKnownDuration(durationSec),
    settings: settings,
    credentials: credentials,
  );

  /// Serializes the foreground-isolate handoff using the existing wire shape.
  Map<String, dynamic> toJson() => {
    'audioPath': input.audioPath,
    'source': input.source.id,
    'settings': settings.toJson(),
    'hfToken': settings.hfToken,
    'asrApiKey': credentials.asrApiKey,
    'summaryApiKey': credentials.summaryApiKey,
    'knownDurationSec': input.knownDurationSec,
  };

  factory ProcessingRequest.fromJson(Map<String, dynamic> json) {
    final settingsJson = (json['settings'] as Map).cast<String, dynamic>();
    final settings = AppSettings.fromJson(
      settingsJson,
      hfToken: json['hfToken'] as String? ?? '',
    );
    return ProcessingRequest(
      input: ProcessingInput(
        audioPath: json['audioPath'] as String,
        source: NoteSource.fromId(json['source'] as String?),
        knownDurationSec: (json['knownDurationSec'] as num?)?.toInt(),
      ),
      settings: settings,
      credentials: ProcessingCredentials(
        asrApiKey: json['asrApiKey'] as String? ?? '',
        summaryApiKey: json['summaryApiKey'] as String? ?? '',
      ),
    );
  }
}

/// Optional observer callbacks that never cross the isolate JSON boundary.
final class ProcessingCallbacks {
  const ProcessingCallbacks({this.onStep, this.onModelProgress});

  final ProcessingStepCallback? onStep;
  final ModelProgressCallback? onModelProgress;
}
