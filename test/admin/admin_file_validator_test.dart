import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/admin/admin_file_validator.dart';

void main() {
  test('existing allowed PDF/image formats agree with headers', () {
    for (final item in <(String, List<int>, bool)>[
      ('a.pdf', [37, 80, 68, 70, 45], true),
      ('a.png', [137, 80, 78, 71, 13, 10, 26, 10], false),
      ('a.jpg', [255, 216, 255], false),
      ('a.webp', [82, 73, 70, 70, 0, 0, 0, 0, 87, 69, 66, 80], false)
    ]) {
      expect(
          () => AdminFileValidator.validate(
              Uint8List.fromList(item.$2), item.$1,
              pdf: item.$3),
          returnsNormally);
    }
  });
  test('extension/header mismatch and empty file rejected', () {
    expect(
        () => AdminFileValidator.validate(Uint8List.fromList([1, 2]), 'a.pdf',
            pdf: true),
        throwsException);
    expect(() => AdminFileValidator.validate(Uint8List(0), 'a.png', pdf: false),
        throwsException);
    expect(
        () => AdminFileValidator.validate(Uint8List(26 * 1024 * 1024), 'a.pdf',
            pdf: true),
        throwsException);
  });
}
