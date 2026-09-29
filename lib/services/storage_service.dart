// storage_service.dart — upload de PDFs para Firebase Storage
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'admin/admin_file_validator.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  static FirebaseStorage get _storage => FirebaseStorage.instance;

  /// Upload de PDF para Firebase Storage.
  /// Retorna a URL pública de download.
  static Future<({String url, String path})> uploadGuidePdf({
    required Uint8List bytes,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    AdminFileValidator.validate(bytes, fileName, pdf: true);
    // Sanitiza nome do arquivo
    final safe = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final ts = sha256.convert(bytes).toString();
    final path = 'clinical_guides/${ts}_$safe';

    final ref = _storage.ref().child(path);
    final meta = SettableMetadata(contentType: 'application/pdf');
    final task = ref.putData(bytes, meta);

    final subscription = onProgress == null
        ? null
        : task.snapshotEvents.listen((snap) {
            if (snap.totalBytes > 0)
              onProgress(snap.bytesTransferred / snap.totalBytes);
          });
    try {
      await task;
    } finally {
      await subscription?.cancel();
    }

    final url = await ref.getDownloadURL();
    return (url: url, path: path);
  }

  /// Deleta um PDF do Storage pelo path armazenado.
  static Future<void> deleteGuidePdf(String storagePath) async {
    try {
      if (storagePath.isEmpty) return;
      await _storage.ref().child(storagePath).delete();
    } catch (_) {}
  }

  /// Upload da capa editorial (JPG/PNG/WebP) para Firebase Storage.
  static Future<({String url, String path})> uploadGuideImage({
    required Uint8List bytes,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    AdminFileValidator.validate(bytes, fileName, pdf: false);
    final safe = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final ts = sha256.convert(bytes).toString();
    final path = 'clinical_guides/covers/${ts}_$safe';

    final lower = safe.toLowerCase();
    final contentType = lower.endsWith('.png')
        ? 'image/png'
        : lower.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';

    final ref = _storage.ref().child(path);
    final task = ref.putData(bytes, SettableMetadata(contentType: contentType));

    final subscription = onProgress == null
        ? null
        : task.snapshotEvents.listen((snap) {
            if (snap.totalBytes > 0)
              onProgress(snap.bytesTransferred / snap.totalBytes);
          });
    try {
      await task;
    } finally {
      await subscription?.cancel();
    }

    final url = await ref.getDownloadURL();
    return (url: url, path: path);
  }
}
