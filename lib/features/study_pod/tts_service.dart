import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

final ttsServiceProvider = Provider<TTSService>((ref) {
  return TTSService();
});

class TTSService {
  final FlutterTts _flutterTts = FlutterTts();

  Future<File?> synthesizeScript(List<Map<String, dynamic>> script) async {
    try {
      final StringBuffer combinedText = StringBuffer();
      for (var line in script) {
        final String speaker = line['speaker'] ?? 'A';
        final String text = line['text'] ?? '';
        combinedText.writeln('Speaker $speaker: $text. ');
      }

      final fileName = 'study_pod_compiled.wav';
      // flutter_tts writes to the OS specific cache/external directory
      final result = await _flutterTts.synthesizeToFile(combinedText.toString(), fileName);
      
      if (result == 1) {
        // Add a buffer delay to ensure native async file writing completes
        await Future.delayed(const Duration(seconds: 3));
        
        Directory? dir;
        if (Platform.isIOS) {
          dir = await getTemporaryDirectory();
        } else if (Platform.isAndroid) {
          dir = await getExternalStorageDirectory();
        }
        
        if (dir != null) {
          final file = File('${dir.path}/$fileName');
          if (await file.exists()) {
             // Copy to a consistent location so share_plus and just_audio can find it easily
             final docDir = await getApplicationDocumentsDirectory();
             final targetFile = File('${docDir.path}/$fileName');
             await file.copy(targetFile.path);
             return targetFile;
          }
        }
      }
    } catch (e) {
      debugPrint('Error synthesizing script locally: $e');
    }
    return null;
  }
}
