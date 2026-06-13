import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import '../auth/google_auth_service.dart';
import '../models/study_document.dart';

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final authService = ref.watch(googleAuthServiceProvider);
  return SyncEngine(authService);
});

/// Handles reading/writing the canonical JSON data file both locally and to
/// Google Drive appDataFolder (for seamless cross-device sync).
class SyncEngine {
  final GoogleAuthService _authService;

  static const String _dataFileName = 'student_data.json';
  static const int _maxLocalDocuments = 5; // LRU eviction threshold

  SyncEngine(this._authService);

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<File> get _localFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_dataFileName');
  }

  Future<drive.DriveApi?> _getDriveApi() async {
    final client = await _authService.getAuthenticatedClient();
    if (client == null) return null;
    return drive.DriveApi(client);
  }

  // ---------------------------------------------------------------------------
  // Local read / write
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> readLocalData() async {
    final file = await _localFile;
    if (!await file.exists()) return null;
    try {
      final contents = await file.readAsString();
      if (contents.trim().isEmpty) return null;
      return jsonDecode(contents) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('SyncEngine.readLocalData error: $e');
      return null;
    }
  }

  Future<void> writeLocalData(Map<String, dynamic> data) async {
    try {
      final file = await _localFile;
      await file.writeAsString(jsonEncode(data));
      // Fire-and-forget Drive upload; don't block the UI.
      syncUp().catchError(
          (e) => debugPrint('SyncEngine.syncUp background error: $e'));
    } catch (e) {
      debugPrint('SyncEngine.writeLocalData error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Drive sync
  // ---------------------------------------------------------------------------

  Future<void> syncDown() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return;

    try {
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_dataFileName'",
        $fields: 'files(id, name)',
      );

      final files = fileList.files;
      if (files == null || files.isEmpty) return;

      final fileId = files.first.id!;
      final media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final localFile = await _localFile;
      final sink = localFile.openWrite();
      await media.stream.pipe(sink);
      await sink.flush();
      await sink.close();
      debugPrint('SyncEngine: synced $_dataFileName down from Drive.');
    } catch (e) {
      debugPrint('SyncEngine.syncDown error: $e');
    }
  }

  Future<void> syncUp() async {
    final localFile = await _localFile;
    if (!await localFile.exists()) return;

    final driveApi = await _getDriveApi();
    if (driveApi == null) return;

    try {
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_dataFileName'",
        $fields: 'files(id, name)',
      );

      final files = fileList.files;
      final bytes = await localFile.readAsBytes();
      final media = drive.Media(Stream.value(bytes), bytes.length,
          contentType: 'application/json');

      if (files != null && files.isNotEmpty) {
        await driveApi.files.update(
          drive.File(),
          files.first.id!,
          uploadMedia: media,
        );
        debugPrint('SyncEngine: updated $_dataFileName in Drive.');
      } else {
        final driveFile = drive.File()
          ..name = _dataFileName
          ..parents = ['appDataFolder'];
        await driveApi.files.create(driveFile, uploadMedia: media);
        debugPrint('SyncEngine: created $_dataFileName in Drive.');
      }
    } catch (e) {
      debugPrint('SyncEngine.syncUp error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Document management
  // ---------------------------------------------------------------------------

  Future<List<StudyDocument>> loadAllDocuments() async {
    final data = await readLocalData() ?? {};
    final list = data['documents'] as List<dynamic>? ?? [];
    try {
      return list
          .map((e) => StudyDocument.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('SyncEngine.loadAllDocuments parse error: $e');
      return [];
    }
  }

  Future<void> saveStudyDocument(StudyDocument doc) async {
    final data = await readLocalData() ?? {};
    final list = List<dynamic>.from(data['documents'] ?? []);

    final idx = list.indexWhere(
        (e) => (e as Map<String, dynamic>)['id'] == doc.id);
    if (idx >= 0) {
      list[idx] = doc.toJson();
    } else {
      list.add(doc.toJson());
    }

    data['documents'] = list;
    await writeLocalData(data);
    await enforceLRUPolicy();
  }

  Future<void> deleteStudyDocument(String docId) async {
    final data = await readLocalData() ?? {};
    final list = List<dynamic>.from(data['documents'] ?? []);
    list.removeWhere(
        (e) => (e as Map<String, dynamic>)['id'] == docId);
    data['documents'] = list;
    await writeLocalData(data);
  }

  // ---------------------------------------------------------------------------
  // File metadata & LRU eviction
  // ---------------------------------------------------------------------------

  Future<void> recordAccessTime(String fileId, String localPath) async {
    final data = await readLocalData() ?? {};
    final meta =
        Map<String, dynamic>.from(data['files_metadata'] ?? {});

    meta[fileId] = {
      'lastAccessed': DateTime.now().toIso8601String(),
      'localPath': localPath,
    };
    data['files_metadata'] = meta;
    await writeLocalData(data);
    await enforceLRUPolicy();
  }

  Future<void> enforceLRUPolicy() async {
    final data = await readLocalData() ?? {};
    final meta =
        Map<String, dynamic>.from(data['files_metadata'] ?? {});

    if (meta.length <= _maxLocalDocuments) return;

    final sorted = meta.entries.toList()
      ..sort((a, b) {
        final ta = DateTime.parse(
            (a.value as Map<String, dynamic>)['lastAccessed'] as String);
        final tb = DateTime.parse(
            (b.value as Map<String, dynamic>)['lastAccessed'] as String);
        return tb.compareTo(ta); // newest first
      });

    for (int i = _maxLocalDocuments; i < sorted.length; i++) {
      final lp =
          (sorted[i].value as Map<String, dynamic>)['localPath'] as String?;
      if (lp != null) {
        final f = File(lp);
        if (await f.exists()) {
          await f.delete();
          debugPrint('SyncEngine: LRU evicted $lp');
        }
      }
      meta.remove(sorted[i].key);
    }

    data['files_metadata'] = meta;
    await writeLocalData(data);
  }
}
