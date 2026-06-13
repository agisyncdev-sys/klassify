import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'sync_engine.dart';
import '../auth/google_auth_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint("Native called background task: $task");
    
    try {
      final authService = GoogleAuthService();
      // Silently sign in to get the valid auth token for Drive
      final account = await authService.signInSilently();
      
      if (account != null) {
        final syncEngine = SyncEngine(authService);
        // Sync down to merge any Drive updates
        await syncEngine.syncDown();
        // Sync up to push local changes
        await syncEngine.syncUp();
        
        debugPrint("Background sync completed successfully.");
        return Future.value(true);
      } else {
        debugPrint("Background sync failed: User not signed in.");
        return Future.value(false);
      }
    } catch (err) {
      debugPrint("Background sync failed: $err");
      return Future.value(false);
    }
  });
}
