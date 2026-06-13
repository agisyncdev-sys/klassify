# Klassify

**AI-powered offline-first study app** – scan a PDF, get AI-generated flashcards and a podcast-style audio summary, synced to your personal Google Drive.

---

## Features

| Feature | Description |
|---|---|
| 📄 **Document Scanning** | ML Kit document scanner (Android/iOS) or file picker (desktop) |
| 🃏 **Flashcards** | AI-generated Q&A cards with 3-D flip animation |
| 🎙️ **Study Pod** | 2-speaker podcast script → TTS audio playback |
| ☁️ **Google Drive Sync** | All data lives in your personal Drive (appDataFolder) |
| 🔒 **Privacy-first** | Local AI mode via Ollama; no data sent to third parties |

---

## Getting Started

### 1. Clone & install

```bash
git clone https://github.com/agisyncdev-sys/klassify.git
cd klassify
flutter pub get
```

### 2. Configure Google Sign-In

1. Create a project in [Google Cloud Console](https://console.cloud.google.com/).
2. Enable **Google Drive API**.
3. Create OAuth 2.0 credentials for your target platform(s).
4. For Android, place `google-services.json` in `android/app/`.
5. For iOS, add the reversed client ID to `ios/Runner/Info.plist`.
6. For Windows desktop, set `windowsClientId` in `lib/core/auth/google_auth_service.dart`.

### 3. Choose an AI engine

**Cloud (recommended for quick start)**
1. Get a free key from [Google AI Studio](https://aistudio.google.com/app/apikey).
2. Paste it in the **Settings** screen inside the app.

**Local (maximum privacy)**
1. Install [Ollama](https://ollama.ai).
2. Pull the Gemma model: `ollama pull gemma`
3. Make sure Ollama is running before opening the app.

### 4. Run

```bash
flutter run
```

---

## Architecture

```
lib/
  core/
    auth/          Google auth + http client wrapper
    models/        StudyDocument data model
    network/       HybridLlmClient (Gemini / Ollama)
    state/         Riverpod providers
    storage/       SyncEngine (local JSON ↔ Drive) + WorkManager task
  features/
    flashcards/    FlashcardGenerator + FlashcardScreen
    main/          Bottom-nav shell
    onboarding/    First-run flow + AI engine picker
    settings/      Settings screen
    study_pod/     ScriptGeneratorService + TTSService + StudyPodScreen
    workspace/     DocumentService + WorkspaceScreen
```

---

## Known Limitations

- TTS file synthesis (`flutter_tts`) only works on Android and iOS, not Windows/macOS/Web.
- `google_mlkit_document_scanner` only runs on Android. iOS and desktop fall back to a standard file picker.
- Windows desktop OAuth requires a manually configured client ID.
- The Syncfusion PDF package requires a valid license for commercial use beyond the community edition limit.

---

## License

Private – all rights reserved. See `LICENSE` for details.
