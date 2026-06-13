import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:file_picker/file_picker.dart';
import '../../core/auth/google_auth_service.dart';

final documentServiceProvider = Provider<DocumentService>((ref) {
  final authService = ref.watch(googleAuthServiceProvider);
  return DocumentService(authService);
});

class DocumentService {
  final GoogleAuthService _authService;
  
  DocumentService(this._authService);

  Future<drive.DriveApi?> _getDriveApi() async {
    final client = await _authService.getAuthenticatedClient();
    if (client == null) return null;
    return drive.DriveApi(client);
  }

  Future<String?> _getOrCreateKlassifyFolder(drive.DriveApi driveApi) async {
    final folderName = 'Klassify Materials';
    try {
      final fileList = await driveApi.files.list(
        q: "name = '$folderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
        spaces: 'drive',
        $fields: 'files(id, name)',
      );

      final files = fileList.files;
      if (files != null && files.isNotEmpty) {
        return files.first.id;
      }

      final folder = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder';
      
      final createdFolder = await driveApi.files.create(folder);
      return createdFolder.id;
    } catch (e) {
      debugPrint('Error getting/creating folder: $e');
      return null;
    }
  }

  Future<File?> scanDocument() async {
    if (kIsWeb) {
      debugPrint('Document scanning is not supported on Web.');
      return null;
    }
    
    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        // Desktop fallback: select a PDF via standard file picker
        FilePickerResult? result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );

        if (result != null && result.files.single.path != null) {
          final pdfFile = File(result.files.single.path!);
          await _uploadPdfToDrive(pdfFile);
          return pdfFile;
        }
        return null;
      }

      DocumentScannerOptions documentOptions = DocumentScannerOptions(
        documentFormats: {DocumentFormat.pdf},
        mode: ScannerMode.full,
        isGalleryImport: true,
        pageLimit: 20,
      );

      final documentScanner = DocumentScanner(options: documentOptions);
      DocumentScanningResult result = await documentScanner.scanDocument();
      
      final pdfPath = result.pdf?.uri;
      if (pdfPath != null) {
        final pdfFile = File(pdfPath);
        await _uploadPdfToDrive(pdfFile);
        return pdfFile;
      }
    } catch (e) {
      debugPrint('Error scanning document: $e');
    }
    return null;
  }

  Future<void> _uploadPdfToDrive(File file) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return;

    final folderId = await _getOrCreateKlassifyFolder(driveApi);
    if (folderId == null) return;

    try {
      final fileName = 'Scan_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final driveFile = drive.File()
        ..name = fileName
        ..parents = [folderId]
        ..mimeType = 'application/pdf';

      final fileContent = await file.readAsBytes();
      final media = drive.Media(Stream.value(fileContent), fileContent.length);

      await driveApi.files.create(driveFile, uploadMedia: media);
      debugPrint('Uploaded $fileName to Klassify Materials folder in Drive.');
    } catch (e) {
      debugPrint('Error uploading PDF to Drive: $e');
    }
  }
}
