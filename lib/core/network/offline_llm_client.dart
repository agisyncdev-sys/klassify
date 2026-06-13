import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../state/app_state.dart';

/// Unified LLM client that dispatches to either Google Gemini (cloud) or
/// a locally-running Ollama instance (local/offline).
class HybridLlmClient {
  static const String _defaultOllamaEndpoint = 'http://127.0.0.1:11434';
  static const String _defaultOllamaModel = 'gemma';
  // Gemini Flash is free-tier and fast; bump to 'gemini-1.5-pro' for quality.
  static const String _geminiModel = 'gemini-1.5-flash';

  final String ollamaEndpoint;
  final AiEngineType engineType;
  final String geminiApiKey;

  const HybridLlmClient({
    this.ollamaEndpoint = _defaultOllamaEndpoint,
    required this.engineType,
    required this.geminiApiKey,
  });

  Future<String?> generate(String prompt) async {
    return engineType == AiEngineType.cloud
        ? _generateCloud(prompt)
        : _generateLocal(prompt);
  }

  // ---------------------------------------------------------------------------
  // Cloud (Gemini)
  // ---------------------------------------------------------------------------

  Future<String?> _generateCloud(String prompt) async {
    if (geminiApiKey.trim().isEmpty) {
      debugPrint('HybridLlmClient: Gemini API key is empty – returning mock.');
      return _mockResponse(prompt);
    }

    try {
      final model = GenerativeModel(
        model: _geminiModel,
        apiKey: geminiApiKey.trim(),
        // Instruct the model to always return raw JSON, not markdown-wrapped.
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
      );

      final response =
          await model.generateContent([Content.text(prompt)]);

      String? raw = response.text;
      if (raw != null) {
        return _extractJsonArray(raw);
      }
    } catch (e) {
      debugPrint('HybridLlmClient (cloud) error: $e');
    }
    return _mockResponse(prompt);
  }

  // ---------------------------------------------------------------------------
  // Local (Ollama)
  // ---------------------------------------------------------------------------

  Future<String?> _generateLocal(String prompt) async {
    try {
      final url = Uri.parse('$ollamaEndpoint/api/generate');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': _defaultOllamaModel,
              'prompt': prompt,
              'stream': false,
              'format': 'json', // Ask Ollama to enforce JSON output
            }),
          )
          .timeout(const Duration(seconds: 180));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final raw = data['response'] as String? ?? '';
        return _extractJsonArray(raw);
      } else {
        debugPrint(
            'HybridLlmClient (local) HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint(
          'HybridLlmClient (local) error (is Ollama running?): $e');
    }
    return _mockResponse(prompt);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Strips markdown fences and extracts the first JSON array from [raw].
  String _extractJsonArray(String raw) {
    // Strip common markdown wrappers
    raw = raw
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    final start = raw.indexOf('[');
    final end = raw.lastIndexOf(']');
    if (start != -1 && end != -1 && end > start) {
      return raw.substring(start, end + 1);
    }
    return raw;
  }

  /// Returns a minimal valid mock JSON array so the UI never crashes when the
  /// AI backend is unavailable.
  String _mockResponse(String prompt) {
    final isPodcast = prompt.contains('podcast scriptwriter');
    if (isPodcast) {
      return jsonEncode([
        {
          'speaker': 'A',
          'text':
              "Welcome to today's study pod! The AI engine is currently unreachable.",
        },
        {
          'speaker': 'B',
          'text': 'How do I fix that?',
        },
        {
          'speaker': 'A',
          'text':
              'If using Local AI, make sure Ollama is installed and running. '
                  'If using Cloud AI, check that your Gemini API key is correct in Settings.',
        },
      ]);
    }
    return jsonEncode([
      {
        'question': 'Why is the AI not responding?',
        'answer':
            'The AI engine is unreachable. Check your API key or Ollama status.',
      },
      {
        'question': 'Will my data stay private?',
        'answer':
            'Yes – everything is stored locally or in your personal Google Drive.',
      },
      {
        'question': 'How do I switch AI engines?',
        'answer':
            'Go to Settings and choose between Cloud AI (Gemini) and Local AI (Ollama).',
      },
    ]);
  }
}
