import 'dart:typed_data';
import 'admin_file_reader.dart';

/// Header and extension agreement before Storage upload; this is not clinical review.
class AdminFileValidator {
  static void validate(Uint8List bytes, String name, {required bool pdf}) {
    final lower = name.toLowerCase();
    final maxBytes = (pdf ? 25 : 5) * 1024 * 1024;
    if (bytes.isEmpty) throw const AdminFileReadException('FILE_EMPTY');
    if (bytes.length > maxBytes) {
      throw const AdminFileReadException('FILE_TOO_LARGE');
    }
    bool starts(List<int> magic) =>
        bytes.length >= magic.length &&
        List.generate(magic.length, (i) => bytes[i] == magic[i])
            .every((v) => v);
    final valid = pdf
        ? lower.endsWith('.pdf') && starts([37, 80, 68, 70, 45])
        : (lower.endsWith('.png') &&
                starts([137, 80, 78, 71, 13, 10, 26, 10])) ||
            ((lower.endsWith('.jpg') || lower.endsWith('.jpeg')) &&
                starts([255, 216, 255])) ||
            (lower.endsWith('.webp') &&
                starts([82, 73, 70, 70]) &&
                bytes.length >= 12 &&
                String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP');
    if (!valid) throw const AdminFileReadException('FILE_TYPE_MISMATCH');
  }
}
