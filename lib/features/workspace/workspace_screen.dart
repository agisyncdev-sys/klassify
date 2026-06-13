import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/state/app_state.dart';
import '../../core/models/study_document.dart';
import '../../core/storage/sync_engine.dart';
import 'document_service.dart';
import '../flashcards/flashcard_generator.dart';
import '../study_pod/script_generator_service.dart';
import '../study_pod/tts_service.dart';
import '../settings/settings_screen.dart';

final documentsProvider = FutureProvider<List<StudyDocument>>((ref) async {
  final engine = ref.watch(syncEngineProvider);
  return engine.loadAllDocuments();
});

class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  
  Future<void> _processDocument() async {
    final documentService = ref.read(documentServiceProvider);
    final flashcardGenerator = ref.read(flashcardGeneratorProvider);
    final scriptGenerator = ref.read(scriptGeneratorServiceProvider);
    final ttsService = ref.read(ttsServiceProvider);
    final syncEngine = ref.read(syncEngineProvider);

    // Pick and scan PDF
    final file = await documentService.scanDocument();
    if (file == null) return;

    // Start background processing
    ref.read(isProcessingProvider.notifier).setProcessing(true);
    
    try {
      final docId = DateTime.now().millisecondsSinceEpoch.toString();
      final dir = await getApplicationDocumentsDirectory();
      final docDir = Directory('${dir.path}/$docId');
      await docDir.create(recursive: true);

      // 1. Generate Flashcards
      ref.read(processingStatusProvider.notifier).setStatus('Generating flashcards...');
      final flashcards = await flashcardGenerator.generateFlashcards(file);
      final flashcardsFile = File('${docDir.path}/flashcards.json');
      await flashcardsFile.writeAsString(jsonEncode(flashcards));
      ref.read(activeFlashcardsProvider.notifier).setFlashcards(flashcards);

      // 2. Generate Podcast Script
      ref.read(processingStatusProvider.notifier).setStatus('Writing podcast script...');
      final script = await scriptGenerator.generateScript(file);

      // 3. Compile Audio
      ref.read(processingStatusProvider.notifier).setStatus('Synthesizing audio...');
      File? audioFile;
      if (script.isNotEmpty) {
        audioFile = await ttsService.synthesizeScript(script);
      }

      // 4. Save StudyDocument
      final studyDoc = StudyDocument(
        id: docId,
        title: file.path.split(Platform.pathSeparator).last.replaceAll(RegExp(r'^Scan_[0-9]+_?'), 'Scan '), // Clean up the name a bit
        createdAt: DateTime.now(),
        pdfPath: file.path,
        flashcardsPath: flashcardsFile.path,
        audioPath: audioFile?.path,
      );
      
      await syncEngine.saveStudyDocument(studyDoc);
      ref.read(activeDocumentProvider.notifier).setDocument(studyDoc);
      
      // Refresh the grid
      ref.invalidate(documentsProvider);

      ref.read(processingStatusProvider.notifier).setStatus('Finished!');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Study materials generated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      ref.read(isProcessingProvider.notifier).setProcessing(false);
      ref.read(processingStatusProvider.notifier).setStatus('');
    }
  }

  void _loadDocument(StudyDocument doc) async {
    ref.read(activeDocumentProvider.notifier).setDocument(doc);
    if (doc.flashcardsPath != null) {
      final file = File(doc.flashcardsPath!);
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        final flashcards = List<Map<String, dynamic>>.from(jsonList);
        ref.read(activeFlashcardsProvider.notifier).setFlashcards(flashcards);
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loaded ${doc.title}')),
      );
    }
  }

  LinearGradient _generateGradient(String seed) {
    int hash = seed.hashCode.abs();
    final color1 = HSLColor.fromAHSL(1.0, (hash % 360).toDouble(), 0.7, 0.6).toColor();
    final color2 = HSLColor.fromAHSL(1.0, ((hash * 2) % 360).toDouble(), 0.8, 0.5).toColor();
    return LinearGradient(
      colors: [color1, color2],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isProcessing = ref.watch(isProcessingProvider);
    final statusText = ref.watch(processingStatusProvider);
    final documentsAsync = ref.watch(documentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workspace', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.gear()),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Shimmer.fromColors(
                    baseColor: Theme.of(context).colorScheme.primaryContainer,
                    highlightColor: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.1),
                    child: Container(
                      width: 120,
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    statusText,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Generating AI study materials...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : documentsAsync.when(
              data: (documents) {
                if (documents.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 72,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Your Library is Empty',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to scan a PDF and start learning',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    final doc = documents[index];
                    final isActive = ref.watch(activeDocumentProvider)?.id == doc.id;
                    
                    return Card(
                      elevation: isActive ? 12 : 2,
                      shadowColor: isActive ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4) : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: isActive 
                            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 3)
                            : BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _loadDocument(doc);
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: _generateGradient(doc.title),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.auto_stories_rounded,
                                    size: 40,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Container(
                                color: Theme.of(context).colorScheme.surface,
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      doc.title,
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${doc.createdAt.year}-${doc.createdAt.month.toString().padLeft(2, '0')}-${doc.createdAt.day.toString().padLeft(2, '0')}',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error loading documents: $err')),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isProcessing ? null : () {
          HapticFeedback.lightImpact();
          _processDocument();
        },
        icon: isProcessing 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) 
            : const Icon(Icons.document_scanner_rounded),
        label: Text(isProcessing ? 'Processing...' : 'Scan PDF'),
      ),
    );
  }
}

// test
