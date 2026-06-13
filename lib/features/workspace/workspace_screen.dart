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
  // Re-fetch whenever a document is saved (invalidated after processing).
  final engine = ref.watch(syncEngineProvider);
  return engine.loadAllDocuments();
});

class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {

  // ---------------------------------------------------------------------------
  // Processing pipeline
  // ---------------------------------------------------------------------------

  Future<void> _processDocument() async {
    final documentService = ref.read(documentServiceProvider);
    final flashcardGen = ref.read(flashcardGeneratorProvider);
    final scriptGen = ref.read(scriptGeneratorServiceProvider);
    final tts = ref.read(ttsServiceProvider);
    final syncEngine = ref.read(syncEngineProvider);

    // Step 0 – pick / scan PDF
    final file = await documentService.scanDocument();
    if (file == null || !mounted) return;

    ref.read(isProcessingProvider.notifier).setProcessing(true);

    try {
      final docId = DateTime.now().millisecondsSinceEpoch.toString();
      final appDir = await getApplicationDocumentsDirectory();
      final docDir = Directory('${appDir.path}/$docId');
      await docDir.create(recursive: true);

      // Step 1 – flashcards
      _setStatus('Generating flashcards…');
      final flashcards = await flashcardGen.generateFlashcards(file);
      final fcFile = File('${docDir.path}/flashcards.json');
      await fcFile.writeAsString(jsonEncode(flashcards));
      ref.read(activeFlashcardsProvider.notifier).setFlashcards(flashcards);

      // Step 2 – podcast script
      _setStatus('Writing podcast script…');
      final script = await scriptGen.generateScript(file);

      // Step 3 – TTS audio (mobile only; gracefully skipped on desktop)
      _setStatus('Synthesizing audio…');
      File? audioFile;
      if (script.isNotEmpty) {
        audioFile = await tts.synthesizeScript(script);
      }

      // Step 4 – persist metadata
      final rawName = file.path.split(Platform.pathSeparator).last;
      final cleanName = rawName
          .replaceAll(RegExp(r'^Scan_\d+_?'), 'Scan ')
          .replaceAll('.pdf', '');

      final doc = StudyDocument(
        id: docId,
        title: cleanName.trim().isEmpty ? 'Document $docId' : cleanName.trim(),
        createdAt: DateTime.now(),
        pdfPath: file.path,
        flashcardsPath: fcFile.path,
        audioPath: audioFile?.path,
      );

      await syncEngine.saveStudyDocument(doc);
      ref.read(activeDocumentProvider.notifier).setDocument(doc);
      ref.invalidate(documentsProvider);

      _setStatus('Done!');
      _showSnack('Study materials generated successfully!');
    } catch (e, stack) {
      debugPrint('WorkspaceScreen._processDocument error: $e\n$stack');
      _showSnack('Error: $e');
    } finally {
      if (mounted) {
        ref.read(isProcessingProvider.notifier).setProcessing(false);
        ref.read(processingStatusProvider.notifier).setStatus('');
      }
    }
  }

  void _setStatus(String s) {
    if (mounted) {
      ref.read(processingStatusProvider.notifier).setStatus(s);
    }
  }

  void _showSnack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // ---------------------------------------------------------------------------
  // Load existing document
  // ---------------------------------------------------------------------------

