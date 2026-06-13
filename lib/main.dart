import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workmanager/workmanager.dart';
import 'core/storage/background_sync_task.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'core/state/app_state.dart';

import 'features/onboarding/onboarding_screen.dart';
import 'features/main/main_shell.dart';
import 'core/auth/google_auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Prevent Google Fonts from making network requests that can
  // block the first frame on desktop, keeping the window invisible.
  GoogleFonts.config.allowRuntimeFetching = false;

  final prefs = await SharedPreferences.getInstance();

  if (!kIsWeb && !Platform.isWindows) {
    Workmanager().initialize(
      callbackDispatcher,
    );
    Workmanager().registerPeriodicTask(
      "1",
      "sync_drive_data",
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
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

  static TextTheme _buildTextTheme(TextTheme base) {
    try {
      return GoogleFonts.plusJakartaSansTextTheme(base);
    } catch (_) {
      return base; // Fall back to default if fonts aren't bundled
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
        textTheme: _buildTextTheme(ThemeData.light().textTheme),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
          surface: const Color(0xFF0F172A),
          surfaceContainerHighest: const Color(0xFF1E293B),
        ),
        textTheme: _buildTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.read(googleAuthServiceProvider);

    return FutureBuilder<bool>(
      future: authService.signInSilently(),
      builder: (context, snapshot) {
        // Show loading spinner while checking auth
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If there was an error, skip to onboarding
        if (snapshot.hasError) {
          debugPrint('AuthGate error: ${snapshot.error}');
          return const OnboardingScreen();
        }

        final isSignedIn = snapshot.data == true;

        if (isSignedIn) {
          return const MainShell();
        } else {
          return const OnboardingScreen();
        }
      },
    );
  }
}

