import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

final ttsServiceProvider = Provider<TTSService>((ref) {
  return TTSService();
});

/// Converts a podcast script (list of {speaker, text} maps) to a single
/// audio file using the platform's built-in TTS engine.
class TTSService {
  final FlutterTts _tts = FlutterTts();

  /// Synthesises [script] into a WAV file.
  /// Returns the [File] on success, or null if synthesis failed or the platform
  /// does not support file synthesis (e.g. Web, Windows desktop).
  Future<File?> synthesizeScript(List<Map<String, dynamic>> script) async {
    // flutter_tts file synthesis only works on Android/iOS.
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      debugPrint(
          'TTSService: file synthesis is only supported on Android and iOS.');
      return null;
    }

    try {
      // Build a single string for the whole script.
      final buf = StringBuffer();
      for (final line in script) {
        final speaker = line['speaker'] ?? 'A';
        final text = (line['text'] ?? '') as String;
        if (text.isNotEmpty) {
          // Brief pause between turns makes the audio more natural.
          buf.write('Speaker $speaker: $text. ');
        }
      }

      final combined = buf.toString().trim();
      if (combined.isEmpty) return null;

      const fileName = 'study_pod_compiled.wav';

      // Ask flutter_tts to write the file.  On Android the file lands in
      // external storage; on iOS in the temporary directory.
      final result = await _tts.synthesizeToFile(combined, fileName);

      if (result != 1) {
        debugPrint('TTSService: synthesizeToFile returned $result (expected 1).');
        return null;
      }

      // Allow the native side to finish writing before we stat the file.
      await Future<void>.delayed(const Duration(seconds: 3));

      Directory? sourceDir;
      if (Platform.isIOS) {
        sourceDir = await getTemporaryDirectory();
      } else if (Platform.isAndroid) {
        sourceDir = await getExternalStorageDirectory();
      }

      if (sourceDir == null) return null;

      final sourceFile = File('${sourceDir.path}/$fileName');
      if (!await sourceFile.exists()) {
        debugPrint(
            'TTSService: synthesized file not found at ${sourceFile.path}');
        return null;
      }

      // Copy to app documents so just_audio and share_plus can reliably
      // find it across restarts.
      final docDir = await getApplicationDocumentsDirectory();
      final targetFile = File('${docDir.path}/$fileName');
      await sourceFile.copy(targetFile.path);

      debugPrint('TTSService: audio saved to ${targetFile.path}');
      return targetFile;
    } catch (e, stack) {
      debugPrint('TTSService error: $e\n$stack');
      return null;
    }
  }
}
