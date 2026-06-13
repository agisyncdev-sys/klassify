import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../state/app_state.dart';

class HybridLlmClient {
  static const String defaultEndpoint = 'http://127.0.0.1:11434';
  static const String defaultModel = 'gemma';

  final String endpoint;
  final AiEngineType engineType;
  final String geminiApiKey;

  HybridLlmClient({
    this.endpoint = defaultEndpoint,
    required this.engineType,
    required this.geminiApiKey,
  });

  Future<String?> generate(String prompt) async {
    if (engineType == AiEngineType.cloud) {
      return _generateCloud(prompt);
    } else {
      return _generateLocal(prompt);
    }
  }

  Future<String?> _generateCloud(String prompt) async {
    if (geminiApiKey.isEmpty) {
      debugPrint('Gemini API key is empty.');
      return _getMockResponse(prompt);
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: geminiApiKey,
      );

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      
      String? rawResponse = response.text;
      if (rawResponse != null) {
        rawResponse = rawResponse.replaceAll('```json', '').replaceAll('```', '').trim();
        final startIndex = rawResponse.indexOf('[');
        final endIndex = rawResponse.lastIndexOf(']');
        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          rawResponse = rawResponse.substring(startIndex, endIndex + 1);
        }
        return rawResponse;
      }
    } catch (e) {
      debugPrint('Error calling Gemini API: $e');
    }
    return _getMockResponse(prompt);
  }

  Future<String?> _generateLocal(String prompt) async {
    try {
      final url = Uri.parse('$endpoint/api/generate');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': defaultModel,
          'prompt': prompt,
          'stream': false,
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String rawResponse = data['response'] as String;
        
        // Strip out markdown code blocks that LLMs often wrap JSON in
        rawResponse = rawResponse.replaceAll('```json', '').replaceAll('```', '').trim();
        
        // Extract just the JSON array from the response in case the model added conversational text
        final startIndex = rawResponse.indexOf('[');
        final endIndex = rawResponse.lastIndexOf(']');
        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          rawResponse = rawResponse.substring(startIndex, endIndex + 1);
        }
        
        return rawResponse;
      } else {
        debugPrint('Ollama API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error calling offline LLM (Is Ollama running?): $e');
      // If Ollama is not running or fails, return a robust mock response so the UI doesn't break
      return _getMockResponse(prompt);
    }
    return _getMockResponse(prompt);
  }

  String _getMockResponse(String prompt) {
    if (prompt.contains('podcast scriptwriter')) {
      return jsonEncode([
        {"speaker": "A", "text": "Welcome to today's study pod! Since your AI engine isn't responding, I'm a fallback simulation."},
        {"speaker": "B", "text": "That's good to know! How do I fix this?"},
        {"speaker": "A", "text": "If using Local AI, ensure Ollama is installed and running. If using Cloud AI, check your API key in Settings!"}
      ]);
    } else {
      return jsonEncode([
        {"question": "What is the status of the AI?", "answer": "The AI engine is currently unreachable or the API key is missing."},
        {"question": "How do I fix this?", "answer": "Check your API key in Settings, or run Ollama if using Local mode."},
        {"question": "Will my data stay private?", "answer": "Yes, everything is secured either locally or in your personal Drive."}
      ]);
    }
  }
}
