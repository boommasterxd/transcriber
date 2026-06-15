import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../service_exceptions.dart';

/// Converts arbitrary audio (m4a, ogg/opus, mp3, …) into the 16 kHz, 16-bit,
/// mono WAV format required by `whisper_kit`'s native core.
class AudioConverter {
  const AudioConverter();

  static const _targetSampleRate = 16000;

  /// Returns a path to a WAV file ready for transcription. If [input] is already
  /// a compliant WAV this still normalizes it to 16 kHz mono to be safe.
  Future<String> toWhisperWav(String input) async {
    final dir = await getTemporaryDirectory();
    final name = '${p.basenameWithoutExtension(input)}_16k.wav';
    final output = p.join(dir.path, 'converted', name);
    await Directory(p.dirname(output)).create(recursive: true);

    final outFile = File(output);
    if (await outFile.exists()) await outFile.delete();

    final cmd = '-y -i "$input" -ar $_targetSampleRate -ac 1 -c:a pcm_s16le "$output"';
    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getAllLogsAsString();
      throw AudioProcessingException('Audio-Konvertierung fehlgeschlagen: ${logs ?? returnCode}');
    }

    // A 16 kHz mono 16-bit WAV is 32 kB per second of audio; anything close to
    // just the 44-byte header means there were no audio samples (a silent or
    // empty recording). Whisper would otherwise return an empty transcript with
    // no error, which is impossible to diagnose — surface it instead.
    final bytes = await outFile.length();
    if (bytes < 16000) {
      throw AudioProcessingException(
        'Die Audiodatei enthält keine hörbaren Daten (${bytes ~/ 1024} KB). '
        'Bitte erneut aufnehmen oder eine andere Datei wählen.',
      );
    }
    return output;
  }
}
