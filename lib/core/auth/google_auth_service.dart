import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:url_launcher/url_launcher.dart';

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService();
});

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GoogleAuthService {
  GoogleSignInAccount? _mobileUser;
  AutoRefreshingAuthClient? _desktopClient;

  GoogleAuthService() {
    if (kIsWeb || !Platform.isWindows) {
      GoogleSignIn.instance.initialize();
      GoogleSignIn.instance.authenticationEvents.listen((event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          _mobileUser = event.user;
        } else if (event is GoogleSignInAuthenticationEventSignOut) {
          _mobileUser = null;
        }
      });
    }
  }

  bool get isSignedIn => (!kIsWeb && Platform.isWindows) 
      ? _desktopClient != null 
      : _mobileUser != null;

  Future<bool> signIn() async {
    if (!kIsWeb && Platform.isWindows) {
      return await _signInWindows();
    }

    try {
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: [
          'https://www.googleapis.com/auth/drive.appdata',
          'https://www.googleapis.com/auth/drive.file',
        ]
      );
      _mobileUser = account;
      return account != null;
    } catch (error) {
      debugPrint('Error signing in: $error');
      return false;
    }
  }

  Future<bool> _signInWindows() async {
    final clientId = ClientId('YOUR_WINDOWS_CLIENT_ID', '');
    final scopes = [
      'https://www.googleapis.com/auth/drive.appdata',
      'https://www.googleapis.com/auth/drive.file',
    ];

    try {
      _desktopClient = await clientViaUserConsent(clientId, scopes, (url) async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          debugPrint('Could not launch browser for OAuth: $url');
        }
      });
      return _desktopClient != null;
    } catch (e) {
      debugPrint('Desktop Auth Error: $e');
      return false;
    }
  }

  Future<bool> signInSilently() async {
    if (!kIsWeb && Platform.isWindows) {
      // clientViaUserConsent doesn't silently refresh well without saved credentials.
      // For MVP, we will require manual sign-in on Windows per session or implement token storage later.
      return _desktopClient != null;
    }

    try {
      final account = await GoogleSignIn.instance.attemptLightweightAuthentication();
      if (account != null) _mobileUser = account;
      return account != null;
    } catch (error) {
      debugPrint('Error signing in silently: $error');
      return false;
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb && Platform.isWindows) {
      _desktopClient?.close();
      _desktopClient = null;
    } else {
      await GoogleSignIn.instance.signOut();
      _mobileUser = null;
    }
  }

  Future<http.Client?> getAuthenticatedClient() async {
    if (!kIsWeb && Platform.isWindows) {
      return _desktopClient; // AutoRefreshingAuthClient is a valid http.Client
    }

    if (_mobileUser == null) return null;

    final authz = await _mobileUser!.authorizationClient.authorizationHeaders([
      'https://www.googleapis.com/auth/drive.appdata',
      'https://www.googleapis.com/auth/drive.file',
    ]);
    
    if (authz == null) return null;
    return GoogleAuthClient(authz);
  }
}
