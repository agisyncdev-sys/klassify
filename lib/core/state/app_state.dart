import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/study_document.dart';

class ActiveFlashcardsNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() => [];
  
  void setFlashcards(List<Map<String, dynamic>> flashcards) {
    state = flashcards;
  }
}

final activeFlashcardsProvider = NotifierProvider<ActiveFlashcardsNotifier, List<Map<String, dynamic>>>(() {
  return ActiveFlashcardsNotifier();
});

class IsProcessingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  
  void setProcessing(bool value) {
    state = value;
  }
}

final isProcessingProvider = NotifierProvider<IsProcessingNotifier, bool>(() {
  return IsProcessingNotifier();
});

class ProcessingStatusNotifier extends Notifier<String> {
  @override
  String build() => '';
  
  void setStatus(String value) {
    state = value;
  }
}

final processingStatusProvider = NotifierProvider<ProcessingStatusNotifier, String>(() {
  return ProcessingStatusNotifier();
});

class ActiveDocumentNotifier extends Notifier<StudyDocument?> {
  @override
  StudyDocument? build() => null;
  
  void setDocument(StudyDocument? doc) {
    state = doc;
  }
}

final activeDocumentProvider = NotifierProvider<ActiveDocumentNotifier, StudyDocument?>(() {
  return ActiveDocumentNotifier();
});

// Settings & Preferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(); // Initialized in main.dart
});

enum AiEngineType { local, cloud }

class AiEngineNotifier extends Notifier<AiEngineType> {
  static const _key = 'ai_engine_type';
  
  @override
  AiEngineType build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final val = prefs.getString(_key);
    return val == 'cloud' ? AiEngineType.cloud : AiEngineType.local;
  }
  
  void setEngine(AiEngineType type) {
    state = type;
    ref.read(sharedPreferencesProvider).setString(_key, type.name);
  }
}

final aiEngineProvider = NotifierProvider<AiEngineNotifier, AiEngineType>(() {
  return AiEngineNotifier();
});

class GeminiApiKeyNotifier extends Notifier<String> {
  static const _key = 'gemini_api_key';
  
  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString(_key) ?? '';
  }
  
  void setKey(String key) {
    state = key;
    ref.read(sharedPreferencesProvider).setString(_key, key);
  }
}

final geminiApiKeyProvider = NotifierProvider<GeminiApiKeyNotifier, String>(() {
  return GeminiApiKeyNotifier();
});
