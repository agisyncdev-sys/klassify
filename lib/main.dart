import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'core/state/app_state.dart';
import 'core/storage/background_sync_task.dart';
import 'core/auth/google_auth_service.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/main/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prevent network font fetching from stalling the first frame on desktop.
  GoogleFonts.config.allowRuntimeFetching = false;

  final prefs = await SharedPreferences.getInstance();

  // Background sync is only available on mobile.
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      'klassify_sync',
      'sync_drive_data',
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const KlassifyApp(),
    ),
  );
}

class KlassifyApp extends ConsumerWidget {
  const KlassifyApp({super.key});

  static TextTheme _textTheme(TextTheme base) {
    try {
      return GoogleFonts.plusJakartaSansTextTheme(base);
    } catch (_) {
      return base;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Klassify',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.light,
          surface: const Color(0xFFF8FAFC),
        ),
        textTheme: _textTheme(ThemeData.light().textTheme),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
          surface: const Color(0xFF0F172A),
          surfaceContainerHighest: const Color(0xFF1E293B),
        ),
        textTheme: _textTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const _AuthGate(),
    );
  }
}

/// Checks for a cached Google session and routes to the appropriate screen.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.read(googleAuthServiceProvider);

    return FutureBuilder<bool>(
      future: authService.signInSilently(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          debugPrint('_AuthGate error: ${snap.error}');
        }
        return snap.data == true ? const MainShell() : const OnboardingScreen();
      },
    );
  }
}
