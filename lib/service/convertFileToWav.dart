import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';

/// Converts any audio or video file to a WAV file (LINEAR16, mono, 16kHz).
Future<String> convertFileToWav(String inputPath) async {
  // Determine the output path.
  final outputPath = inputPath.replaceFirst(
      RegExp(r'\.[^.]+$', caseSensitive: false), '_converted.wav');

  // -y: Overwrite output files without asking.
  // -i: Input file.
  // -vn: Ignore any video streams (if the input is a video file).
  // -ac 1: Set number of audio channels to 1 (mono).
  // -ar 16000: Set the audio sample rate to 16000 Hz.
  // -sample_fmt s16: Set the sample format to 16-bit PCM (LINEAR16).
  final command =
      '-y -i "$inputPath" -vn -ac 1 -ar 16000 -sample_fmt s16 "$outputPath"';

  final session = await FFmpegKit.execute(command);
  final returnCode = await session.getReturnCode();

  if (ReturnCode.isSuccess(returnCode)) {
    print('Conversion succeeded: $outputPath');
    return outputPath;
  } else {
    final output = await session.getOutput();
    print('Conversion failed with return code $returnCode: $output');
    throw Exception('Failed to convert file to WAV');
  }
}
