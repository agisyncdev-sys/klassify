import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../core/storage/sync_engine.dart';
import '../../core/network/offline_llm_client.dart';
import '../../core/state/app_state.dart';

final scriptGeneratorServiceProvider = Provider<ScriptGeneratorService>((ref) {
  return ScriptGeneratorService(
    syncEngine: ref.watch(syncEngineProvider),
    engineType: ref.watch(aiEngineProvider),
    geminiApiKey: ref.watch(geminiApiKeyProvider),
  );
});

class ScriptGeneratorService {
  final SyncEngine _syncEngine;
  final AiEngineType _engineType;
  final String _geminiApiKey;

  static const int _maxDocumentChars = 15000;

  ScriptGeneratorService({
    required SyncEngine syncEngine,
    required AiEngineType engineType,
    required String geminiApiKey,
  })  : _syncEngine = syncEngine,
        _engineType = engineType,
        _geminiApiKey = geminiApiKey;

  Future<List<Map<String, dynamic>>> generateScript(File pdfFile) async {
    try {
      // 1. Extract text from PDF
      final bytes = await pdfFile.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      String text = PdfTextExtractor(document).extractText();
      document.dispose();

      if (text.trim().isEmpty) {
        debugPrint('ScriptGeneratorService: No text extracted from PDF.');
        return _fallbackScript();
      }

      if (text.length > _maxDocumentChars) {
        text = text.substring(0, _maxDocumentChars);
      }

      // 2. Build prompt
      final prompt = '''
You are an expert podcast scriptwriter. Create a natural, conversational 2-person study podcast script based on the document text below.

SPEAKERS:
- Speaker A: the expert who explains concepts clearly.
- Speaker B: the curious student who asks follow-up questions.

RULES:
- Output ONLY a valid JSON array – no markdown, no preamble, no trailing text.
- Each element must have exactly two string fields: "speaker" (value "A" or "B") and "text".
- Aim for 12–16 exchanges. Keep each line under 3 sentences.

Document text:
$text
''';

      // 3. Call LLM
      final llm = HybridLlmClient(
        engineType: _engineType,
        geminiApiKey: _geminiApiKey,
      );

      final raw = await llm.generate(prompt);
      if (raw == null || raw.isEmpty) return _fallbackScript();

      // 4. Parse & validate
      final decoded = jsonDecode(raw) as List<dynamic>;
      final lines = decoded
          .whereType<Map<String, dynamic>>()
          .where((l) =>
              (l['speaker'] == 'A' || l['speaker'] == 'B') &&
              (l['text'] as String?)?.isNotEmpty == true)
          .toList();

      if (lines.isEmpty) return _fallbackScript();

      // 5. Persist
      await _persistScript(lines);
      return lines;
    } catch (e, stack) {
      debugPrint('ScriptGeneratorService error: $e\n$stack');
      return _fallbackScript();
    }
  }

  Future<void> _persistScript(List<Map<String, dynamic>> script) async {
    try {
      final data = await _syncEngine.readLocalData() ?? {};
      data['study_pod_script'] = script;
      await _syncEngine.writeLocalData(data);
    } catch (e) {
      debugPrint('ScriptGeneratorService._persistScript error: $e');
    }
  }

  List<Map<String, dynamic>> _fallbackScript() => [
        {
          'speaker': 'A',
          'text':
              "Welcome to Study Pod! It looks like the AI engine wasn't able to generate a script.",
        },
        {
          'speaker': 'B',
          'text': 'How can I fix that?',
        },
        {
          'speaker': 'A',
          'text':
              'Head to Settings. If you chose Cloud AI, make sure your Gemini API key is entered. '
                  'If you chose Local AI, ensure Ollama is installed and running on your machine.',
        },
      ];
}
