import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../core/storage/sync_engine.dart';
import '../../core/network/offline_llm_client.dart';
import '../../core/state/app_state.dart';

final scriptGeneratorServiceProvider = Provider<ScriptGeneratorService>((ref) {
  final syncEngine = ref.watch(syncEngineProvider);
  final engineType = ref.watch(aiEngineProvider);
  final apiKey = ref.watch(geminiApiKeyProvider);
  return ScriptGeneratorService(syncEngine, engineType, apiKey);
});

class ScriptGeneratorService {
  final SyncEngine _syncEngine;
  final AiEngineType _engineType;
  final String _geminiApiKey;
  
  ScriptGeneratorService(this._syncEngine, this._engineType, this._geminiApiKey);

  Future<List<Map<String, dynamic>>> generateScript(File pdfFile) async {
    try {
      final offlineLlm = HybridLlmClient(
        engineType: _engineType,
        geminiApiKey: _geminiApiKey,
      );

      final prompt = '''
You are an expert podcast scriptwriter. Create a conversational 2-person script based on the provided document.
Speaker A is the expert, Speaker B is the student.
Output MUST be a valid JSON array of objects with "speaker" and "text" fields.
''';

      // Extract real text from the PDF binary using syncfusion
      final PdfDocument document = PdfDocument(inputBytes: await pdfFile.readAsBytes());
      String documentText = PdfTextExtractor(document).extractText();
      document.dispose();
      
      // Prevent overwhelmingly large prompts for local LLMs by limiting text
      if (documentText.length > 15000) {
        documentText = documentText.substring(0, 15000);
      }
      final fullPrompt = '$prompt\n\nDocument Text:\n$documentText';

      final responseText = await offlineLlm.generate(fullPrompt);
      if (responseText != null) {
        final List<dynamic> jsonList = jsonDecode(responseText);
        final List<Map<String, dynamic>> script = List<Map<String, dynamic>>.from(jsonList);
        
        await _saveScriptToLocal(script);
        return script;
      }
    } catch (e) {
      debugPrint('Error generating script: $e');
    }
    return [];
  }

  Future<void> _saveScriptToLocal(List<Map<String, dynamic>> script) async {
    final currentData = await _syncEngine.readLocalData() ?? {};
    currentData['study_pod_script'] = script;
    await _syncEngine.writeLocalData(currentData);
  }
}
