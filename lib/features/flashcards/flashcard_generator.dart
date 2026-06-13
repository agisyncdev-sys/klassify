import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../core/storage/sync_engine.dart';
import '../../core/network/offline_llm_client.dart';
import '../../core/state/app_state.dart';

final flashcardGeneratorProvider = Provider<FlashcardGenerator>((ref) {
  return FlashcardGenerator(
    syncEngine: ref.watch(syncEngineProvider),
    engineType: ref.watch(aiEngineProvider),
    geminiApiKey: ref.watch(geminiApiKeyProvider),
  );
});

class FlashcardGenerator {
  final SyncEngine _syncEngine;
  final AiEngineType _engineType;
  final String _geminiApiKey;

  // Limit input to avoid overwhelming local LLMs or hitting Gemini context.
  static const int _maxDocumentChars = 15000;
  static const int _flashcardCount = 10;

  FlashcardGenerator({
    required SyncEngine syncEngine,
    required AiEngineType engineType,
    required String geminiApiKey,
  })  : _syncEngine = syncEngine,
        _engineType = engineType,
        _geminiApiKey = geminiApiKey;

  Future<List<Map<String, dynamic>>> generateFlashcards(File pdfFile) async {
    try {
      // 1. Extract text from PDF
      final bytes = await pdfFile.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      String text = PdfTextExtractor(document).extractText();
      document.dispose();

      if (text.trim().isEmpty) {
        debugPrint('FlashcardGenerator: No text extracted from PDF.');
        return _fallbackCards();
      }

      if (text.length > _maxDocumentChars) {
        text = text.substring(0, _maxDocumentChars);
      }

      // 2. Build prompt
      final prompt = '''
You are an expert tutor. Create exactly $_flashcardCount concise flashcards based on the document text below.

RULES:
- Output ONLY a valid JSON array – no markdown, no preamble, no trailing text.
- Each element must have exactly two string fields: "question" and "answer".
- Questions should test understanding, not just recall.

Document text:
$text
''';

      // 3. Call LLM
      final llm = HybridLlmClient(
        engineType: _engineType,
        geminiApiKey: _geminiApiKey,
      );

      final raw = await llm.generate(prompt);
      if (raw == null || raw.isEmpty) return _fallbackCards();

      // 4. Parse
      final decoded = jsonDecode(raw) as List<dynamic>;
      final cards = decoded
          .whereType<Map<String, dynamic>>()
          .where((c) =>
              c.containsKey('question') && c.containsKey('answer'))
          .toList();

      if (cards.isEmpty) return _fallbackCards();

      // 5. Persist
      await _persistCards(cards);
      return cards;
    } catch (e, stack) {
      debugPrint('FlashcardGenerator error: $e\n$stack');
      return _fallbackCards();
    }
  }

  Future<void> _persistCards(List<Map<String, dynamic>> newCards) async {
    try {
      final data = await _syncEngine.readLocalData() ?? {};
      final existing =
          List<dynamic>.from(data['flashcards'] ?? []);
      existing.addAll(newCards);
      data['flashcards'] = existing;
      await _syncEngine.writeLocalData(data);
    } catch (e) {
      debugPrint('FlashcardGenerator._persistCards error: $e');
    }
  }

  List<Map<String, dynamic>> _fallbackCards() => [
        {
          'question': 'Could not generate flashcards – what should I check?',
          'answer':
              'Ensure your AI engine is configured. Cloud AI needs a Gemini API key in Settings; Local AI needs Ollama running on port 11434.',
        },
      ];
}
