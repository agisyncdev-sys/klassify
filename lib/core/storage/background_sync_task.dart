import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'sync_engine.dart';
import '../auth/google_auth_service.dart';

/// Entry-point called by WorkManager from a background isolate.
/// MUST be a top-level function annotated with @pragma('vm:entry-point').
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('Background task started: $task');

    try {
      final authService = GoogleAuthService();
      final isSignedIn = await authService.signInSilently();

      if (isSignedIn) {
        final syncEngine = SyncEngine(authService);
        await syncEngine.syncDown();
        await syncEngine.syncUp();
        debugPrint('Background sync completed for task: $task');
        return true;
      } else {
        debugPrint('Background sync skipped – user not signed in.');
        // Return true so WorkManager doesn't retry immediately; the next
        // scheduled execution will try again once the user has logged in.
        return true;
      }
    } catch (e, stack) {
      debugPrint('Background sync error: $e\n$stack');
      // Return false to signal WorkManager to retry later.
      return false;
    }
  });
}
