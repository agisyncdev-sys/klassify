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

class SyncEngine {
  final GoogleAuthService _authService;
  static const String _fileName = 'student_data.json';

  SyncEngine(this._authService);

  Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<drive.DriveApi?> _getDriveApi() async {
    final client = await _authService.getAuthenticatedClient();
    if (client == null) return null;
    return drive.DriveApi(client);
  }

  Future<void> syncDown() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return;

    try {
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_fileName'",
        $fields: 'files(id, name)',
      );

      final files = fileList.files;
      if (files != null && files.isNotEmpty) {
        final fileId = files.first.id!;
        final media = await driveApi.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
        
        final localFile = await _localFile;
        final sink = localFile.openWrite();
        await media.stream.pipe(sink);
        await sink.close();
        debugPrint('Synced $_fileName from Drive AppData.');
      }
    } catch (e) {
      debugPrint('Error syncing down: $e');
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
        q: "name = '$_fileName'",
        $fields: 'files(id, name)',
      );

      final files = fileList.files;
      final fileContent = await localFile.readAsBytes();
      final media = drive.Media(Stream.value(fileContent), fileContent.length);

      if (files != null && files.isNotEmpty) {
        final fileId = files.first.id!;
        await driveApi.files.update(
          drive.File(),
          fileId,
          uploadMedia: media,
        );
        debugPrint('Updated $_fileName in Drive AppData.');
      } else {
        final driveFile = drive.File()
          ..name = _fileName
          ..parents = ['appDataFolder'];
        await driveApi.files.create(
          driveFile,
          uploadMedia: media,
        );
        debugPrint('Created $_fileName in Drive AppData.');
      }
    } catch (e) {
      debugPrint('Error syncing up: $e');
    }
  }

  Future<Map<String, dynamic>?> readLocalData() async {
    final file = await _localFile;
    if (!await file.exists()) return null;
    try {
      final contents = await file.readAsString();
      return jsonDecode(contents) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error reading local data: $e');
      return null;
    }
  }

  Future<void> writeLocalData(Map<String, dynamic> data) async {
    try {
      final file = await _localFile;
      await file.writeAsString(jsonEncode(data));
      await syncUp();
    } catch (e) {
      debugPrint('Error writing local data: $e');
    }
  }

  Future<void> recordAccessTime(String fileId, String localPath) async {
    final data = await readLocalData() ?? {};
    final metadata = data['files_metadata'] as Map<String, dynamic>? ?? {};
    
    metadata[fileId] = {
      'lastAccessed': DateTime.now().toIso8601String(),
      'localPath': localPath,
    };
    
    data['files_metadata'] = metadata;
    await writeLocalData(data);
    await enforceLRUPolicy();
  }

  Future<void> enforceLRUPolicy() async {
    final data = await readLocalData() ?? {};
    final metadata = data['files_metadata'] as Map<String, dynamic>? ?? {};
    
    if (metadata.length <= 5) return;

    final entries = metadata.entries.toList()
      ..sort((a, b) {
        final timeA = DateTime.parse(a.value['lastAccessed'] as String);
        final timeB = DateTime.parse(b.value['lastAccessed'] as String);
        return timeB.compareTo(timeA); // newest first
      });

    // Prune everything after index 4
    for (int i = 5; i < entries.length; i++) {
      final localPath = entries[i].value['localPath'] as String?;
      if (localPath != null) {
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
          debugPrint('Evicted physical file to save space: $localPath');
        }
      }
    }
  }

  Future<List<StudyDocument>> loadAllDocuments() async {
    final data = await readLocalData() ?? {};
    final documentsJson = data['documents'] as List<dynamic>? ?? [];
    return documentsJson.map((e) => StudyDocument.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveStudyDocument(StudyDocument doc) async {
    final data = await readLocalData() ?? {};
    final documentsJson = data['documents'] as List<dynamic>? ?? [];
    
    final index = documentsJson.indexWhere((e) => (e as Map)['id'] == doc.id);
    if (index >= 0) {
      documentsJson[index] = doc.toJson();
    } else {
      documentsJson.add(doc.toJson());
    }
    
    data['documents'] = documentsJson;
    await writeLocalData(data);
  }
}
