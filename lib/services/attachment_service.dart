import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persists receipt/attachment files inside the app documents directory so
/// they survive cache eviction and the picker's temporary paths.
class AttachmentService {
  AttachmentService._();

  static final AttachmentService instance = AttachmentService._();

  static const String _folderName = 'receipts';

  Future<Directory> _folder() async {
    final base = await getApplicationDocumentsDirectory();
    final folder = Directory('${base.path}/$_folderName');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder;
  }

  /// Copies [sourcePath] into the app documents folder and returns the new
  /// absolute path. When [sourcePath] is already inside the app folder the
  /// original path is returned unchanged.
  Future<String> persist(String sourcePath) async {
    if (sourcePath.trim().isEmpty) return '';
    final folder = await _folder();
    final normalizedSource = File(sourcePath).absolute.path;
    if (normalizedSource.startsWith(folder.absolute.path)) {
      return normalizedSource;
    }
    final source = File(sourcePath);
    if (!await source.exists()) {
      return sourcePath;
    }
    final extension = _extensionOf(sourcePath);
    final name =
        'receipt_${DateTime.now().microsecondsSinceEpoch}$extension';
    final destination = '${folder.path}${Platform.pathSeparator}$name';
    await source.copy(destination);
    return destination;
  }

  Future<void> deleteIfManaged(String path) async {
    if (path.trim().isEmpty) return;
    final folder = await _folder();
    final normalized = File(path).absolute.path;
    if (!normalized.startsWith(folder.absolute.path)) return;
    final file = File(normalized);
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot < path.length - 6) return '.jpg';
    return path.substring(dot);
  }
}
