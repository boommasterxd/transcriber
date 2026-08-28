import '../../data/models/audio_ownership.dart';

export '../../data/models/audio_ownership.dart';

/// An audio file accompanied by explicit ownership information.
final class ManagedAudioFile {
  const ManagedAudioFile({required this.path, required this.ownership});

  final String path;
  final AudioOwnership ownership;
}