  Future<void> _loadDocument(StudyDocument doc) async {
    ref.read(activeDocumentProvider.notifier).setDocument(doc);

    if (doc.flashcardsPath != null) {
      final file = File(doc.flashcardsPath!);
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          final decoded = jsonDecode(content) as List<dynamic>;
          ref
              .read(activeFlashcardsProvider.notifier)
              .setFlashcards(List<Map<String, dynamic>>.from(decoded));
        } catch (e) {
          debugPrint('WorkspaceScreen._loadDocument parse error: $e');
        }
      }
    }

    _showSnack('Loaded "${doc.title}"');
  }

  // ---------------------------------------------------------------------------
  // Delete document
  // ---------------------------------------------------------------------------

  Future<void> _deleteDocument(StudyDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text(
            '"${doc.title}" and its study materials will be removed from this device.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Remove physical files
    for (final path in [doc.pdfPath, doc.flashcardsPath, doc.audioPath]) {
      if (path != null) {
        final f = File(path);
        if (await f.exists()) await f.delete();
      }
    }

    await ref.read(syncEngineProvider).deleteStudyDocument(doc.id);

    // Clear active state if this doc was active
    if (ref.read(activeDocumentProvider)?.id == doc.id) {
      ref.read(activeDocumentProvider.notifier).setDocument(null);
      ref.read(activeFlashcardsProvider.notifier).setFlashcards([]);
    }

    ref.invalidate(documentsProvider);
    _showSnack('"${doc.title}" deleted.');
  }

  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------

  LinearGradient _gradientFor(String seed) {
    final h = seed.hashCode.abs();
    final c1 = HSLColor.fromAHSL(1, (h % 360).toDouble(), 0.7, 0.6).toColor();
    final c2 =
        HSLColor.fromAHSL(1, ((h * 137) % 360).toDouble(), 0.8, 0.45).toColor();
    return LinearGradient(
      colors: [c1, c2],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isProcessing = ref.watch(isProcessingProvider);
    final statusText = ref.watch(processingStatusProvider);
    final docsAsync = ref.watch(documentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workspace',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.gear()),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: isProcessing
          ? _ProcessingView(statusText: statusText)
          : docsAsync.when(
              data: (docs) =>
                  docs.isEmpty ? _EmptyLibraryView() : _DocumentGrid(
                      docs: docs,
                      onTap: _loadDocument,
                      onDelete: _deleteDocument,
                      gradientFor: _gradientFor,
                    ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) =>
                  Center(child: Text('Error loading documents: $err')),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isProcessing
            ? null
            : () {
                HapticFeedback.lightImpact();
                _processDocument();
              },
        icon: isProcessing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.document_scanner_rounded),
        label: Text(isProcessing ? 'Processing…' : 'Scan PDF'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets (keep build() lean)
// ---------------------------------------------------------------------------

class _ProcessingView extends StatelessWidget {
  final String statusText;
  const _ProcessingView({required this.statusText});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Shimmer.fromColors(
            baseColor: cs.primaryContainer,
            highlightColor: cs.onPrimaryContainer.withValues(alpha: 0.1),
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            statusText,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text('Generating AI study materials…',
              style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _EmptyLibraryView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_rounded,
              size: 72, color: cs.surfaceContainerHighest),
          const SizedBox(height: 24),
          Text('Your Library is Empty',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  )),
          const SizedBox(height: 8),
          Text('Tap + to scan a PDF and start learning',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  )),
        ],
      ),
    );
  }
}

class _DocumentGrid extends ConsumerWidget {
  final List<StudyDocument> docs;
  final Future<void> Function(StudyDocument) onTap;
  final Future<void> Function(StudyDocument) onDelete;
  final LinearGradient Function(String) gradientFor;

  const _DocumentGrid({
    required this.docs,
    required this.onTap,
    required this.onDelete,
    required this.gradientFor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeId = ref.watch(activeDocumentProvider)?.id;

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 0.75,
      ),
      itemCount: docs.length,
      itemBuilder: (ctx, i) {
        final doc = docs[i];
        final isActive = doc.id == activeId;

        return Card(
          elevation: isActive ? 12 : 2,
          shadowColor: isActive
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: isActive
                ? BorderSide(
                    color: Theme.of(context).colorScheme.primary, width: 3)
                : BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap(doc);
            },
            onLongPress: () {
              HapticFeedback.mediumImpact();
              onDelete(doc);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(gradient: gradientFor(doc.title)),
                    child: Center(
                      child: Icon(Icons.auto_stories_rounded,
                          size: 40,
                          color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    color: Theme.of(context).colorScheme.surface,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          doc.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          '${doc.createdAt.year}-'
                          '${doc.createdAt.month.toString().padLeft(2, '0')}-'
                          '${doc.createdAt.day.toString().padLeft(2, '0')}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
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
  }
}
