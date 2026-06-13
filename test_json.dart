import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> main() async {
  try {
    print("Testing offline LLM mock response...");
    
    // Simulate what offline LLM client does
    String _getMockResponse(String prompt) {
      if (prompt.contains('podcast scriptwriter')) {
        return jsonEncode([
          {"speaker": "A", "text": "Welcome to today's study pod! Since your local AI isn't running, I'm a fallback simulation."},
          {"speaker": "B", "text": "That's good to know! How do I get the real AI working?"},
          {"speaker": "A", "text": "Just install Ollama and run 'ollama run gemma'. Then Klassify will use your local GPU to generate real scripts from your PDFs completely offline!"}
        ]);
      } else {
        return jsonEncode([
          {"question": "What is the status of the local AI?", "answer": "It is currently not reachable on port 11434."},
          {"question": "How do I fix this?", "answer": "Install Ollama and run the gemma model."},
          {"question": "Will my data stay private?", "answer": "Yes, everything runs 100% locally on your machine once configured."}
        ]);
      }
    }

    String flashcardResp = _getMockResponse("flashcard");
    final List<dynamic> fList = jsonDecode(flashcardResp);
    final flashcards = List<Map<String, dynamic>>.from(fList);
    print("Flashcards parsed successfully! Count: ${flashcards.length}");

    String scriptResp = _getMockResponse("podcast scriptwriter");
    final List<dynamic> sList = jsonDecode(scriptResp);
    final script = List<Map<String, dynamic>>.from(sList);
    print("Script parsed successfully! Count: ${script.length}");
    
  } catch (e) {
    print("Exception caught: $e");
  }
}
