import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class AdminFileReadException implements Exception {
  const AdminFileReadException(this.reasonCode);
  final String reasonCode;
}

/// Bounded reader for web/native pickers. Never dereferences browser blob paths.
class AdminFileReader {
  static Future<Uint8List> read(PlatformFile file,
      {required int maxBytes}) async {
    if (file.size > maxBytes) {
      throw const AdminFileReadException('FILE_TOO_LARGE');
    }
    final data = file.bytes;
    if (data != null) {
      if (data.isEmpty) throw const AdminFileReadException('FILE_EMPTY');
      if (data.length > maxBytes) {
        throw const AdminFileReadException('FILE_TOO_LARGE');
      }
      return data;
    }
    final stream = file.readStream;
    if (stream == null) {
      throw const AdminFileReadException('FILE_READ_UNAVAILABLE');
    }
    final builder = BytesBuilder(copy: false);
    try {
      await for (final chunk in stream.timeout(const Duration(seconds: 30))) {
        if (builder.length + chunk.length > maxBytes) {
          throw const AdminFileReadException('FILE_TOO_LARGE');
        }
        builder.add(chunk);
      }
    } on AdminFileReadException {
      rethrow;
    } catch (_) {
      throw const AdminFileReadException('FILE_READ_FAILED');
    }
    if (builder.isEmpty) throw const AdminFileReadException('FILE_EMPTY');
    return builder.takeBytes();
  }
}
