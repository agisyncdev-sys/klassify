import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:file_picker/file_picker.dart';
import '../../core/auth/google_auth_service.dart';

final documentServiceProvider = Provider<DocumentService>((ref) {
  return DocumentService(ref.watch(googleAuthServiceProvider));
});

class DocumentService {
  final GoogleAuthService _authService;

  DocumentService(this._authService);

  // ---------------------------------------------------------------------------
  // Drive helpers
  // ---------------------------------------------------------------------------

  Future<drive.DriveApi?> _getDriveApi() async {
    final client = await _authService.getAuthenticatedClient();
    if (client == null) return null;
    return drive.DriveApi(client);
  }

  Future<String?> _getOrCreateFolder(drive.DriveApi api) async {
    const folderName = 'Klassify Materials';
    try {
      final list = await api.files.list(
        q: "name = '$folderName' and "
            "mimeType = 'application/vnd.google-apps.folder' and "
            "trashed = false",
        spaces: 'drive',
        $fields: 'files(id)',
      );
      if (list.files?.isNotEmpty == true) {
        return list.files!.first.id;
      }
      final folder = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder';
      final created = await api.files.create(folder);
      return created.id;
    } catch (e) {
      debugPrint('DocumentService._getOrCreateFolder error: $e');
      return null;
    }
  }

  Future<void> _uploadToDrive(File file) async {
    try {
      final api = await _getDriveApi();
      if (api == null) {
        debugPrint(
            'DocumentService: Drive not available – skipping upload.');
        return;
      }
      final folderId = await _getOrCreateFolder(api);
      if (folderId == null) return;

      final name =
          'Scan_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final driveFile = drive.File()
        ..name = name
        ..parents = [folderId]
        ..mimeType = 'application/pdf';

      final bytes = await file.readAsBytes();
      final media =
          drive.Media(Stream.value(bytes), bytes.length,
              contentType: 'application/pdf');

      await api.files.create(driveFile, uploadMedia: media);
      debugPrint('DocumentService: uploaded $name to Drive.');
    } catch (e) {
      // Upload is best-effort; never crash the main flow.
      debugPrint('DocumentService._uploadToDrive error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Launches the ML Kit document scanner on mobile, or a file picker on
  /// desktop.  Returns the resulting PDF [File], or null if the user cancelled
  /// or an error occurred.
  Future<File?> scanDocument() async {
    if (kIsWeb) {
      debugPrint('DocumentService: scanning is not supported on Web.');
      return null;
    }

    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        return _pickFileDesktop();
      }
      return _scanMobile();
    } catch (e) {
      debugPrint('DocumentService.scanDocument error: $e');
      return null;
    }
  }

  Future<File?> _pickFileDesktop() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: false,
    );
    if (result?.files.single.path == null) return null;
    final file = File(result!.files.single.path!);
    await _uploadToDrive(file);
    return file;
  }

  Future<File?> _scanMobile() async {
    final options = DocumentScannerOptions(
      documentFormats: {DocumentFormat.pdf},
      mode: ScannerMode.full,
      isGalleryImport: true,
      pageLimit: 20,
    );

    final scanner = DocumentScanner(options: options);
    DocumentScanningResult result;
    try {
      result = await scanner.scanDocument();
    } finally {
      scanner.close();
    }

    final pdfUri = result.pdf?.uri;
    if (pdfUri == null) return null;

    final file = File(pdfUri);
    if (!await file.exists()) return null;

    await _uploadToDrive(file);
    return file;
  }
}
