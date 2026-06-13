import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../core/storage/sync_engine.dart';
import '../../core/network/offline_llm_client.dart';
import '../../core/state/app_state.dart';

final flashcardGeneratorProvider = Provider<FlashcardGenerator>((ref) {
  final syncEngine = ref.watch(syncEngineProvider);
  final engineType = ref.watch(aiEngineProvider);
  final apiKey = ref.watch(geminiApiKeyProvider);
  return FlashcardGenerator(syncEngine, engineType, apiKey);
});

class FlashcardGenerator {
  final SyncEngine _syncEngine;
  final AiEngineType _engineType;
  final String _geminiApiKey;
  
  FlashcardGenerator(this._syncEngine, this._engineType, this._geminiApiKey);

  Future<List<Map<String, dynamic>>> generateFlashcards(File pdfFile) async {
    try {
      final offlineLlm = HybridLlmClient(
        engineType: _engineType,
        geminiApiKey: _geminiApiKey,
      );
      
      final prompt = '''
You are an expert tutor. Create a set of 10 concise flashcards based on the provided document text.
Output MUST be a valid JSON array of objects with "question" and "answer" fields.
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
        final List<Map<String, dynamic>> flashcards = List<Map<String, dynamic>>.from(jsonList);
        
        // Save to local sync engine
        await _saveFlashcards(flashcards);
        
        return flashcards;
      }
    } catch (e) {
      debugPrint('Error generating flashcards: $e');
    }
    return [];
  }

  Future<void> _saveFlashcards(List<Map<String, dynamic>> newFlashcards) async {
    final currentData = await _syncEngine.readLocalData() ?? {'flashcards': []};
    final List<dynamic> existingCards = currentData['flashcards'] ?? [];
    
    existingCards.addAll(newFlashcards);
    currentData['flashcards'] = existingCards;
    
    await _syncEngine.writeLocalData(currentData);
  }
}
