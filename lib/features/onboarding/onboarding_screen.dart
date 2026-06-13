import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/auth/google_auth_service.dart';
import '../../core/state/app_state.dart';
import '../main/main_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLastPage = _currentPage == 3;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Add a Skip button at the top right
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const MainShell()),
                  );
                },
                child: const Text('Skip for now'),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildPage(
                    context: context,
                    title: 'Welcome to Klassify',
                    subtitle: 'Your offline-first, AI study copilot.',
                    icon: PhosphorIcons.graduationCap(),
                    color: colorScheme.primary,
                  ),
                  _buildPage(
                    context: context,
                    title: 'Absolute Privacy',
                    subtitle: 'Bring Your Own Storage (BYOS). Your PDFs and generated flashcards live strictly in your personal Google Drive and stay fully encrypted.',
                    icon: PhosphorIcons.shieldCheck(),
                    color: colorScheme.secondary,
                  ),
                  _buildAiEngineSelectionPage(context),
                  _buildPage(
                    context: context,
                    title: 'Connect Account',
                    subtitle: 'Link your Google Drive to sync your academic workspace across all your devices, even when offline.',
                    icon: PhosphorIcons.cloudArrowUp(),
                    color: colorScheme.tertiary,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button (hidden on first page)
                  _currentPage > 0 
                    ? TextButton(
                        onPressed: () => _controller.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                        child: const Text('Back', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      )
                    : const SizedBox(width: 64), // Placeholder to keep alignment
                  
                  SmoothPageIndicator(
                    controller: _controller,
                    count: 4,
                    effect: ExpandingDotsEffect(
                      activeDotColor: colorScheme.primary,
                      dotColor: colorScheme.primaryContainer,
                      dotHeight: 8,
                      dotWidth: 8,
                    ),
                  ),
                  
                  // Next or Sign In Button
                  if (isLastPage)
                    Consumer(
                      builder: (context, ref, child) {
                        return FilledButton.icon(
                          onPressed: () async {
                            final authService = ref.read(googleAuthServiceProvider);
                            final success = await authService.signIn();
                            if (success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Successfully connected to Drive!')),
                              );
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => const MainShell()),
                              );
                            }
                          },
                          icon: const Icon(Icons.login_rounded),
                          label: const Text('Sign in'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      }
                    )
                  else
                    TextButton(
                      onPressed: () => _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      child: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage({
    required BuildContext context,
    required String title, 
    required String subtitle, 
    required IconData icon, 
    required Color color,
  }) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
            ),
            child: Icon(icon, size: 80, color: color),
          ),
          const SizedBox(height: 48),
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            subtitle,
            style: theme.textTheme.titleMedium?.copyWith(
              height: 1.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiEngineSelectionPage(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final aiEngine = ref.watch(aiEngineProvider);
        final theme = Theme.of(context);
        
        return Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose Your Brain',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select how Klassify generates your study materials.',
                style: theme.textTheme.titleMedium?.copyWith(
                  height: 1.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 40),
              _buildEngineOption(
                context: context,
                title: 'Cloud AI (Google Gemini)',
                subtitle: 'Instant generation over the internet. Requires a free API Key.',
                icon: PhosphorIcons.cloudLightning(),
                isSelected: aiEngine == AiEngineType.cloud,
                onTap: () => ref.read(aiEngineProvider.notifier).setEngine(AiEngineType.cloud),
              ),
              const SizedBox(height: 16),
              _buildEngineOption(
                context: context,
                title: 'Local AI (Ollama)',
                subtitle: 'Strict privacy. Runs completely offline. Requires manual ~4GB download.',
                icon: PhosphorIcons.hardDrive(),
                isSelected: aiEngine == AiEngineType.local,
                onTap: () => ref.read(aiEngineProvider.notifier).setEngine(AiEngineType.local),
              ),
              
              if (aiEngine == AiEngineType.cloud) ...[
                const SizedBox(height: 32),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Gemini API Key',
                    hintText: 'Paste your key here',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (val) {
                    ref.read(geminiApiKeyProvider.notifier).setKey(val);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEngineOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
