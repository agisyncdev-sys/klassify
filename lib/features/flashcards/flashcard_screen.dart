import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appinio_swiper/appinio_swiper.dart';
import '../../core/state/app_state.dart';

class FlashcardScreen extends ConsumerStatefulWidget {
  const FlashcardScreen({super.key});

  @override
  ConsumerState<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends ConsumerState<FlashcardScreen> {
  final AppinioSwiperController _swiperController = AppinioSwiperController();

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flashcards = ref.watch(activeFlashcardsProvider);
    final isProcessing = ref.watch(isProcessingProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Flashcards', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: flashcards.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isProcessing ? Icons.memory_rounded : Icons.style_rounded,
                            size: 72,
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            isProcessing ? "Extracting Knowledge..." : "No Flashcards Loaded",
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!isProcessing) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Select a document in the Workspace',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                            ),
                          ]
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: AppinioSwiper(
                        key: ValueKey(flashcards.length),
                        controller: _swiperController,
                        cardCount: flashcards.length,
                        onSwipeBegin: (previousIndex, previousDirection, swipeActivity) {
                          HapticFeedback.selectionClick();
                        },
                        onSwipeEnd: (previousIndex, targetIndex, activity) {
                          HapticFeedback.lightImpact();
                        },
                        cardBuilder: (BuildContext context, int index) {
                          return FlipFlashcardWidget(
                            flashcard: flashcards[index],
                          );
                        },
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton.large(
                    heroTag: 'btn_left',
                    onPressed: flashcards.isEmpty ? null : () {
                      HapticFeedback.mediumImpact();
                      _swiperController.swipeLeft();
                    },
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    foregroundColor: Theme.of(context).colorScheme.error,
                    elevation: 2,
                    child: const Icon(Icons.close_rounded, size: 36),
                  ),
                  FloatingActionButton.large(
                    heroTag: 'btn_right',
                    onPressed: flashcards.isEmpty ? null : () {
                      HapticFeedback.mediumImpact();
                      _swiperController.swipeRight();
                    },
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    elevation: 6,
                    child: const Icon(Icons.check_rounded, size: 36),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FlipFlashcardWidget extends StatefulWidget {
  final Map<String, dynamic> flashcard;

  const FlipFlashcardWidget({
    super.key,
    required this.flashcard,
  });

  @override
  State<FlipFlashcardWidget> createState() => _FlipFlashcardWidgetState();
}

class _FlipFlashcardWidgetState extends State<FlipFlashcardWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flipCard() {
    HapticFeedback.lightImpact();
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    _isFront = !_isFront;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flipCard,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * pi;
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateY(angle);

          final isBackVisible = angle > pi / 2;

          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: isBackVisible
                ? Transform(
                    transform: Matrix4.identity()..rotateY(pi),
                    alignment: Alignment.center,
                    child: _buildSide(isFront: false),
                  )
                : _buildSide(isFront: true),
          );
        },
      ),
    );
  }

  Widget _buildSide({required bool isFront}) {
    final title = isFront ? 'Question' : 'Answer';
    final content = isFront ? (widget.flashcard['question'] ?? '') : (widget.flashcard['answer'] ?? '');
    
    return Container(
      decoration: BoxDecoration(
        color: isFront ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isFront 
              ? Theme.of(context).colorScheme.outlineVariant 
              : Theme.of(context).colorScheme.primaryContainer,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isFront 
                      ? Theme.of(context).colorScheme.primaryContainer 
                      : Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  title.toUpperCase(),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isFront ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                content,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: isFront ? FontWeight.w700 : FontWeight.w600,
                  color: isFront ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onPrimaryContainer,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),
              Icon(
                Icons.touch_app_rounded,
                color: isFront 
                    ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3)
                    : Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.3),
                size: 32,
              )
            ],
          ),
        ),
      ),
    );
  }
}
