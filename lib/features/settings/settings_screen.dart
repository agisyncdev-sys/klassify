import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/state/app_state.dart';
import '../../core/auth/google_auth_service.dart';
import '../onboarding/onboarding_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _keyCtrl;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _keyCtrl = TextEditingController(text: ref.read(geminiApiKeyProvider));
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            'You will be signed out of Google Drive. Your local data will remain.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(googleAuthServiceProvider).signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiEngine = ref.watch(aiEngineProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // --- AI Engine ---
          _SectionHeader(label: 'AI Engine'),
          const SizedBox(height: 12),
          _EngineCard(
            title: 'Local AI (Ollama)',
            subtitle:
                'Maximum privacy. Runs fully offline. Requires Ollama + the Gemma model (~4 GB).',
            icon: PhosphorIcons.hardDrive(),
            isSelected: aiEngine == AiEngineType.local,
            onTap: () =>
                ref.read(aiEngineProvider.notifier).setEngine(AiEngineType.local),
          ),
          const SizedBox(height: 12),
          _EngineCard(
            title: 'Cloud AI (Google Gemini)',
            subtitle: 'Fast generation via the internet. Requires a free API key.',
            icon: PhosphorIcons.cloudLightning(),
            isSelected: aiEngine == AiEngineType.cloud,
            onTap: () => ref
                .read(aiEngineProvider.notifier)
                .setEngine(AiEngineType.cloud),
          ),

          if (aiEngine == AiEngineType.cloud) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gemini API Key',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _keyCtrl,
                    obscureText: _obscureKey,
                    decoration: InputDecoration(
                      hintText: 'Paste your key here',
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureKey
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded),
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey),
                      ),
                    ),
                    onChanged: (v) =>
                        ref.read(geminiApiKeyProvider.notifier).setKey(v),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => launchUrl(
                        Uri.parse('https://aistudio.google.com/app/apikey'),
                        mode: LaunchMode.externalApplication),
                    child: Text(
                      'Get a free key from Google AI Studio →',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // --- Account ---
          _SectionHeader(label: 'Account'),
          const SizedBox(height: 12),
          ListTile(
            leading: Icon(PhosphorIcons.signOut(),
                color: theme.colorScheme.error),
            title: Text('Sign out of Google',
                style: TextStyle(color: theme.colorScheme.error)),
            subtitle: const Text('You will need to sign in again to sync.'),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            tileColor: theme.colorScheme.errorContainer.withValues(alpha: 0.15),
            onTap: _signOut,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
    );
  }
}

class _EngineCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _EngineCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? cs.primaryContainer.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 32,
                color: isSelected ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? cs.primary : cs.onSurface,
                          )),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: cs.primary),
          ],
        ),
      ),
    );
  }
}
