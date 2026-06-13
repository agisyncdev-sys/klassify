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

/// Wraps Google Sign-In auth headers into a standard http.Client so that
/// googleapis can use it transparently.
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request..headers.addAll(_headers));
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

class GoogleAuthService {
  GoogleSignInAccount? _mobileUser;
  AutoRefreshingAuthClient? _desktopClient;

  // Scopes needed for Drive.appdata + Drive.file access
  static const List<String> _driveScopes = [
    'https://www.googleapis.com/auth/drive.appdata',
    'https://www.googleapis.com/auth/drive.file',
  ];

  GoogleAuthService() {
    // GoogleSignIn is only meaningful on mobile / web – not Windows desktop
    if (!_isWindowsDesktop) {
      try {
        GoogleSignIn.instance.initialize();
        GoogleSignIn.instance.authenticationEvents.listen((event) {
          if (event is GoogleSignInAuthenticationEventSignIn) {
            _mobileUser = event.user;
          } else if (event is GoogleSignInAuthenticationEventSignOut) {
            _mobileUser = null;
          }
        });
      } catch (e) {
        debugPrint('GoogleSignIn init error: $e');
      }
    }
  }

  bool get _isWindowsDesktop => !kIsWeb && Platform.isWindows;

  bool get isSignedIn =>
      _isWindowsDesktop ? _desktopClient != null : _mobileUser != null;

  /// Full interactive sign-in.
  Future<bool> signIn() async {
    if (_isWindowsDesktop) return _signInWindows();

    try {
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: _driveScopes,
      );
      _mobileUser = account;
      return account != null;
    } catch (e) {
      debugPrint('signIn error: $e');
      return false;
    }
  }

  Future<bool> _signInWindows() async {
    // IMPORTANT: replace 'YOUR_WINDOWS_CLIENT_ID' with your real OAuth 2.0
    // Desktop client ID from the Google Cloud console before shipping.
    const windowsClientId = 'YOUR_WINDOWS_CLIENT_ID';
    if (windowsClientId == 'YOUR_WINDOWS_CLIENT_ID') {
      debugPrint(
          'Windows OAuth not configured. Set windowsClientId in google_auth_service.dart.');
      return false;
    }

    final clientId = ClientId(windowsClientId, '');
    try {
      _desktopClient =
          await clientViaUserConsent(clientId, _driveScopes, (url) async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          debugPrint('Could not launch browser for OAuth: $url');
        }
      });
      return _desktopClient != null;
    } catch (e) {
      debugPrint('Windows desktop auth error: $e');
      return false;
    }
  }

  /// Silent sign-in – returns true if a cached session was restored.
  Future<bool> signInSilently() async {
    if (_isWindowsDesktop) {
      // Windows sessions are not persisted across restarts in this MVP.
      return _desktopClient != null;
    }

    try {
      final account =
          await GoogleSignIn.instance.attemptLightweightAuthentication();
      if (account != null) _mobileUser = account;
      return account != null;
    } catch (e) {
      debugPrint('signInSilently error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    if (_isWindowsDesktop) {
      _desktopClient?.close();
      _desktopClient = null;
    } else {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (e) {
        debugPrint('signOut error: $e');
      }
      _mobileUser = null;
    }
  }

  /// Returns an authenticated [http.Client] ready for googleapis calls,
  /// or null if the user is not signed in.
  Future<http.Client?> getAuthenticatedClient() async {
    if (_isWindowsDesktop) {
      return _desktopClient; // AutoRefreshingAuthClient extends http.Client
    }

    if (_mobileUser == null) return null;

    try {
      final headers = await _mobileUser!.authorizationClient
          .authorizationHeaders(_driveScopes);
      if (headers == null) return null;
      return GoogleAuthClient(headers);
    } catch (e) {
      debugPrint('getAuthenticatedClient error: $e');
      return null;
    }
  }
}
