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
  late AppinioSwiperController _swiper;

  @override
  void initState() {
    super.initState();
    _swiper = AppinioSwiperController();
  }

  @override
  void dispose() {
    _swiper.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flashcards = ref.watch(activeFlashcardsProvider);
    final isProcessing = ref.watch(isProcessingProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Flashcards',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (flashcards.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Chip(
                label: Text('${flashcards.length} cards'),
                backgroundColor: cs.primaryContainer,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: flashcards.isEmpty
                  ? _EmptyState(isProcessing: isProcessing)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: AppinioSwiper(
                        key: ValueKey(flashcards.length),
                        controller: _swiper,
                        cardCount: flashcards.length,
                        onSwipeBegin: (_, __, ___) =>
                            HapticFeedback.selectionClick(),
                        onSwipeEnd: (_, __, ___) =>
                            HapticFeedback.lightImpact(),
                        cardBuilder: (_, index) => FlipFlashcardWidget(
                          flashcard: flashcards[index],
                        ),
                      ),
                    ),
            ),
            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ActionFab(
                    heroTag: 'btn_left',
                    icon: Icons.close_rounded,
                    color: cs.error,
                    bg: cs.errorContainer,
                    enabled: flashcards.isNotEmpty,
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _swiper.swipeLeft();
                    },
                  ),
                  _ActionFab(
                    heroTag: 'btn_right',
                    icon: Icons.check_rounded,
                    color: cs.onPrimary,
                    bg: cs.primary,
                    enabled: flashcards.isNotEmpty,
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _swiper.swipeRight();
                    },
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

class _EmptyState extends StatelessWidget {
  final bool isProcessing;
  const _EmptyState({required this.isProcessing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isProcessing ? Icons.memory_rounded : Icons.style_rounded,
            size: 72,
            color: cs.surfaceContainerHighest,
          ),
          const SizedBox(height: 24),
          Text(
            isProcessing ? 'Extracting Knowledge…' : 'No Flashcards Loaded',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.bold),
          ),
          if (!isProcessing) ...[
            const SizedBox(height: 8),
            Text(
              'Select a document in the Workspace',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionFab extends StatelessWidget {
  final String heroTag;
  final IconData icon;
  final Color color;
  final Color bg;
  final bool enabled;
  final VoidCallback onPressed;

  const _ActionFab({
    required this.heroTag,
    required this.icon,
    required this.color,
    required this.bg,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.large(
      heroTag: heroTag,
      onPressed: enabled ? onPressed : null,
      backgroundColor: enabled ? bg : Theme.of(context).colorScheme.surfaceContainerHighest,
      foregroundColor: enabled ? color : Theme.of(context).colorScheme.onSurfaceVariant,
      elevation: 2,
      child: Icon(icon, size: 36),
    );
  }
}

// ---------------------------------------------------------------------------
// Flip card widget
// ---------------------------------------------------------------------------

class FlipFlashcardWidget extends StatefulWidget {
  final Map<String, dynamic> flashcard;
  const FlipFlashcardWidget({super.key, required this.flashcard});

  @override
  State<FlipFlashcardWidget> createState() => _FlipFlashcardWidgetState();
}

class _FlipFlashcardWidgetState extends State<FlipFlashcardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
    _anim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _flip() {
    HapticFeedback.lightImpact();
    if (_isFront) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
    setState(() => _isFront = !_isFront);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) {
          final angle = _anim.value * pi;
          final showBack = angle > pi / 2;

          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle);

          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: showBack
                ? Transform(
                    transform: Matrix4.identity()..rotateY(pi),
                    alignment: Alignment.center,
                    child: _CardFace(
                        flashcard: widget.flashcard, isFront: false),
                  )
                : _CardFace(flashcard: widget.flashcard, isFront: true),
          );
        },
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  final Map<String, dynamic> flashcard;
  final bool isFront;
  const _CardFace({required this.flashcard, required this.isFront});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = isFront ? 'QUESTION' : 'ANSWER';
    final content = isFront
        ? (flashcard['question'] ?? '').toString()
        : (flashcard['answer'] ?? '').toString();

    return Container(
      decoration: BoxDecoration(
        color: isFront ? cs.surface : cs.primaryContainer,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isFront ? cs.outlineVariant : cs.primary.withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isFront
                      ? cs.primaryContainer
                      : cs.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: isFront
                            ? cs.primary
                            : cs.onPrimaryContainer,
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
                      fontWeight:
                          isFront ? FontWeight.w700 : FontWeight.w600,
                      color: isFront
                          ? cs.onSurface
                          : cs.onPrimaryContainer,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 36),
              Icon(
                Icons.touch_app_rounded,
                size: 28,
                color: (isFront ? cs.onSurfaceVariant : cs.onPrimaryContainer)
                    .withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
