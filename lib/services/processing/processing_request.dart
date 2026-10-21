import '../../core/l10n/app_strings.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/transcript_note.dart';
import '../storage/managed_audio_file.dart';

/// The two visible steps of the processing flow.
enum ProcessingStep { transcribing, summarizing }

typedef ProcessingStepCallback = void Function(ProcessingStep step);

/// Identifies the audio being processed and any metadata already known by the UI.
final class ProcessingInput {
  const ProcessingInput({
    required this.audio,
    required this.source,
    this.knownDurationSec,
  });

  final ManagedAudioFile audio;
  final NoteSource source;
  final int? knownDurationSec;

  String get audioPath => audio.path;

  ProcessingInput withKnownDuration(int durationSec) => ProcessingInput(
    audio: audio,
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

/// Immutable input for one cloud-processing run.
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
}

/// Optional observer callbacks for the visible cloud processing stages.
final class ProcessingCallbacks {
  const ProcessingCallbacks({this.onStep, this.isCancelled});

  final ProcessingStepCallback? onStep;
  final bool Function()? isCancelled;

  /// Stops subsequent local stages; an in-flight provider request may complete.
  void throwIfCancelled() {
    if (isCancelled?.call() ?? false) {
      throw const ProcessingCancelledException();
    }
  }
}

final class ProcessingCancelledException implements Exception {
  const ProcessingCancelledException();
}
